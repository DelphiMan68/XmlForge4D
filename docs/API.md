# API reference (condensed)

All strings are `XmlString` (= `UnicodeString`). Exceptions derive from `EXmlForgeException`
(`ErrorCode`, `Line`, `Column`, `SourceName`, `Diagnostic`): `EXmlParseException`,
`EXmlSerializationException`, `EXmlConversionException`, `EXmlValidationException`,
`EXmlNamespaceException`, `EXmlEncodingException`, `EXmlSecurityException`, `EXmlXPathException`,
`EXmlCancelledException`. Codes are the `XFE_*` constants in `XmlForge4D.Types`.

## XmlForge4D.Parser
* `TXmlParserOptions.Default` — `NamespaceAware`, `PreserveWhitespace`, `DtdMode`,
  `IgnoreExternalEntities`, `MaxDocumentSize`, `MaxDepth`, `MaxEntityExpansion`, `MaxEntityDepth`,
  `MaxAttributes`, `BufferSize`.
* `TXmlParser` — `ParseStream / ParseFile / ParseString(…, Handler)`, `Cancel`, `OnCancel`.
* `TXmlSaxHandler` — override `StartDocument, EndDocument, DocType, StartPrefixMapping,
  EndPrefixMapping, StartElement, EndElement, Characters, CData, Comment, ProcessingInstruction,
  FatalError`. `TXmlSaxAttributes`: `Count, QName[i], LocalName[i], Prefix[i], NamespaceURI[i],
  Value[i], IndexOf, IndexOfNS, ValueOf`.

## XmlForge4D.Dom
* `TXmlDocument` — `Create`, `LoadFromFile/Stream/String` (class functions), `ParseFile/Stream/String`,
  `SaveToFile/Stream`, `ToXml(Pretty)`, `AddRoot`, `CreateElement[NS]`, `CreateAttribute[NS]`,
  `CreateTextNode`, `CreateCDataSection`, `CreateComment`, `CreateProcessingInstruction`,
  `CreateDocType`, `ImportNode`, `Clear`, `DocumentElement`, `DocType`, `XmlVersion`, `Encoding`,
  `Standalone`, `HasDeclaration`.
* `TXmlNode` — `NodeType, Name, LocalName, Prefix, NamespaceURI, Value, TextContent, ParentNode,
  OwnerDocument, Line, Column, ChildCount, Children[i], FirstChild, LastChild, NextSibling,
  PreviousSibling, AppendChild, InsertBefore, RemoveChild, DeleteChild, ReplaceChild,
  RemoveAllChildren, CloneNode, LookupNamespaceURI, LookupPrefix, SelectNodes, SelectSingleNode,
  SelectString, SelectNumber, SelectBoolean, ToXml`.
* `TXmlElement` — `AttributeCount, Attributes[i], AttributeValue[name], FindAttribute[NS],
  HasAttribute, TryGetAttribute, GetAttributeNS, SetAttribute, SetAttributeNS, RemoveAttribute,
  DeclareNamespace, AddElement, AddElementWithText, AddText, AddCData, AddComment,
  FindChildElement[NS], GetElementsByTagName`.
* `TXmlNodeList` — non-owning result list (`Count`, `Items[i]`); free it.

## XmlForge4D.Writer
`TXmlWriterOptions.Default` (`Indent, IndentSize, NewLine, Encoding, WriteBom, DeclarationMode,
SelfCloseEmpty, ValidateNames, ValidateChars, BufferSize`); `TXmlWriter` (`Create(Stream, Opts)`,
`CreateToString(Opts)`, `WriteStartDocument, WriteDocType, WriteStartElement, WriteAttribute,
WriteEndElement, WriteFullEndElement, WriteElementString, WriteText, WriteCData, WriteComment,
WriteProcessingInstruction, WriteRaw, EndDocument, Flush, Text`).

## XmlForge4D.XPath
`TXPathExpression.Create(expr)`, `AddNamespace`, `SetVariable*`, `DefaultElementNamespace`,
`Evaluate / SelectNodes / SelectSingleNode / EvaluateString / EvaluateNumber / EvaluateBoolean`.

## XmlForge4D.Schema
`TXsdSchema.LoadFromFile/LoadFromString`, `AddSchemaDocument`, `Warnings`;
`TXmlValidator.Create(Schema)`, `Validate`, `ValidateOrRaise`, `ErrorCount`, `Errors[i]`
(`Message, Line, Column, Path`), `ErrorsAsText`.

## XmlForge4D.DataModel / Json
`TDataNode` (`Kind, Count, Items, Names, AddMember, InsertMember, Add, FindMember, AsString,
AsDouble, Clone, SameAs`, class constructors `NewNull/NewBoolean/NewNumber/NewString/NewArray/NewObject`);
`TJsonParser.ParseText/ParseStream/ParseFile`; `TJsonWriter.Write/WriteToStream/WriteToFile`.

## XmlForge4D.Convert
`TXmlJsonConverter`: `XmlToJson`, `XmlTextToJson`, `JsonToXml`, `JsonToXmlText`, `XmlToUdm`,
`UdmToXml`, `DocumentToInfoset`, `InfosetToDocument`; `TXmlToJsonOptions`, `TJsonToXmlOptions`
(`.Default`); `TXmlInfosetComparer.Equal`.
