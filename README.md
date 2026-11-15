<div align="center">
  <img src="assets/banner.jpg" alt="XmlForge4D — Professional XML Processing & Data Conversion for Delphi and Free Pascal." width="100%" />
</div>

# XmlForge4D

**Professional XML Processing & Data Conversion for Delphi and Free Pascal.**

XmlForge4D is a complete XML toolkit written in portable Object Pascal. It gives you a secure
streaming parser, a DOM, SAX events, a streaming writer, XPath 1.0, XSD validation and — its
signature feature — reliable two-way **XML ⇄ JSON** conversion in two clearly separated modes:

* **Standard conversion** – convenient JSON for everyday application code (`@attributes`, `#text`,
  arrays for repeated elements, numbers and booleans detected automatically).
* **Lossless conversion** – the versioned **XML Infoset JSON** format, which preserves node order,
  namespaces, CDATA, comments, processing instructions, DOCTYPE, whitespace and the XML declaration.

Everything is built around a *Universal Data Model* (UDM), so further formats such as YAML or TOML
can be added without touching the XML core.

---

## Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Quick start](#quick-start)
4. [Parsing XML](#parsing-xml)
5. [Navigating the DOM](#navigating-the-dom)
6. [Creating and modifying XML](#creating-and-modifying-xml)
7. [Namespaces](#namespaces)
8. [Saving and serialization](#saving-and-serialization)
9. [Streaming writer](#streaming-writer)
10. [SAX (event-based) parsing](#sax-event-based-parsing)
11. [XPath 1.0](#xpath-10)
12. [XML to JSON (standard)](#xml-to-json-standard)
13. [JSON to XML (standard)](#json-to-xml-standard)
14. [Lossless conversion (XML Infoset JSON)](#lossless-conversion-xml-infoset-json)
15. [Universal Data Model and JSON](#universal-data-model-and-json)
16. [XSD validation](#xsd-validation)
17. [Security](#security)
18. [Error handling](#error-handling)
19. [Large files and performance](#large-files-and-performance)
20. [Tests, benchmarks and examples](#tests-benchmarks-and-examples)
21. [Compatibility and design notes](#compatibility-and-design-notes)
22. [Limitations](#limitations)
23. [License](#license)

---

## Features

| Area | What you get |
|---|---|
| **Parser** | XML 1.0 (plus a documented XML 1.1 subset), UTF-8 / UTF-16 / ISO-8859-1 / US-ASCII, BOM and declaration detection, namespaces, CDATA, comments, processing instructions, DOCTYPE with internal entities, strict well-formedness checks, errors with code + line + column |
| **Security** | External entities are never loaded (no XXE, no network or file access), limits for entity expansion, entity depth, element depth, attributes per element and document size, optional DOCTYPE prohibition |
| **DOM** | Ordered nodes: element, attribute, text, CDATA, comment, processing instruction, DOCTYPE; namespace-aware create / import / clone / insert / remove / replace; namespace lookup; text content |
| **SAX** | `TXmlSaxHandler`: start/end document, elements, prefix mappings, characters, CDATA, comments, PIs, DOCTYPE, fatal errors; incremental decoding with configurable buffer; cancellation |
| **Writer** | Forward-only streaming writer, pretty printing, escaping, name/character validation, UTF-8 / UTF-16 LE/BE / Latin-1 / ASCII output (character references for unrepresentable characters) |
| **XPath** | XPath 1.0: all axes (except `namespace::`), node tests, predicates, unions, the complete core function library, variables, namespace-aware names |
| **XSD** | Documented XSD 1.0 subset: complex/simple types, `sequence`/`choice`/`all`, occurrences, attributes, facets, about 35 built-in types, `nillable`, groups, extension |
| **XML ⇄ JSON** | Standard conversion with many options, lossless XML Infoset JSON, information-model comparer for round-trip tests |
| **UDM / JSON** | `TDataNode` ordered value tree, JSON parser and writer, extension point for more formats |

Source layout:

```
src/
  XmlForge4D.inc         compiler configuration (Delphi / Free Pascal)
  XmlForge4D.Types       exceptions, error codes, name rules, string buffer, number helpers
  XmlForge4D.Encoding    UTF-8 / UTF-16 / Latin-1 / ASCII codecs, BOM detection
  XmlForge4D.Parser      SAX parser (streaming, namespaces, security limits)
  XmlForge4D.Writer      streaming writer + pretty printer
  XmlForge4D.Dom         DOM nodes, TXmlDocument, SAX-to-DOM builder
  XmlForge4D.XPath       XPath 1.0
  XmlForge4D.Schema      XSD subset loader + validator
  XmlForge4D.DataModel   Universal Data Model (TDataNode)
  XmlForge4D.Json        JSON parser / writer for the UDM
  XmlForge4D.Convert     XML <-> JSON (standard + lossless), options, comparer
```

---

## Installation

Requirements: Delphi 2009 or newer (Delphi 12 is the design target) **or** Free Pascal 3.0+
(3.2.x is the design target). Windows, Linux and macOS use the same sources. There are no
dependencies beyond the RTL (`SysUtils`, `Classes`, `Math`).

**Delphi**

* Add the `src` folder to *Tools → Options → Language → Delphi → Library → Library path* (or to the
  project's search path), **or** open `packages/XmlForge4D.dpk` and build/install it.
* Add the units you need to your `uses` clause, for example
  `uses XmlForge4D.Types, XmlForge4D.Dom, XmlForge4D.Convert;`

**Lazarus / Free Pascal**

* Lazarus: *Package → Open package file (.lpk)* → `packages/XmlForge4D.lpk` → *Use → Add to project*.
* Command line: `fpc -Fu<path-to>/src yourprogram.lpr`
* Every unit includes `XmlForge4D.inc`, which switches Free Pascal to `{$MODE DELPHIUNICODE}`, so
  your own program does not need a special mode switch. It is still recommended to use
  `{$mode delphiunicode}` (or `{$mode objfpc}{$H+}`) in your own sources.

The text type used everywhere is `XmlString` (an alias of `UnicodeString`), declared in
`XmlForge4D.Types`.

---

## Quick start

```pascal
program QuickStart;
{$APPTYPE CONSOLE}

uses
  SysUtils, XmlForge4D.Types, XmlForge4D.Dom, XmlForge4D.Convert;

var
  Doc: TXmlDocument;
begin
  Doc := TXmlDocument.LoadFromString(
    '<person id="123"><name>Shaahin</name><age>35</age></person>');
  try
    WriteLn(Doc.DocumentElement.AttributeValue['id']);      // 123
    WriteLn(Doc.SelectString('/person/name'));              // Shaahin
    WriteLn(TXmlJsonConverter.XmlToJson(Doc));              // {"person": {"@id": "123", ...}}
  finally
    Doc.Free;                                               // you own the document
  end;
end.
```

**Ownership rule in one sentence:** every `TXmlDocument` returned by a `LoadFrom…` function (or
created with `Create`) must be freed by you; nodes belong to their parent; query result lists
(`TXmlNodeList`) are freed by you, but the nodes inside them are not.

---

## Parsing XML

### From a file, a string and a stream

```pascal
uses Classes, XmlForge4D.Types, XmlForge4D.Dom;

var
  Doc: TXmlDocument;
  Stream: TFileStream;
begin
  // 1. file
  Doc := TXmlDocument.LoadFromFile('orders.xml');
  Doc.Free;

  // 2. string
  Doc := TXmlDocument.LoadFromString('<a><b>text</b></a>');
  Doc.Free;

  // 3. stream (UTF-8, UTF-16 and ISO-8859-1 are detected automatically)
  Stream := TFileStream.Create('orders.xml', fmOpenRead or fmShareDenyWrite);
  try
    Doc := TXmlDocument.LoadFromStream(Stream);
    Doc.Free;
  finally
    Stream.Free;
  end;
end;
```

To refill an existing document object use the instance methods `ParseFile`, `ParseStream` and
`ParseString`.

### Parser options

```pascal
uses XmlForge4D.Parser;

var
  Opt: TXmlParserOptions;
  Doc: TXmlDocument;
begin
  Opt := TXmlParserOptions.Default;
  Opt.PreserveWhitespace := False;      // drop whitespace-only text nodes
  Opt.NamespaceAware := True;           // default
  Opt.MaxDepth := 64;                   // reject deeper nesting
  Opt.MaxDocumentSize := 50 * 1024 * 1024;   // bytes, 0 = unlimited
  Opt.DtdMode := dtdAllow;              // dtdAllow | dtdIgnore | dtdProhibit
  Opt.BufferSize := 256 * 1024;         // streaming chunk size in bytes

  Doc := TXmlDocument.LoadFromFile('data.xml', Opt);
  Doc.Free;
end;
```

| Option | Default | Meaning |
|---|---|---|
| `NamespaceAware` | `True` | resolve prefixes; unbound prefixes raise `EXmlNamespaceException` |
| `PreserveWhitespace` | `True` | report whitespace-only text between elements |
| `DtdMode` | `dtdAllow` | `dtdProhibit` rejects any DOCTYPE, `dtdIgnore` parses but ignores entity declarations |
| `IgnoreExternalEntities` | `False` | `False`: a reference to an external entity raises `EXmlSecurityException`; `True`: expands to nothing |
| `MaxDocumentSize` | `0` (unlimited) | maximum input size in bytes |
| `MaxDepth` | `256` | maximum element nesting |
| `MaxEntityExpansion` | `1,000,000` | total characters produced by entity expansion |
| `MaxEntityDepth` | `16` | nested entity references |
| `MaxAttributes` | `1024` | attributes per element |
| `BufferSize` | `65536` | bytes read per chunk |

### Reading the XML declaration and the DOCTYPE

```pascal
Doc := TXmlDocument.LoadFromString(
  '<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>' +
  '<!DOCTYPE note SYSTEM "note.dtd"><note/>');
try
  WriteLn(Doc.XmlVersion);                 // 1.0
  WriteLn(Doc.Encoding);                   // ISO-8859-1  (declared name, informational)
  WriteLn(Doc.Standalone = xsYes);         // TRUE
  WriteLn(Doc.HasDeclaration);             // TRUE
  if Doc.DocType <> nil then
    WriteLn(Doc.DocType.Name, ' ', Doc.DocType.SystemId);   // note note.dtd
finally
  Doc.Free;
end;
```

---

## Navigating the DOM

```pascal
uses XmlForge4D.Types, XmlForge4D.Dom;

procedure Dump(Node: TXmlNode; Indent: Integer);
var
  I: Integer;
  E: TXmlElement;
begin
  case Node.NodeType of
    ntElement:
      begin
        E := TXmlElement(Node);
        Write(StringOfChar(' ', Indent), '<', E.Name, '>');
        for I := 0 to E.AttributeCount - 1 do
          Write(' @', E.Attributes[I].Name, '=', E.Attributes[I].Value);
        WriteLn;
        for I := 0 to E.ChildCount - 1 do
          Dump(E.Children[I], Indent + 2);
      end;
    ntText:    WriteLn(StringOfChar(' ', Indent), 'text: ', Node.Value);
    ntCData:   WriteLn(StringOfChar(' ', Indent), 'cdata: ', Node.Value);
    ntComment: WriteLn(StringOfChar(' ', Indent), 'comment: ', Node.Value);
    ntProcessingInstruction:
               WriteLn(StringOfChar(' ', Indent), 'pi: ', Node.Name, ' ', Node.Value);
  end;
end;

var
  Doc: TXmlDocument;
begin
  Doc := TXmlDocument.LoadFromFile('person.xml');
  try
    Dump(Doc.DocumentElement, 0);
  finally
    Doc.Free;
  end;
end;
```

Frequently used members:

```pascal
Root := Doc.DocumentElement;                 // TXmlElement
Root.Name;  Root.LocalName;  Root.Prefix;  Root.NamespaceURI;
Root.TextContent;                            // all descendant text (text + CDATA)
Root.AttributeValue['id'];                   // '' when missing
if Root.TryGetAttribute('id', Value) then ...
if Root.HasAttribute('id') then ...
Attr := Root.FindAttribute('id');            // TXmlAttribute or nil
Child := Root.FindChildElement('name');      // first child element with that qualified name
Child := Root.FindChildElementNS('urn:x', 'name');
Root.ChildCount;  Root.Children[0];  Root.FirstChild;  Root.LastChild;
Node.ParentNode;  Node.NextSibling;  Node.PreviousSibling;
Node.Line;  Node.Column;                     // source position of parsed nodes

List := Root.GetElementsByTagName('skill');  // all descendants, by qualified name ('*' = all)
try
  for I := 0 to List.Count - 1 do WriteLn(List[I].TextContent);
finally
  List.Free;                                 // frees the list only, not the nodes
end;
```

---

## Creating and modifying XML

### Building a document from scratch

```pascal
uses XmlForge4D.Types, XmlForge4D.Dom;

var
  Doc: TXmlDocument;
  Root, Book: TXmlElement;
begin
  Doc := TXmlDocument.Create;
  try
    Root := Doc.AddRoot('library');
    Root.SetAttribute('updated', '2026-11-14');
    Root.AddComment(' sample data ');

    Book := Root.AddElement('book');
    Book.SetAttribute('id', '1');
    Book.AddElementWithText('title', 'Object Pascal Handbook');
    Book.AddElementWithText('year', '2023');
    Book.AddElement('notes').AddCData('<b>bold</b> & raw');

    Book := Root.AddElement('book');
    Book.SetAttribute('id', '2');
    Book.AddElementWithText('title', 'Free Pascal Guide');

    WriteLn(Doc.ToXml(True));      // pretty printed
    Doc.SaveToFile('library.xml');
  finally
    Doc.Free;
  end;
end;
```

Output of `ToXml(True)`:

```xml
<?xml version="1.0"?>
<library updated="2026-11-14">
  <!-- sample data -->
  <book id="1">
    <title>Object Pascal Handbook</title>
    <year>2023</year>
    <notes><![CDATA[<b>bold</b> & raw]]></notes>
  </book>
  <book id="2">
    <title>Free Pascal Guide</title>
  </book>
</library>
```

### Editing

```pascal
var
  Doc: TXmlDocument;
  Root: TXmlElement;
  Item, Copy: TXmlNode;
begin
  Doc := TXmlDocument.LoadFromString('<r><a/><b>old</b><c><d/></c></r>');
  try
    Root := Doc.DocumentElement;

    // change text
    Root.FindChildElement('b').TextContent := 'new';

    // change / add / remove attributes
    Root.SetAttribute('version', '2');
    Root.RemoveAttribute('version');

    // remove a child (frees it)
    Root.DeleteChild(Root.FindChildElement('a'));

    // detach a child without freeing it
    Item := Root.RemoveChild(Root.FindChildElement('c'));
    Root.AppendChild(Item);                       // put it back at the end

    // clone a subtree and insert it before the first child
    Copy := Root.FindChildElement('c').CloneNode(True);
    Root.InsertBefore(Copy, Root.FirstChild);

    // replace a node (returns the removed node, which you must free)
    Doc.DocumentElement.ReplaceChild(Doc.CreateElement('z'), Root.LastChild).Free;

    WriteLn(Doc.ToXml);
  finally
    Doc.Free;
  end;
end;
```

### Moving nodes between documents

A node can only be inserted into the document that created it. Copy it first with `ImportNode`:

```pascal
Imported := TargetDoc.ImportNode(SourceDoc.DocumentElement.FindChildElement('item'), True);
TargetDoc.DocumentElement.AppendChild(Imported);
```

The DOM rejects invalid structure with `EXmlForgeException`: inserting a node into itself or
one of its descendants, inserting text directly under the document, a second root element, nodes
from another document, invalid names.

---

## Namespaces

### Parsing namespaced XML

```pascal
Doc := TXmlDocument.LoadFromString(
  '<r xmlns="urn:default" xmlns:p="urn:prefixed"><p:item p:code="7" plain="1"/><other/></r>');
try
  Root := Doc.DocumentElement;
  WriteLn(Root.NamespaceURI);                         // urn:default
  Item := TXmlElement(Root.Children[0]);
  WriteLn(Item.Name, ' / ', Item.LocalName, ' / ', Item.Prefix);   // p:item / item / p
  WriteLn(Item.NamespaceURI);                         // urn:prefixed
  WriteLn(Item.GetAttributeNS('urn:prefixed', 'code'));            // 7
  WriteLn(Item.FindAttributeNS('', 'plain') <> nil);               // TRUE (no namespace)
  WriteLn(Root.Children[1].NamespaceURI);             // urn:default (inherited default ns)
finally
  Doc.Free;
end;
```

Namespace declarations are kept as attributes named `xmlns` / `xmlns:prefix`
(namespace URI `XMLNS_NS_URI`). Helper:

```pascal
var
  Uri, Prefix: XmlString;
begin
  if Item.LookupNamespaceURI('p', Uri) then WriteLn(Uri);              // in-scope lookup
  if Item.LookupPrefix('urn:prefixed', Prefix) then WriteLn(Prefix);   // reverse lookup
end;
```

### Creating namespaced XML

```pascal
var
  Doc: TXmlDocument;
  Root, Cust, Row: TXmlElement;
begin
  Doc := TXmlDocument.Create;
  try
    Root := Doc.AddRoot('inv:invoice', 'urn:example:invoice');   // declares xmlns:inv automatically
    Root.DeclareNamespace('c', 'urn:example:customer');
    Cust := Root.AddElement('c:customer');                       // resolved from the in-scope declaration
    Cust.AddElementWithText('c:name', 'Ali');
    Row := Root.AddElement('inv:line');
    Row.SetAttributeNS('urn:example:customer', 'c:ref', 'A-1');
    WriteLn(Doc.ToXml(True));
  finally
    Doc.Free;
  end;
end;
```

```xml
<?xml version="1.0"?>
<inv:invoice xmlns:inv="urn:example:invoice" xmlns:c="urn:example:customer">
  <c:customer>
    <c:name>Ali</c:name>
  </c:customer>
  <inv:line c:ref="A-1"/>
</inv:invoice>
```

Using an undeclared prefix (`Root.AddElement('x:y')`) raises `EXmlNamespaceException`.

---

## Saving and serialization

```pascal
uses XmlForge4D.Writer, XmlForge4D.Encoding;     // Encoding provides xeUtf8, xeUtf16LE, ...

var
  Opt: TXmlWriterOptions;
  S: XmlString;
begin
  Doc.SaveToFile('out.xml');                     // UTF-8, compact

  Opt := TXmlWriterOptions.Default;
  Opt.Indent := True;                            // pretty print
  Opt.IndentSize := 4;
  Opt.Encoding := xeUtf16LE;                     // xeUtf8 | xeUtf16LE | xeUtf16BE | xeLatin1 | xeAscii
  Opt.WriteBom := True;
  Doc.SaveToFile('out16.xml', Opt);

  Opt := TXmlWriterOptions.Default;
  Opt.DeclarationMode := xdNever;                // xdAuto (follow document) | xdAlways | xdNever
  Opt.SelfCloseEmpty := False;                   // <a></a> instead of <a/>
  Doc.SaveToStream(MyStream, Opt);

  S := Doc.ToXml;                                // compact string
  S := Doc.ToXml(True);                          // pretty string
  S := Doc.DocumentElement.FindChildElement('book').ToXml(True);   // a single node
end;
```

| Writer option | Default | Meaning |
|---|---|---|
| `Indent` / `IndentSize` | `False` / `2` | pretty printing (mixed-content elements are never re-indented) |
| `NewLine` | `#10` | line separator used when indenting |
| `Encoding` | `xeUtf8` | output encoding; characters not representable in Latin-1/ASCII become `&#x…;` |
| `WriteBom` | `False` | write a byte-order mark |
| `DeclarationMode` | `xdAuto` | write the XML declaration if the document has one (always written for Latin-1/ASCII output so the encoding can be detected) |
| `SelfCloseEmpty` | `True` | `<a/>` for empty elements |
| `ValidateNames` / `ValidateChars` | `True` | reject invalid names and characters instead of writing broken XML |

---

## Streaming writer

`TXmlWriter` produces XML without building a DOM — ideal for exporting large data sets.

```pascal
uses SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Writer;

var
  Stream: TFileStream;
  W: TXmlWriter;
  Opt: TXmlWriterOptions;
  I: Integer;
begin
  Stream := TFileStream.Create('export.xml', fmCreate);
  try
    Opt := TXmlWriterOptions.Default;
    Opt.Indent := True;
    W := TXmlWriter.Create(Stream, Opt);
    try
      W.WriteStartDocument('1.0', 'UTF-8');
      W.WriteStartElement('customers');
      for I := 1 to 100000 do
      begin
        W.WriteStartElement('customer');
        W.WriteAttribute('id', IntToStr(I));
        W.WriteElementString('name', 'Customer ' + IntToStr(I));
        W.WriteStartElement('notes');
        W.WriteCData('free <text> & more');
        W.WriteEndElement;                 // notes
        W.WriteEndElement;                 // customer
      end;
      W.EndDocument;                       // closes open elements and flushes
    finally
      W.Free;
    end;
  finally
    Stream.Free;
  end;
end;
```

Write to a string instead of a stream with `TXmlWriter.CreateToString(Options)` and read `W.Text`.
Other methods: `WriteComment`, `WriteProcessingInstruction`, `WriteDocType`, `WriteText`,
`WriteFullEndElement`, `WriteRaw`, `Flush`. Misuse (attribute after content, invalid names,
`--` in comments …) raises `EXmlSerializationException`.

---

## SAX (event-based) parsing

SAX reads documents of any size in constant memory. Derive from `TXmlSaxHandler` and override the
events you need.

```pascal
uses SysUtils, XmlForge4D.Types, XmlForge4D.Parser;

type
  TTotals = class(TXmlSaxHandler)
  private
    FInPrice: Boolean;
    FBuffer: XmlString;
  public
    Items: Integer;
    Sum: Double;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); override;
    procedure EndElement(const Uri, LocalName, QName: XmlString); override;
    procedure Characters(const Text: XmlString); override;
  end;

procedure TTotals.StartElement(const Uri, LocalName, QName: XmlString;
  Attrs: TXmlSaxAttributes; Line, Column: Integer);
begin
  if LocalName = 'item' then Inc(Items);
  if LocalName = 'price' then
  begin
    FInPrice := True;
    FBuffer := '';
  end;
end;

procedure TTotals.Characters(const Text: XmlString);
begin
  if FInPrice then FBuffer := FBuffer + Text;   // text can arrive in several chunks
end;

procedure TTotals.EndElement(const Uri, LocalName, QName: XmlString);
var
  V: Double;
begin
  if (LocalName = 'price') and FInPrice then
  begin
    if XmlTryParseFloat(Trim(FBuffer), V) then Sum := Sum + V;
    FInPrice := False;
  end;
end;

var
  Parser: TXmlParser;
  Totals: TTotals;
begin
  Parser := TXmlParser.Create;
  Totals := TTotals.Create;
  try
    Parser.ParseFile('catalog.xml', Totals);
    WriteLn(Totals.Items, ' items, total ', XmlFloatToStr(Totals.Sum));
  finally
    Totals.Free;
    Parser.Free;
  end;
end.
```

All events: `StartDocument`, `EndDocument`, `DocType`, `StartPrefixMapping`, `EndPrefixMapping`,
`StartElement` (with `TXmlSaxAttributes`: `Count`, `QName[i]`, `LocalName[i]`, `Prefix[i]`,
`NamespaceURI[i]`, `Value[i]`, `IndexOf`, `IndexOfNS`, `ValueOf`), `EndElement`, `Characters`,
`CData`, `Comment`, `ProcessingInstruction`, `FatalError`.

### Cancelling a long parse

```pascal
type
  TWorker = class
    Stop: Boolean;
    procedure CheckCancel(Sender: TObject; var Cancel: Boolean);
  end;

procedure TWorker.CheckCancel(Sender: TObject; var Cancel: Boolean);
begin
  Cancel := Stop;                 // e.g. set from a "Cancel" button
end;

...
Parser.OnCancel := Worker.CheckCancel;
try
  Parser.ParseFile('huge.xml', Handler);
except
  on EXmlCancelledException do WriteLn('cancelled');
end;
// or call Parser.Cancel from another place
```

### Building a DOM through the SAX interface

The DOM itself is built by `TXmlDomBuilder`, which is just another `TXmlSaxHandler`:

```pascal
Doc := TXmlDocument.Create;
Builder := TXmlDomBuilder.Create(Doc);
Parser := TXmlParser.Create;
try
  Parser.ParseFile('data.xml', Builder);       // same result as TXmlDocument.LoadFromFile
finally
  Parser.Free;
  Builder.Free;
end;
```

---

## XPath 1.0

Convenience methods exist on every node:

```pascal
Doc := TXmlDocument.LoadFromFile('library.xml');
try
  Title  := Doc.SelectString('/library/book[1]/title');          // XmlString
  Count  := Doc.SelectNumber('count(//book)');                   // Double
  HasOld := Doc.SelectBoolean('//book[year < 2000]');            // Boolean
  Node   := Doc.SelectSingleNode('//book[@id="2"]');             // TXmlNode or nil

  List := Doc.SelectNodes('//book[price > 10]/title');           // you free the list
  try
    for I := 0 to List.Count - 1 do WriteLn(List[I].TextContent);
  finally
    List.Free;
  end;
finally
  Doc.Free;
end;
```

Examples of supported expressions:

```text
/library/book                     absolute path
//title                           descendants
book[2]                           positional predicate        book[last()]    last()
book[@id='7']                     attribute predicate
book[year>2000 and price<30]      boolean/numeric predicates
book/title | book/year            union
//book/following-sibling::book    axes: child, descendant, parent, ancestor, following,
                                  preceding, following-sibling, preceding-sibling, attribute,
                                  self, descendant-or-self, ancestor-or-self
//text()  //comment()  //processing-instruction()  //node()
count(//book)   sum(//price)   string-length(//title)   normalize-space(' a  b ')
concat('a','b')  contains(.,'x')  starts-with(.,'x')  substring-before/after  substring
translate('abc','abc','ABC')  floor/ceiling/round  not()  boolean()  number()  string()
name()  local-name()  namespace-uri()  lang('en')  position()  last()
```

### Namespaces and variables with `TXPathExpression`

```pascal
uses XmlForge4D.XPath;

var
  X: TXPathExpression;
  List: TXmlNodeList;
begin
  X := TXPathExpression.Create('//b:book[@id=$id]/b:title');   // compile once, evaluate many times
  try
    X.AddNamespace('b', 'urn:books');                          // or rely on in-scope prefixes (root element's
                                                               // declarations are used for the document node)
    X.SetVariableString('id', '3');
    WriteLn(X.EvaluateString(Doc));

    X.SetVariableString('id', '4');
    List := X.SelectNodes(Doc);
    List.Free;
  finally
    X.Free;
  end;
end;
```

Per XPath 1.0, an unprefixed name test matches elements **without** a namespace. If your document
uses a default namespace, either register a prefix for it or set
`X.DefaultElementNamespace := 'urn:books'`.

Results are always in document order. XPath errors raise `EXmlXPathException`.

---

## XML to JSON (standard)

### The basic rules

```xml
<?xml version="1.0" encoding="UTF-8"?>
<person id="123">
    <name>Shaahin</name>
    <age>35</age>
    <active>true</active>
    <address city="Tehran">
        <street>Example Street</street>
    </address>
    <skill>Delphi</skill>
    <skill>Free Pascal</skill>
</person>
```

```pascal
Json := TXmlJsonConverter.XmlToJson(Doc);              // from a document
Json := TXmlJsonConverter.XmlTextToJson(XmlString);    // straight from XML text
```

```json
{
  "person": {
    "@id": "123",
    "name": "Shaahin",
    "age": 35,
    "active": true,
    "address": {
      "@city": "Tehran",
      "street": "Example Street"
    },
    "skill": [
      "Delphi",
      "Free Pascal"
    ]
  }
}
```

| XML | JSON |
|---|---|
| root element | `{ "root": … }` (or just the value with `rmUnwrap`) |
| attribute | `"@name": "value"` (string; numbers/booleans only with `ConvertAttributeValues`) |
| element with only text | scalar: number / boolean / string |
| element with attributes or children | object |
| text next to attributes/children | `"#text"` |
| CDATA | merged into text, or `"#cdata"` with `PreserveCDATA` |
| comment | dropped, or `"#comment"` with `PreserveComments` |
| repeated child elements | array |
| empty element | `null` (or `""` / `{}` — see `EmptyElementMode`) |
| `xsi:nil="true"` | `null` |
| namespace prefixes / `xmlns` | kept (`"p:name"`, `"@xmlns:p"`) or stripped |

Numbers are recognised only when they follow the JSON number grammar and have at most 15 digits,
so values such as `007`, `+5`, `.5` or a 16-digit identifier stay strings.

### Options

```pascal
uses XmlForge4D.Convert;

var
  O: TXmlToJsonOptions;
begin
  O := TXmlToJsonOptions.Default;
  O.AttributePrefix := '_';                 // "_id" instead of "@id"
  O.TextNodeName := '$';                    // "$" instead of "#text"
  O.RootElementMode := rmUnwrap;            // drop the root element name
  O.RepeatedElementMode := rpAlwaysArray;   // every child element becomes an array
  O.EmptyElementMode := emEmptyString;      // <a/> -> ""    (emNull | emEmptyString | emEmptyObject)
  O.ConvertNumbers := False;                // keep numbers as strings
  O.ConvertBooleans := False;
  O.ConvertAttributeValues := True;         // also detect numbers/booleans in attributes
  O.PreserveComments := True;
  O.PreserveCDATA := True;
  O.PreserveNamespaces := False;            // strip prefixes and xmlns attributes
  O.PreserveWhitespace := False;            // trim text (default)
  O.DateTimeMode := dmNormalizeIso;         // "2026-11-14 10:30:00" -> "2026-11-14T10:30:00"
  O.PrettyPrint := True;
  O.IndentSize := 4;

  Json := TXmlJsonConverter.XmlTextToJson(Xml, O);
end;
```

### More examples

In the snippets below `X2J(xml)` stands for `TXmlJsonConverter.XmlTextToJson(xml)` with default options
(results are shown compact; the converter pretty-prints by default).

```pascal
// repeated elements become arrays
X2J('<a><b>1</b><b>2</b><b>3</b></a>');
// {"a":{"b":[1,2,3]}}

// attributes + text
X2J('<price currency="EUR">9.5</price>');
// {"price":{"@currency":"EUR","#text":9.5}}

// empty and nil elements
X2J('<a xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><b/><c xsi:nil="true"/></a>');
// {"a":{"@xmlns:xsi":"http://www.w3.org/2001/XMLSchema-instance","b":null,"c":null}}

// comments and CDATA kept on request (O.PreserveComments / O.PreserveCDATA)
X2J('<a><!--note--><![CDATA[<x>]]><b>1</b></a>');
// {"a":{"#cdata":"<x>","#comment":"note","b":1}}

// mixed content: the text pieces are concatenated and their order is lost
X2J('<p>Hello <b>bold</b> world</p>');
// {"p":{"#text":"Hello  world","b":"bold"}}   -> use lossless mode if the order matters
```

---

## JSON to XML (standard)

```pascal
Doc := TXmlJsonConverter.JsonToXml(
  '{"person":{"@id":"123","name":"Shaahin","age":35,"active":true,' +
  '"skill":["Delphi","Free Pascal"]}}');
try
  WriteLn(Doc.ToXml(True));
finally
  Doc.Free;
end;
```

```xml
<?xml version="1.0"?>
<person id="123">
  <name>Shaahin</name>
  <age>35</age>
  <active>true</active>
  <skill>Delphi</skill>
  <skill>Free Pascal</skill>
</person>
```

For direct text output with full control (encoding name in the declaration, indentation):

```pascal
var
  O: TJsonToXmlOptions;
  Xml: XmlString;
begin
  O := TJsonToXmlOptions.Default;
  O.RootElementName := 'person';        // used when the JSON has no single root member
  O.PrettyPrint := True;
  O.IndentSize := 2;
  O.IncludeXMLDeclaration := True;
  O.Encoding := 'UTF-8';                // text written in the declaration
  Xml := TXmlJsonConverter.JsonToXmlText('{"name":"Ali","skill":["a","b"]}', O);
end;
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<person>
  <name>Ali</name>
  <skill>a</skill>
  <skill>b</skill>
</person>
```

### Mapping conventions (all configurable)

| JSON | XML |
|---|---|
| `"@name": value` | attribute |
| `"#text": "…"` | text node |
| `"#cdata": "…"` | CDATA section |
| `"#comment": "…"` | comment |
| `"#children": [ … ]` | ordered child nodes (strings = text, objects = `{ "name": value }`) |
| `"name": [ … ]` | repeated `<name>` elements (`PreserveArrayElements = True`) |
| `"name": null` | `<name/>` (or `xsi:nil="true"` with `NullHandling := nhNilAttribute`) |
| `"@xmlns:p": "uri"` | namespace declaration, usable by `p:` names in the same object |

### More examples

In the snippets below `J2X(json)` stands for `TXmlJsonConverter.JsonToXml(json).ToXml` (compact output,
XML declaration omitted for brevity).

```pascal
// text, CDATA and comment nodes in one element
J2X('{"a":{"#text":"t","#cdata":"<c>","#comment":"c","b":1}}');
// <a>t<![CDATA[<c>]]><!--c--><b>1</b></a>

// ordered mixed content with #children
J2X('{"p":{"#children":["Hello ",{"b":"bold"}," world"]}}');
// <p>Hello <b>bold</b> world</p>

// namespaces
J2X('{"inv:invoice":{"@xmlns:inv":"urn:invoice","inv:total":42}}');
// <inv:invoice xmlns:inv="urn:invoice"><inv:total>42</inv:total></inv:invoice>

// several top-level members -> wrapped
J2X('{"a":1,"b":2}');
// <root><a>1</a><b>2</b></root>

// top-level array
J2X('[1,2]');
// <root><item>1</item><item>2</item></root>

// arrays wrapped in one element (O.PreserveArrayElements := False)
J2X('{"a":{"s":["x","y"]}}');
// <a><s><item>x</item><item>y</item></s></a>

// invalid names: error by default, sanitised with O.ValidateElementNames := False
J2X('{"a":{"1bad name":"x"}}');
// EXmlConversionException   /   <a><_1bad_name>x</_1bad_name></a>
```

---

## Lossless conversion (XML Infoset JSON)

When the XML must come back with the same structure, use `cmLossless`:

```pascal
uses SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Encoding, XmlForge4D.Dom, XmlForge4D.Convert;

var
  Doc, Doc2: TXmlDocument;
  Json: XmlString;
  Bytes: TBytes;
  Stream: TFileStream;
begin
  Doc := TXmlDocument.LoadFromFile('contract.xml');
  try
    Json := TXmlJsonConverter.XmlToJson(Doc, cmLossless);
    Bytes := XmlUtf8Encode(Json);                        // save the JSON as UTF-8
    Stream := TFileStream.Create('contract.json', fmCreate);
    try
      Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
  finally
    Doc.Free;
  end;

  // ... later: restore the XML
  Doc2 := TXmlJsonConverter.JsonToXml(Json, cmLossless);
  try
    Doc2.SaveToFile('contract-restored.xml');
  finally
    Doc2.Free;
  end;
end;
```

Example — this mixed-content element:

```xml
<message id="10">
    Hello
    <name>Shaahin</name>
    <![CDATA[<raw-data>]]>
</message>
```

becomes:

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

What is preserved: element names, namespace URIs and prefixes, namespace declarations, attributes
(with their namespaces), child order, text, CDATA, comments, processing instructions, DOCTYPE,
whitespace-only text, mixed content, and the XML declaration (version, declared encoding,
standalone). What is *not* (and cannot be, without source-level information): quote style, entity
spellings and character references, attribute order, `xmlns` ordering, original line endings
(normalised to LF as the XML specification requires), expanded entity references. The full,
versioned schema is documented in [docs/INFOSET_JSON.md](docs/INFOSET_JSON.md).

### Verifying round trips

Compare the information model, not the text:

```pascal
var
  A, B: TXmlDocument;
  Diff: XmlString;
begin
  A := TXmlDocument.LoadFromFile('input.xml');
  B := TXmlJsonConverter.JsonToXml(TXmlJsonConverter.XmlToJson(A, cmLossless), cmLossless);
  try
    if TXmlInfosetComparer.Equal(A, B, Diff) then
      WriteLn('identical information model')
    else
      WriteLn('difference: ', Diff);       // e.g. "/root[1]/item[3]: value differs"
  finally
    B.Free;
    A.Free;
  end;
end;
```

---

## Universal Data Model and JSON

`TDataNode` is a format-independent, ordered tree of null / boolean / number / string / array /
object values. Numbers keep their literal text, so nothing is lost on round trips.

```pascal
uses XmlForge4D.DataModel, XmlForge4D.Json, XmlForge4D.Convert;

var
  Node, Skills: TDataNode;
begin
  // parse JSON into the UDM
  Node := TJsonParser.ParseText('{"name":"Ali","age":35,"skills":["Delphi","FPC"],"manager":null}');
  try
    WriteLn(Node.FindMember('name').AsString);                  // Ali
    WriteLn(XmlFloatToStr(Node.FindMember('age').AsDouble));   // 35
    Skills := Node.FindMember('skills');
    WriteLn(Skills.Count, ' skills, first = ', Skills[0].AsString);
    WriteLn(Node.FindMember('manager').Kind = dkNull);          // TRUE

    // modify
    Node.AddMember('active', TDataNode.NewBoolean(True));
    Skills.Add(TDataNode.NewString('Lazarus'));

    // write back as JSON
    WriteLn(TJsonWriter.Write(Node, True, 2));
  finally
    Node.Free;                                                  // frees the whole tree
  end;
end;
```

Build a tree by hand and turn it into XML:

```pascal
var
  Root, Person: TDataNode;
  Doc: TXmlDocument;
  O: TJsonToXmlOptions;
begin
  Root := TDataNode.NewObject;
  try
    Person := Root.AddMember('person', TDataNode.NewObject);
    Person.AddMember('@id', TDataNode.NewString('7'));
    Person.AddMember('name', TDataNode.NewString('Ali'));

    O := TJsonToXmlOptions.Default;
    Doc := TXmlJsonConverter.UdmToXml(Root, O);
    try
      WriteLn(Doc.ToXml(True));
    finally
      Doc.Free;
    end;
  finally
    Root.Free;
  end;
end;
```

The reverse, `TXmlJsonConverter.XmlToUdm(Doc, Options)`, returns the UDM tree for a document so you
can post-process it before serializing. `TJsonParser.ParseFile`, `ParseStream` and
`TJsonWriter.WriteToFile` / `WriteToStream` handle files (UTF-8).

---

## XSD validation

```pascal
uses XmlForge4D.Schema;

const
  Xsd =
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' +
    '<xs:simpleType name="Percent"><xs:restriction base="xs:integer">' +
    '<xs:minInclusive value="0"/><xs:maxInclusive value="100"/></xs:restriction></xs:simpleType>' +
    '<xs:element name="person"><xs:complexType><xs:sequence>' +
    '<xs:element name="name" type="xs:string"/>' +
    '<xs:element name="score" type="Percent" minOccurs="0"/>' +
    '<xs:element name="skill" type="xs:string" minOccurs="0" maxOccurs="unbounded"/>' +
    '</xs:sequence><xs:attribute name="id" type="xs:int" use="required"/>' +
    '</xs:complexType></xs:element></xs:schema>';

var
  Schema: TXsdSchema;
  Validator: TXmlValidator;
  Doc: TXmlDocument;
  Err: TXmlValidationError;
  I: Integer;
begin
  Schema := TXsdSchema.LoadFromString(Xsd);              // or LoadFromFile('model.xsd')
  try
    for I := 0 to Schema.Warnings.Count - 1 do           // unsupported constructs found in the schema
      WriteLn('schema warning: ', Schema.Warnings[I]);

    Validator := TXmlValidator.Create(Schema);
    try
      Doc := TXmlDocument.LoadFromString(
        '<person id="x"><name>Ali</name><score>150</score></person>');
      try
        if Validator.Validate(Doc) then
          WriteLn('valid')
        else
          for I := 0 to Validator.ErrorCount - 1 do
          begin
            Err := Validator.Errors[I];
            WriteLn(Err.Path, ': ', Err.Message, ' (line ', Err.Line, ', column ', Err.Column, ')');
          end;
      finally
        Doc.Free;
      end;
    finally
      Validator.Free;
    end;
  finally
    Schema.Free;
  end;
end;
```

Typical messages:

```text
/person/@id: Attribute "id" value "x": not a valid xs:int (line 1, column 1)
/person/score: Element <score> value "150": value must be <= 100 (line 1, column 32)
```

* `Validator.ValidateOrRaise(Doc)` raises `EXmlValidationException` for the first error;
  `Diagnostic` holds all errors as text.
* A schema spread over several files can be assembled with `Schema.AddSchemaDocument(Doc)` —
  the loader never follows `import`/`include` by itself, so schemas cannot cause file or network
  access.
* Supported subset and known gaps are listed at the top of `XmlForge4D.Schema.pas`.

---

## Security

Defaults are safe for ordinary use; tighten them for untrusted input:

```pascal
var
  Opt: TXmlParserOptions;
begin
  Opt := TXmlParserOptions.Default;
  Opt.DtdMode := dtdProhibit;                  // no DOCTYPE at all (blocks XXE / entity tricks entirely)
  Opt.MaxDocumentSize := 20 * 1024 * 1024;     // bytes
  Opt.MaxDepth := 64;
  Opt.MaxAttributes := 256;
  Doc := TXmlDocument.LoadFromStream(UploadStream, Opt);
end;
```

| Threat | Protection |
|---|---|
| XXE / SSRF | External entities (`SYSTEM`/`PUBLIC`) are **never** read from files or networks. A reference raises `EXmlSecurityException` (`XFE_SEC_EXTERNAL_ENTITY`), or expands to nothing with `IgnoreExternalEntities`. |
| Billion laughs / quadratic blow-up | Limits on total expansion (`MaxEntityExpansion`), entity nesting (`MaxEntityDepth`), recursion detection |
| Deeply nested documents | `MaxDepth` (the parser itself is iterative; DOM recursion is bounded by this limit) |
| Huge inputs | `MaxDocumentSize`, streaming parse |
| Attribute flooding | `MaxAttributes` |
| Malformed encodings | strict UTF-8/UTF-16 decoding raises `EXmlEncodingException` |
| JSON bombs | `TJsonParser.ParseText(Json, MaxDepth)` limits nesting (default 512) |
| Broken output / injection | the writer validates names and characters, escapes content, splits `]]>` in CDATA |

More details: [docs/SECURITY.md](docs/SECURITY.md).

---

## Error handling

All library exceptions derive from `EXmlForgeException` and carry structured information:
`ErrorCode` (the `XFE_*` constants), `Message`, `Line`, `Column`, `SourceName`, `Diagnostic`.

| Exception | Raised for |
|---|---|
| `EXmlParseException` | malformed XML |
| `EXmlNamespaceException` | unbound or invalid namespace prefixes |
| `EXmlEncodingException` | invalid or unsupported encodings |
| `EXmlSecurityException` | limit exceeded, external entity, prohibited DOCTYPE |
| `EXmlSerializationException` | invalid names/characters or misuse of the writer |
| `EXmlConversionException` | invalid JSON, invalid Infoset JSON, invalid element names |
| `EXmlValidationException` | schema problems, `ValidateOrRaise` |
| `EXmlXPathException` | XPath syntax or evaluation errors |
| `EXmlCancelledException` | parse cancelled |

```pascal
try
  Doc := TXmlDocument.LoadFromFile('broken.xml');
except
  on E: EXmlParseException do
    WriteLn(Format('XML error %d at line %d, column %d: %s', [E.ErrorCode, E.Line, E.Column, E.Message]));
  on E: EXmlSecurityException do
    WriteLn('Rejected by security policy: ', E.Message);
  on E: EXmlForgeException do
    WriteLn('XmlForge4D error: ', E.Message);
end;
```

---

## Large files and performance

* **Parse with SAX** for files that do not fit comfortably in memory; memory use is proportional to
  the nesting depth, not the file size.
* **Write with `TXmlWriter`** to a `TFileStream` for large exports.
* The DOM stores one object per node (attributes are nodes as well); budget roughly 150–300 bytes
  per node.
* Input is decoded incrementally in chunks (`TXmlParserOptions.BufferSize`).
* XPath results are sorted into document order with a cached numbering that is refreshed
  automatically when the document is modified.
* Parse each file with its own parser instance when using threads; instances are not thread-safe.

Measure on your own machine with the benchmark program (scenarios: small, medium and large files,
deeply nested documents, many attributes, repeated elements, mixed content; reports DOM parse, DOM
serialization, XML⇄JSON conversion, SAX parse and memory):

```
./build_fpc.sh bench 5        # scale factor 5 = five times larger documents
```

---

## Tests, benchmarks and examples

```
./build_fpc.sh test           # Free Pascal: build + run the test suite (Linux/macOS)
build_fpc.bat                 # Free Pascal on Windows
build_delphi.bat              # Delphi (RAD Studio command prompt)
./build_fpc.sh bench [scale]  # benchmarks
./build_fpc.sh examples       # build and run the Free Pascal examples
```

* `tests/XmlForge4D.TestSuite.pas` – framework-free test suite covering the parser, encodings,
  security limits, SAX, DOM, writer, standard and lossless conversion, round trips, XPath and XSD.
  The runner's exit code is the number of failed checks.
* `benchmarks/` – benchmark unit and program.
* `examples/Delphi/*.dpr` and `examples/FreePascal/*.lpr` – three complete programs:
  `ExampleXmlJson` (conversion), `ExampleDomXPath` (DOM, XPath, XSD) and `ExampleSax` (streaming).
* `.github/workflows/ci.yml` – CI for Free Pascal on Linux, Windows and macOS.

More documentation: [docs/API.md](docs/API.md) · [docs/CONVERSION_RULES.md](docs/CONVERSION_RULES.md) ·
[docs/INFOSET_JSON.md](docs/INFOSET_JSON.md) · [docs/SECURITY.md](docs/SECURITY.md) ·
[docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) · [AGENTS.md](AGENTS.md) (guidance for AI coding agents).

---

## Compatibility and design notes

* One string type everywhere: `XmlString = UnicodeString`; all character logic works on UTF-16 code
  units. Own UTF-8/UTF-16/Latin-1/ASCII codecs make results independent of the OS code page.
* Number parsing and formatting are locale independent.
* No generics, anonymous methods or other newer syntax; no unit outside the RTL is required.
* `TXmlDocument` is a class that you free (no interface reference counting); scoped enums are
  avoided for Free Pascal 3.0 compatibility, hence `cmStandard` / `cmLossless` instead of
  `TXmlConversionMode.Lossless`.
* `TXmlDocument.LoadFromFile / LoadFromStream / LoadFromString` are class functions returning a new
  document; to refill an existing one use `ParseFile / ParseStream / ParseString`.
* Namespace declarations are stored as attributes (`xmlns`, `xmlns:p`) so that serialization
  reproduces them; XPath's attribute axis hides them as required by the XPath data model.

---

## Limitations

* **DTD:** internal general entities only; no default attributes (`ATTLIST`), no DTD validation,
  parameter entities are skipped. Entity references are expanded while parsing, so the DOM and the
  JSON contain the replacement text.
* **XML 1.1:** the version is accepted and character references to control characters are allowed;
  NEL / LS line endings are not treated specially.
* **Encodings:** UTF-8, UTF-16 (LE/BE), ISO-8859-1 and US-ASCII; other declared encodings raise
  `EXmlEncodingException`.
* **Line endings** are normalized to LF on input, as required by the XML specification. Quote
  style, attribute order and `xmlns` order are not part of the supported information model.
* **XPath:** the `namespace::` axis and `id()` return empty node-sets; XPath 2.0/3.x is not
  supported (the API is designed so newer versions can be added).
* **XSD:** `pattern` facet, `list`/`union` types, `xsi:type`, substitution groups, identity
  constraints, ID/IDREF checks and XSD 1.1 are not supported (reported in `Schema.Warnings`).
* **Formats:** YAML and TOML are not included; the Universal Data Model is the extension point.

---

## License

MIT — see [LICENSE](LICENSE). Contributions and issue reports are welcome; AI coding agents should
read [AGENTS.md](AGENTS.md) first.
