# Conversion rules and options

## Standard XML → JSON (`TXmlToJsonOptions`)

| XML | JSON |
|---|---|
| root element | `{ "root": value }` (`RootElementMode = rmWrap`) or just `value` (`rmUnwrap`) |
| attribute | member `"@name"` (string; `ConvertAttributeValues = True` converts like text) |
| element with only text | scalar (number / boolean / string) |
| element with attributes or children | object |
| text next to attributes/children | `"#text"` |
| CDATA | merged into text, or `"#cdata"` when `PreserveCDATA` |
| comment | dropped, or `"#comment"` when `PreserveComments` |
| repeated child elements | array (`rpAuto`) / every child an array (`rpAlwaysArray`) |
| empty element | `null` (`emNull`), `""` (`emEmptyString`) or `{}` (`emEmptyObject`) |
| `xsi:nil="true"` | `null` (`ConvertNullValues`) |
| processing instructions, DOCTYPE, declaration | not represented |
| namespace prefixes / `xmlns` | kept as written (`PreserveNamespaces = True`: `"p:name"`, `"@xmlns:p"`) or stripped to local names |
| mixed content | text pieces concatenated into `#text`; **order is not preserved** |

Scalar detection (`ConvertNumbers`, `ConvertBooleans`): `true`/`false` → boolean; text matching the
JSON number grammar with ≤ 15 digits → number (so `007`, `+5`, `.5`, `1.`, ids with 16+ digits stay
strings). `DateTimeMode = dmNormalizeIso` rewrites `YYYY-MM-DD hh:mm:ss…` to `YYYY-MM-DDThh:mm:ss…`;
the default keeps strings. Whitespace: text is trimmed unless `PreserveWhitespace`; whitespace between
elements is never emitted as `#text`.

Other options: `AttributePrefix` (`@`), `TextNodeName` (`#text`), `CDataNodeName`, `CommentNodeName`,
`PrettyPrint`, `IndentSize`, `LosslessMode`.

## Standard JSON → XML (`TJsonToXmlOptions`)

| JSON | XML |
|---|---|
| object with one non-special member | that member is the root (or the root named `RootElementName`) |
| anything else at top level | wrapped in `<root>` / `RootElementName` |
| `"@name": v` | attribute (`v` must be scalar) |
| `"@xmlns"`, `"@xmlns:p"` | namespace declarations (resolved before the element is created) |
| `"#text"` / `"#cdata"` / `"#comment"` | text / CDATA / comment node at that position (arrays → several nodes) |
| `"#children": [ ... ]` | ordered child nodes: strings are text, objects hold `{ "name": value }`, `{ "#comment": ... }`, … |
| `"name": scalar` | `<name>text</name>` (booleans `true/false`, numbers as written) |
| `"name": null` | `<name/>` (`NullHandling = nhNilAttribute` writes `xsi:nil="true"`) |
| `"name": [..]` | repeated `<name>` elements (`PreserveArrayElements`) or `<name><item>..</item></name>` |
| nested arrays | items named `ArrayItemName` (`item`) |

Names are validated (`ValidateElementNames`): invalid names raise `EXmlConversionException`
(`XFE_CONV_BAD_NAME`), or are sanitised to valid names (`_` replaces invalid characters) when the
option is off. Prefixed names need a declaration in scope (`nsStrict`, raises
`EXmlNamespaceException`) or are stripped (`nsStrip`). `XmlVersion`, `Encoding`,
`IncludeXMLDeclaration` and `PrettyPrint`/`IndentSize` (used by `JsonToXmlText`) shape the output.
`LosslessMode = True` means the input is XML Infoset JSON.

## Lossless

See [INFOSET_JSON.md](INFOSET_JSON.md). Choose it whenever the XML must come back with the same
node order, namespaces, CDATA, comments, PIs, DOCTYPE and whitespace.

## Round-trip testing

`TXmlInfosetComparer.Equal(A, B, Diff)` compares the model (names, namespaces, attributes as a set,
namespace declarations as a set, exact child order and text). Never compare serialized strings: they
may differ in attribute order, quoting or whitespace inside tags.
