# XML Infoset JSON — format `XmlForge4D`, version `1.0`

The lossless representation used by `TXmlJsonConverter.XmlToJson(Doc, cmLossless)` and
`JsonToXml(Json, cmLossless)`. It is a JSON encoding of the *supported* XML information model.

> "Lossless" means the information model below survives `XML -> JSON -> XML`. It does **not** mean
> byte-for-byte reconstruction (see *Not preserved*).

## Versioning

* `$format` must be `"XmlForge4D"`.
* `$version` is `"MAJOR.MINOR"`. Readers accept every `1.x`; a major bump means an incompatible change.
  Minor versions only add optional members; readers must ignore unknown members.

## Document

```json
{
  "$format": "XmlForge4D",
  "$version": "1.0",
  "$document": {
    "xmlDeclaration": { "version": "1.0", "encoding": "UTF-8", "standalone": null },
    "children": [ /* node, node, ... in document order */ ]
  }
}
```

* `xmlDeclaration` is **omitted** when the source had no XML declaration. `encoding` / `standalone`
  are `null` when absent; `standalone` is `"yes"` or `"no"`. `encoding` is metadata only — it is the
  declared name in the source, it does not control the encoding of any later serialization.
* `children` holds the prolog/epilog nodes (comments, processing instructions, `doctype`) and exactly
  one root `element`.

## Nodes

Every node is an object with a `type`.

### `element`
```json
{
  "type": "element",
  "name": "item",               // local name
  "namespaceURI": "urn:x",      // null = no namespace
  "prefix": "p",                // null = no prefix
  "namespaceDeclarations": [    // optional: present only if the element declares namespaces
    { "prefix": null, "namespaceURI": "urn:d" },
    { "prefix": "p",  "namespaceURI": "urn:x" }
  ],
  "attributes": [               // never contains xmlns declarations
    { "name": "id", "value": "10", "namespaceURI": null, "prefix": null }
  ],
  "children": [ /* nodes */ ]
}
```
* `namespaceDeclarations[].prefix` is `null` for the default namespace; `namespaceURI` may be `""`
  (`xmlns=""` undeclaration).
* The qualified name is `prefix:name` (or `name`). The `namespaceURI` of elements and attributes is
  authoritative; declarations are kept so serialization reproduces the same `xmlns` attributes.
* Attributes are an unordered set in the information model; they are written in document order.

### `text`, `cdata`, `comment`
```json
{ "type": "text",    "value": "\n    Hello\n    " }
{ "type": "cdata",   "value": "<raw-data>" }
{ "type": "comment", "value": " note " }
```
Whitespace-only text nodes are real nodes and are preserved. Adjacent `text` / `cdata` nodes are kept
as separate nodes.

### `processingInstruction`
```json
{ "type": "processingInstruction", "target": "xml-stylesheet", "value": "href=\"a.css\"" }
```

### `doctype`
```json
{ "type": "doctype", "name": "note", "publicId": null, "systemId": "note.dtd", "internalSubset": null }
```
`internalSubset` is the raw text between `[` and `]`.

## Example (from the specification)

XML `<message id="10">\n    Hello\n    <name>Shaahin</name>\n    <![CDATA[<raw-data>]]>\n</message>` becomes

```json
{
  "$format": "XmlForge4D",
  "$version": "1.0",
  "$document": {
    "children": [
      {
        "type": "element", "name": "message", "namespaceURI": null, "prefix": null,
        "attributes": [ { "name": "id", "value": "10", "namespaceURI": null, "prefix": null } ],
        "children": [
          { "type": "text", "value": "\n    Hello\n    " },
          { "type": "element", "name": "name", "namespaceURI": null, "prefix": null,
            "attributes": [], "children": [ { "type": "text", "value": "Shaahin" } ] },
          { "type": "text", "value": "\n    " },
          { "type": "cdata", "value": "<raw-data>" },
          { "type": "text", "value": "\n" }
        ]
      }
    ]
  }
}
```
(The writer always emits `attributes` and `children` arrays, and explicit `null`s for
`namespaceURI` / `prefix`; readers accept omitted optional members.)

## Not preserved (information that is not part of the model)

* Original bytes: quote style (`'` vs `"`), entity spellings (`&#65;` vs `A`), character
  references, whitespace inside tags, attribute order, order of `xmlns` declarations relative to
  other attributes.
* Line endings: `CRLF`/`CR` are normalised to `LF` on input (required by XML 1.0 §2.11).
* **Entity references**: references to declared entities are expanded by the parser, so the DOM — and
  therefore the JSON — contains the replacement text. The `<!ENTITY>` declarations remain available
  in `internalSubset`.
* Default attribute values from `ATTLIST` declarations (never applied).
* Source encoding bytes / BOM; the `encoding` member is only the declared name.

## Invalid documents

Readers raise `EXmlConversionException` (code `XFE_CONV_BAD_INFOSET = 602`) for a wrong `$format`,
unsupported major version, unknown `type`, missing required members, or structurally invalid
XML (for example text directly under the document, two roots, a prefixed element without
namespace URI).
