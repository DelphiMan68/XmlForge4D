{$I ../src/XmlForge4D.inc}
unit XmlForge4D.TestSuite;

{ Self-contained test suite with no external framework, so it compiles with
  both Delphi and Free Pascal. RunAllTests returns the number of failures. }

interface

function RunAllTests: Integer;

implementation

uses
  SysUtils, Classes, Math,
  XmlForge4D.Types, XmlForge4D.Encoding, XmlForge4D.Parser, XmlForge4D.Writer,
  XmlForge4D.Dom, XmlForge4D.XPath, XmlForge4D.DataModel, XmlForge4D.Json,
  XmlForge4D.Convert, XmlForge4D.Schema;

var
  GPassed, GFailed: Integer;
  GGroup: string;

procedure Check(Cond: Boolean; const Name: string);
begin
  if Cond then
    Inc(GPassed)
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL [', GGroup, '] ', Name);
  end;
end;

procedure CheckEq(const Expected, Actual, Name: string);
begin
  if Expected = Actual then
    Inc(GPassed)
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL [', GGroup, '] ', Name);
    WriteLn('     expected: ', Expected);
    WriteLn('     actual  : ', Actual);
  end;
end;

procedure Group(const Name: string);
begin
  GGroup := Name;
  WriteLn('* ', Name);
end;

{ ---- helpers ---- }

function Parse(const Xml: XmlString): TXmlDocument;
begin
  Result := TXmlDocument.LoadFromString(Xml);
end;

function ParseRaises(const Xml: XmlString; ExClass: ExceptClass): Boolean;
var
  D: TXmlDocument;
begin
  Result := False;
  try
    D := TXmlDocument.LoadFromString(Xml);
    D.Free;
  except
    on E: Exception do Result := E is ExClass;
  end;
end;

function ParseRaisesOpt(const Xml: XmlString; const Opt: TXmlParserOptions; ExClass: ExceptClass): Boolean;
var
  D: TXmlDocument;
begin
  Result := False;
  try
    D := TXmlDocument.LoadFromString(Xml, Opt);
    D.Free;
  except
    on E: Exception do Result := E is ExClass;
  end;
end;

function JsonEq(const A, B: XmlString): Boolean;
var
  X, Y: TDataNode;
begin
  X := TJsonParser.ParseText(A);
  try
    Y := TJsonParser.ParseText(B);
    try
      Result := X.SameAs(Y);
    finally
      Y.Free;
    end;
  finally
    X.Free;
  end;
end;

function X2J(const Xml: XmlString): XmlString;
begin
  Result := TXmlJsonConverter.XmlTextToJson(Xml);
end;

function Sel(Doc: TXmlDocument; const XPath: XmlString): XmlString;
begin
  Result := Doc.SelectString(XPath);
end;

function NodeCount(Doc: TXmlDocument; const XPath: XmlString): Integer;
var
  L: TXmlNodeList;
begin
  L := Doc.SelectNodes(XPath);
  try
    Result := L.Count;
  finally
    L.Free;
  end;
end;

const
  PersonXml =
    '<?xml version="1.0" encoding="UTF-8"?>' + #10 +
    '<person id="123">' + #10 +
    '    <name>Shaahin</name>' + #10 +
    '    <age>35</age>' + #10 +
    '    <active>true</active>' + #10 +
    '    <address city="Tehran">' + #10 +
    '        <street>Example Street</street>' + #10 +
    '    </address>' + #10 +
    '    <skill>Delphi</skill>' + #10 +
    '    <skill>Free Pascal</skill>' + #10 +
    '</person>';

{ ---- SAX recorder ---- }

type
  TRecorder = class(TXmlSaxHandler)
  public
    Log: string;
    Elements, Texts, CDatas, Comments, PIs, Mappings: Integer;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); override;
    procedure EndElement(const Uri, LocalName, QName: XmlString); override;
    procedure Characters(const Text: XmlString); override;
    procedure CData(const Text: XmlString); override;
    procedure Comment(const Text: XmlString); override;
    procedure ProcessingInstruction(const Target, Data: XmlString); override;
    procedure StartPrefixMapping(const Prefix, Uri: XmlString); override;
  end;

procedure TRecorder.StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
  Line, Column: Integer);
begin
  Inc(Elements);
  Log := Log + '<' + QName + '>';
end;

procedure TRecorder.EndElement(const Uri, LocalName, QName: XmlString);
begin
  Log := Log + '</' + QName + '>';
end;

procedure TRecorder.Characters(const Text: XmlString);
begin
  Inc(Texts);
end;

procedure TRecorder.CData(const Text: XmlString);
begin
  Inc(CDatas);
end;

procedure TRecorder.Comment(const Text: XmlString);
begin
  Inc(Comments);
end;

procedure TRecorder.ProcessingInstruction(const Target, Data: XmlString);
begin
  Inc(PIs);
end;

procedure TRecorder.StartPrefixMapping(const Prefix, Uri: XmlString);
begin
  Inc(Mappings);
end;

{ ====================================================================== }

procedure TestParser;
var
  D: TXmlDocument;
  Opt: TXmlParserOptions;
begin
  Group('Parser');
  D := Parse(PersonXml);
  try
    CheckEq('person', D.DocumentElement.Name, 'root name');
    CheckEq('123', D.DocumentElement.AttributeValue['id'], 'attribute');
    CheckEq('Shaahin', Sel(D, '/person/name'), 'nested text');
    Check(D.HasDeclaration, 'declaration present');
    CheckEq('UTF-8', D.Encoding, 'declared encoding');
  finally
    D.Free;
  end;

  D := Parse('<a x="1" y=''2'' z="a&amp;b"><b/><c></c><d>t</d></a>');
  try
    CheckEq('2', D.DocumentElement.AttributeValue['y'], 'single-quoted attribute');
    CheckEq('a&b', D.DocumentElement.AttributeValue['z'], 'entity in attribute');
    CheckEq('3', IntToStr(D.DocumentElement.ChildCount), 'empty elements counted');
  finally
    D.Free;
  end;

  D := Parse('<r xmlns="urn:d" xmlns:p="urn:p"><p:x p:a="1" b="2"/><y/></r>');
  try
    CheckEq('urn:d', D.DocumentElement.NamespaceURI, 'default namespace');
    CheckEq('urn:p', TXmlElement(D.DocumentElement.Children[0]).NamespaceURI, 'prefixed element ns');
    CheckEq('1', TXmlElement(D.DocumentElement.Children[0]).GetAttributeNS('urn:p', 'a'), 'prefixed attribute by namespace');
    Check(TXmlElement(D.DocumentElement.Children[0]).FindAttributeNS('', 'b') <> nil, 'unprefixed attribute has no namespace');
    CheckEq('urn:d', D.DocumentElement.Children[1].NamespaceURI, 'default ns inherited');
  finally
    D.Free;
  end;
  Check(ParseRaises('<p:a/>', EXmlNamespaceException), 'unbound prefix');

  D := Parse('<a><![CDATA[<x>&]]><!-- c --><?pi data?>text</a>');
  try
    CheckEq('<x>&text', D.DocumentElement.TextContent, 'cdata + text content');
    Check(D.DocumentElement.Children[0].NodeType = ntCData, 'cdata node kind');
    Check(D.DocumentElement.Children[1].NodeType = ntComment, 'comment node kind');
    CheckEq('pi', D.DocumentElement.Children[2].Name, 'PI target');
    CheckEq('data', D.DocumentElement.Children[2].Value, 'PI data');
  finally
    D.Free;
  end;

  // Unicode (Persian) and characters outside the BMP
  D := Parse('<a>' + #$0633#$0644#$0627#$0645 + ' ' + #$D83D#$DE00 + '</a>');
  try
    CheckEq(#$0633#$0644#$0627#$0645 + ' ' + #$D83D#$DE00, D.DocumentElement.TextContent, 'unicode text');
  finally
    D.Free;
  end;

  D := Parse('<a>&#65;&#x42;&lt;&gt;&amp;&apos;&quot;</a>');
  try
    CheckEq('AB<>&''"', D.DocumentElement.TextContent, 'character and predefined references');
  finally
    D.Free;
  end;

  D := Parse('<a>x' + #13#10 + 'y' + #13 + 'z</a>');
  try
    CheckEq('x' + #10 + 'y' + #10 + 'z', D.DocumentElement.TextContent, 'line ending normalisation');
  finally
    D.Free;
  end;

  D := Parse('<!DOCTYPE a [<!ENTITY e "hello <b>bold</b>">]><a>&e;</a>');
  try
    CheckEq('hello bold', D.DocumentElement.TextContent, 'internal entity expansion');
    Check(D.DocumentElement.FindChildElement('b') <> nil, 'entity markup becomes elements');
    Check(D.DocType <> nil, 'doctype node');
  finally
    D.Free;
  end;

  Check(ParseRaises('<a><b></a>', EXmlParseException), 'mismatched tags');
  Check(ParseRaises('<a>', EXmlParseException), 'unclosed element');
  Check(ParseRaises('<a x="1" x="2"/>', EXmlParseException), 'duplicate attribute');
  Check(ParseRaises('<a>&nope;</a>', EXmlParseException), 'undefined entity');
  Check(ParseRaises('<a/><b/>', EXmlParseException), 'two root elements');
  Check(ParseRaises('text<a/>', EXmlParseException), 'text before root');
  Check(ParseRaises('<a x=1/>', EXmlParseException), 'unquoted attribute');
  Check(ParseRaises('<a><!-- bad -- comment --></a>', EXmlParseException), 'double hyphen in comment');
  Check(ParseRaises('<a>]]></a>', EXmlParseException), 'CDATA end in text');
  Check(ParseRaises('<a>' + #1 + '</a>', EXmlParseException), 'control character');
  Check(ParseRaises('', EXmlParseException), 'empty document');
  Check(ParseRaises('<a b="<"/>', EXmlParseException), '"<" in attribute value');
  try
    D := Parse('<a>' + #10 + '  <b></c></a>');
    D.Free;
    Check(False, 'error position raised');
  except
    on E: EXmlParseException do
    begin
      CheckEq('2', IntToStr(E.Line), 'error line');
      Check(E.Column > 0, 'error column');
      Check(E.ErrorCode = XFE_MISMATCHED_TAG, 'error code');
    end;
  end;

  // whitespace option
  Opt := TXmlParserOptions.Default;
  Opt.PreserveWhitespace := False;
  D := TXmlDocument.LoadFromString('<a> <b/> </a>', Opt);
  try
    CheckEq('1', IntToStr(D.DocumentElement.ChildCount), 'whitespace dropped when requested');
  finally
    D.Free;
  end;

end;

procedure TestLargeAndStreaming;
var
  S: XmlString;
  Buf: TXmlStrBuf;
  I: Integer;
  D: TXmlDocument;
  P: TXmlParser;
  H: TRecorder;
  Opt: TXmlParserOptions;
  M: TMemoryStream;
  Bytes: TBytes;
begin
  Group('Large documents / streaming');
  Buf := TXmlStrBuf.Create(1 shl 20);
  try
    Buf.Append('<?xml version="1.0"?><root>');
    for I := 1 to 20000 do
      Buf.Append('<item id="' + IntToStr(I) + '"><v>' + #$0633 + IntToStr(I) + '</v></item>');
    Buf.Append('</root>');
    S := Buf.AsString;
  finally
    Buf.Free;
  end;
  D := Parse(S);
  try
    CheckEq('20000', IntToStr(D.DocumentElement.ChildCount), 'large doc child count');
    CheckEq('20000', Sel(D, 'string(/root/item[20000]/@id)'), 'last attribute');
    CheckEq('20000', XmlFloatToStr(D.SelectNumber('count(//item)')), 'count()');
  finally
    D.Free;
  end;

  // tiny buffer: multi-byte UTF-8 sequences cross chunk boundaries
  Bytes := XmlUtf8Encode(S);
  M := TMemoryStream.Create;
  P := nil;
  H := TRecorder.Create;
  try
    M.WriteBuffer(Bytes[0], Length(Bytes));
    M.Position := 0;
    Opt := TXmlParserOptions.Default;
    Opt.BufferSize := 256;
    P := TXmlParser.Create(Opt);
    P.ParseStream(M, H);
    CheckEq('40001', IntToStr(H.Elements), 'SAX element count with small buffer');
  finally
    P.Free;
    H.Free;
    M.Free;
  end;
end;

procedure TestEncodings;
var
  M: TMemoryStream;
  D: TXmlDocument;
  B: array[0..1] of Byte;
  I: Integer;
  S: XmlString;
  Raw: TBytes;
begin
  Group('Encodings');
  S := '<a>' + #$0633 + 'A</a>';
  // UTF-16 LE with BOM
  M := TMemoryStream.Create;
  try
    B[0] := $FF; B[1] := $FE;
    M.WriteBuffer(B, 2);
    for I := 1 to Length(S) do
    begin
      B[0] := Ord(S[I]) and $FF;
      B[1] := Ord(S[I]) shr 8;
      M.WriteBuffer(B, 2);
    end;
    M.Position := 0;
    D := TXmlDocument.LoadFromStream(M);
    try
      CheckEq(#$0633 + 'A', D.DocumentElement.TextContent, 'UTF-16 LE with BOM');
    finally
      D.Free;
    end;
  finally
    M.Free;
  end;
  // UTF-16 BE without BOM
  M := TMemoryStream.Create;
  try
    for I := 1 to Length(S) do
    begin
      B[0] := Ord(S[I]) shr 8;
      B[1] := Ord(S[I]) and $FF;
      M.WriteBuffer(B, 2);
    end;
    M.Position := 0;
    D := TXmlDocument.LoadFromStream(M);
    try
      CheckEq(#$0633 + 'A', D.DocumentElement.TextContent, 'UTF-16 BE without BOM');
    finally
      D.Free;
    end;
  finally
    M.Free;
  end;
  // Latin-1 declared
  Raw := nil;
  SetLength(Raw, 0);
  M := TMemoryStream.Create;
  try
    S := '<?xml version="1.0" encoding="ISO-8859-1"?><a>caf' + #$E9 + '</a>';
    for I := 1 to Length(S) do
    begin
      B[0] := Ord(S[I]);
      M.WriteBuffer(B, 1);
    end;
    M.Position := 0;
    D := TXmlDocument.LoadFromStream(M);
    try
      CheckEq('caf' + #$E9, D.DocumentElement.TextContent, 'ISO-8859-1 declared');
    finally
      D.Free;
    end;
  finally
    M.Free;
  end;
  // UTF-8 BOM
  M := TMemoryStream.Create;
  try
    B[0] := $EF; M.WriteBuffer(B, 1);
    B[0] := $BB; M.WriteBuffer(B, 1);
    B[0] := $BF; M.WriteBuffer(B, 1);
    Raw := XmlUtf8Encode('<a>ok</a>');
    M.WriteBuffer(Raw[0], Length(Raw));
    M.Position := 0;
    D := TXmlDocument.LoadFromStream(M);
    try
      CheckEq('ok', D.DocumentElement.TextContent, 'UTF-8 BOM skipped');
    finally
      D.Free;
    end;
  finally
    M.Free;
  end;
  // invalid UTF-8
  M := TMemoryStream.Create;
  try
    S := '<a>';
    Raw := XmlUtf8Encode(S);
    M.WriteBuffer(Raw[0], Length(Raw));
    B[0] := $C3; M.WriteBuffer(B, 1);
    B[0] := $28; M.WriteBuffer(B, 1);
    M.Position := 0;
    try
      D := TXmlDocument.LoadFromStream(M);
      D.Free;
      Check(False, 'invalid UTF-8 rejected');
    except
      on E: EXmlEncodingException do Check(True, 'invalid UTF-8 rejected');
    end;
  finally
    M.Free;
  end;
  // writer round trip through every encoding
  D := Parse('<a>' + #$0633 + #$D83D#$DE00 + '</a>');
  try
    CheckEq(#$0633 + #$D83D#$DE00, D.DocumentElement.TextContent, 'surrogate pair parsed');
  finally
    D.Free;
  end;
end;

procedure TestSecurity;
var
  Opt: TXmlParserOptions;
  Lol: XmlString;
  I: Integer;
  Deep: XmlString;
begin
  Group('Security');
  Check(ParseRaises('<!DOCTYPE a [<!ENTITY x SYSTEM "file:///etc/passwd">]><a>&x;</a>', EXmlSecurityException),
    'XXE: external entity refused');
  Check(not ParseRaises('<!DOCTYPE a [<!ENTITY % p SYSTEM "http://example.invalid/x.dtd">]><a/>', Exception),
    'parameter entity declarations are parsed but never fetched');
  Opt := TXmlParserOptions.Default;
  Opt.IgnoreExternalEntities := True;
  Check(not ParseRaisesOpt('<!DOCTYPE a [<!ENTITY x SYSTEM "file:///etc/passwd">]><a>&x;</a>', Opt, Exception),
    'external entity can be ignored (expands to nothing)');

  Lol := '<!DOCTYPE lolz [<!ENTITY lol "lol">';
  Lol := Lol + '<!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">';
  for I := 2 to 9 do
    Lol := Lol + '<!ENTITY lol' + IntToStr(I) + ' "' + StringOfChar(' ', 0) +
      '&lol' + IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' +
      IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' +
      IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' + IntToStr(I - 1) + ';&lol' +
      IntToStr(I - 1) + ';">';
  Lol := Lol + ']><lolz>&lol9;</lolz>';
  Check(ParseRaises(Lol, EXmlSecurityException), 'billion laughs stopped by expansion limit');

  Check(ParseRaises('<!DOCTYPE a [<!ENTITY a "&a;">]><r>&a;</r>', EXmlSecurityException), 'recursive entity');

  Opt := TXmlParserOptions.Default;
  Opt.DtdMode := dtdProhibit;
  Check(ParseRaisesOpt('<!DOCTYPE a><a/>', Opt, EXmlSecurityException), 'DOCTYPE prohibited by option');

  Opt := TXmlParserOptions.Default;
  Opt.MaxDepth := 10;
  Deep := '';
  for I := 1 to 20 do Deep := Deep + '<a>';
  for I := 1 to 20 do Deep := Deep + '</a>';
  Check(ParseRaisesOpt(Deep, Opt, EXmlSecurityException), 'nesting depth limit');

  Opt := TXmlParserOptions.Default;
  Opt.MaxDocumentSize := 20;
  Check(ParseRaisesOpt('<a>' + StringOfChar('x', 100) + '</a>', Opt, EXmlSecurityException), 'document size limit');

  Opt := TXmlParserOptions.Default;
  Opt.MaxAttributes := 2;
  Check(ParseRaisesOpt('<a x="1" y="2" z="3"/>', Opt, EXmlSecurityException), 'attribute count limit');
end;

procedure TestSax;
var
  P: TXmlParser;
  H: TRecorder;
begin
  Group('SAX');
  P := TXmlParser.Create;
  H := TRecorder.Create;
  try
    P.ParseString('<a xmlns:p="urn:p"><b/><!--c--><?t d?><![CDATA[x]]>text<p:c/></a>', H);
    CheckEq('<a><b></b><p:c></p:c></a>', H.Log, 'event order');
    CheckEq('1', IntToStr(H.Comments), 'comment event');
    CheckEq('1', IntToStr(H.PIs), 'PI event');
    CheckEq('1', IntToStr(H.CDatas), 'CDATA event');
    CheckEq('1', IntToStr(H.Mappings), 'prefix mapping event');
  finally
    H.Free;
    P.Free;
  end;
end;

procedure TestDomAndWriter;
var
  D, D2: TXmlDocument;
  R, E, C: TXmlElement;
  N: TXmlNode;
  Opt: TXmlWriterOptions;
  M: TMemoryStream;
  S: XmlString;
begin
  Group('DOM + writer');
  D := TXmlDocument.Create;
  try
    R := D.AddRoot('root');
    R.SetAttribute('a', '1 & "2" < 3');
    E := R.AddElement('child');
    E.AddText('x < y & z');
    R.AddComment(' note ');
    R.AddCData('<raw>');
    CheckEq('<?xml version="1.0"?><root a="1 &amp; &quot;2&quot; &lt; 3"><child>x &lt; y &amp; z</child><!-- note --><![CDATA[<raw>]]></root>',
      D.ToXml, 'serialisation and escaping');
  finally
    D.Free;
  end;

  D := Parse('<r><a/><b>t</b><c><d/></c></r>');
  try
    CheckEq('<r>' + #10 + '  <a/>' + #10 + '  <b>t</b>' + #10 + '  <c>' + #10 + '    <d/>' + #10 + '  </c>' + #10 + '</r>',
      D.DocumentElement.ToXml(True), 'pretty printing');
    N := D.DocumentElement.FindChildElement('b');
    D.DocumentElement.DeleteChild(N);
    CheckEq('<r><a/><c><d/></c></r>', D.DocumentElement.ToXml, 'delete child');
    C := TXmlElement(D.DocumentElement.FindChildElement('c').CloneNode(True));
    D.DocumentElement.AppendChild(C);
    CheckEq('<r><a/><c><d/></c><c><d/></c></r>', D.DocumentElement.ToXml, 'clone + append');
    D2 := Parse('<x><y/></x>');
    try
      N := D.ImportNode(D2.DocumentElement, True);
      D.DocumentElement.AppendChild(N);
      CheckEq('1', IntToStr(NodeCount(D, '/r/x/y')), 'imported subtree is queryable');
      CheckEq('x', D.DocumentElement.LastChild.Name, 'imported node name');
    finally
      D2.Free;
    end;
    try
      D.DocumentElement.AppendChild(D.DocumentElement);
      Check(False, 'cycle prevented');
    except
      on EXmlForgeException do Check(True, 'cycle prevented');
    end;
    try
      D2 := Parse('<z/>');
      try
        D.DocumentElement.AppendChild(D2.DocumentElement);
        Check(False, 'cross-document insert prevented');
      finally
        D2.Free;
      end;
    except
      on EXmlForgeException do Check(True, 'cross-document insert prevented');
    end;
  finally
    D.Free;
  end;

  // namespaces in DOM
  D := TXmlDocument.Create;
  try
    R := D.AddRoot('p:root', 'urn:p');
    E := R.AddElement('child');
    Check(E.NamespaceURI = '', 'unprefixed child without default namespace');
    E := R.AddElement('p:other');
    CheckEq('urn:p', E.NamespaceURI, 'prefixed child resolves namespace');
    CheckEq('<?xml version="1.0"?><p:root xmlns:p="urn:p"><child/><p:other/></p:root>', D.ToXml, 'namespace serialisation');
    try
      R.AddElement('q:bad');
      Check(False, 'unbound prefix on AddElement');
    except
      on EXmlNamespaceException do Check(True, 'unbound prefix on AddElement');
    end;
  finally
    D.Free;
  end;

  // writer errors
  D := TXmlDocument.Create;
  try
    try
      D.AddRoot('1bad');
      Check(False, 'invalid element name rejected');
    except
      on EXmlForgeException do Check(True, 'invalid element name rejected');
    end;
    R := D.AddRoot('ok');
    R.AddText('bad' + #1);
    try
      D.ToXml;
      Check(False, 'invalid character rejected on write');
    except
      on EXmlSerializationException do Check(True, 'invalid character rejected on write');
    end;
  finally
    D.Free;
  end;

  // Latin-1 output uses character references for unrepresentable characters
  D := Parse('<a>' + #$0633 + #$E9 + '</a>');
  try
    Opt := TXmlWriterOptions.Default;
    Opt.Encoding := xeLatin1;
    M := TMemoryStream.Create;
    try
      D.SaveToStream(M, Opt);
      M.Position := 0;
      D2 := TXmlDocument.LoadFromStream(M);
      try
        CheckEq(#$0633 + #$E9, D2.DocumentElement.TextContent, 'Latin-1 output with char refs round-trips');
      finally
        D2.Free;
      end;
    finally
      M.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestXmlToJson;
var
  D: TXmlDocument;
  O: TXmlToJsonOptions;
begin
  Group('XML -> JSON (standard)');
  Check(JsonEq(
    '{"person":{"@id":"123","name":"Shaahin","age":35,"active":true,"address":{"@city":"Tehran","street":"Example Street"},"skill":["Delphi","Free Pascal"]}}',
    X2J(PersonXml)), 'specification example');
  Check(JsonEq('{"a":{"b":[1,2,3]}}', X2J('<a><b>1</b><b>2</b><b>3</b></a>')), 'repeated elements -> array');
  Check(JsonEq('{"a":{"b":"007","c":"12345678901234567890","d":-1.5e3}}',
    X2J('<a><b>007</b><c>12345678901234567890</c><d>-1.5e3</d></a>')), 'numeric detection rules');
  Check(JsonEq('{"a":{"b":null}}', X2J('<a><b/></a>')), 'empty element -> null');
  Check(JsonEq('{"a":{"@xmlns:xsi":"http://www.w3.org/2001/XMLSchema-instance","b":null}}',
    X2J('<a xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><b xsi:nil="true"/></a>')),
    'xsi:nil -> null, xmlns attribute kept');
  Check(JsonEq('{"a":{"b":{"@id":"1","#text":"x"}}}', X2J('<a><b id="1">x</b></a>')), 'attribute + text');

  O := TXmlToJsonOptions.Default;
  O.EmptyElementMode := emEmptyString;
  D := Parse('<a><b/></a>');
  try
    Check(JsonEq('{"a":{"b":""}}', TXmlJsonConverter.XmlToJson(D, O)), 'empty element -> ""');
    O.EmptyElementMode := emEmptyObject;
    Check(JsonEq('{"a":{"b":{}}}', TXmlJsonConverter.XmlToJson(D, O)), 'empty element -> {}');
    O := TXmlToJsonOptions.Default;
    O.RootElementMode := rmUnwrap;
    Check(JsonEq('{"b":null}', TXmlJsonConverter.XmlToJson(D, O)), 'unwrap root');
    O := TXmlToJsonOptions.Default;
    O.RepeatedElementMode := rpAlwaysArray;
    Check(JsonEq('{"a":{"b":[null]}}', TXmlJsonConverter.XmlToJson(D, O)), 'always array');
  finally
    D.Free;
  end;

  O := TXmlToJsonOptions.Default;
  O.ConvertNumbers := False;
  O.ConvertBooleans := False;
  Check(JsonEq('{"a":{"b":"1","c":"true"}}', TXmlJsonConverter.XmlTextToJson('<a><b>1</b><c>true</c></a>', O)),
    'conversion switches off');

  O := TXmlToJsonOptions.Default;
  O.AttributePrefix := '_';
  O.TextNodeName := '$';
  Check(JsonEq('{"a":{"_id":"1","$":"x"}}', TXmlJsonConverter.XmlTextToJson('<a id="1">x</a>', O)), 'custom prefixes');

  O := TXmlToJsonOptions.Default;
  O.PreserveComments := True;
  O.PreserveCDATA := True;
  Check(JsonEq('{"a":{"#cdata":"<x>","#comment":"c","b":1}}',
    TXmlJsonConverter.XmlTextToJson('<a><!--c--><![CDATA[<x>]]><b>1</b></a>', O)), 'comments and CDATA preserved');

  O := TXmlToJsonOptions.Default;
  O.PreserveNamespaces := False;
  Check(JsonEq('{"r":{"x":1}}', TXmlJsonConverter.XmlTextToJson('<p:r xmlns:p="urn:p"><p:x>1</p:x></p:r>', O)),
    'namespace prefixes stripped');
  Check(JsonEq('{"p:r":{"@xmlns:p":"urn:p","p:x":1}}', X2J('<p:r xmlns:p="urn:p"><p:x>1</p:x></p:r>')),
    'namespace prefixes and declarations preserved');
  Check(JsonEq('{"a":{"#text":"hello  world","b":"x"}}', X2J('<a>hello <b>x</b> world</a>')),
    'mixed content: text pieces concatenated, order not preserved');
end;

procedure TestJsonToXml;
var
  D: TXmlDocument;
  O: TJsonToXmlOptions;
  S: XmlString;
begin
  Group('JSON -> XML (standard)');
  D := TXmlJsonConverter.JsonToXml('{"person":{"@id":"123","name":"Shaahin","age":35,"active":true,"skill":["Delphi","Free Pascal"]}}');
  try
    CheckEq('<?xml version="1.0"?><person id="123"><name>Shaahin</name><age>35</age><active>true</active><skill>Delphi</skill><skill>Free Pascal</skill></person>',
      D.ToXml, 'specification example');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('{"a":{"b":{"c":"d"},"n":null,"t":"x<y&z"}}');
  try
    CheckEq('<?xml version="1.0"?><a><b><c>d</c></b><n/><t>x&lt;y&amp;z</t></a>', D.ToXml, 'nested, null, escaping');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('{"a":{"#text":"t","#cdata":"<c>","#comment":"c","b":1}}');
  try
    CheckEq('<?xml version="1.0"?><a>t<![CDATA[<c>]]><!--c--><b>1</b></a>', D.ToXml, 'text, CDATA, comment nodes');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('{"a":{"#children":["x",{"b":"1"},{"#comment":"c"},{"b":"2"}]}}');
  try
    CheckEq('<?xml version="1.0"?><a>x<b>1</b><!--c--><b>2</b></a>', D.ToXml, '#children keeps order');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('{"p:a":{"@xmlns:p":"urn:p","p:b":1}}');
  try
    CheckEq('urn:p', D.DocumentElement.NamespaceURI, 'namespace from @xmlns:p');
    CheckEq('urn:p', D.DocumentElement.Children[0].NamespaceURI, 'child namespace');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('{"a":1,"b":2}');
  try
    CheckEq('<?xml version="1.0"?><root><a>1</a><b>2</b></root>', D.ToXml, 'multiple members wrapped in <root>');
  finally
    D.Free;
  end;
  D := TXmlJsonConverter.JsonToXml('[1,2]');
  try
    CheckEq('<?xml version="1.0"?><root><item>1</item><item>2</item></root>', D.ToXml, 'top-level array');
  finally
    D.Free;
  end;
  O := TJsonToXmlOptions.Default;
  O.RootElementName := 'person';
  O.PrettyPrint := True;
  O.IncludeXMLDeclaration := True;
  S := TXmlJsonConverter.JsonToXmlText('{"name":"S","skill":["a","b"]}', O);
  CheckEq('<?xml version="1.0" encoding="UTF-8"?>' + #10 + '<person>' + #10 + '  <name>S</name>' + #10 +
    '  <skill>a</skill>' + #10 + '  <skill>b</skill>' + #10 + '</person>', S, 'pretty text with options');
  O := TJsonToXmlOptions.Default;
  O.IncludeXMLDeclaration := False;
  O.PrettyPrint := False;
  CheckEq('<a><b>1</b></a>', TXmlJsonConverter.JsonToXmlText('{"a":{"b":1}}', O), 'no declaration');
  O := TJsonToXmlOptions.Default;
  O.PreserveArrayElements := False;
  D := TXmlJsonConverter.JsonToXml('{"a":{"s":["x","y"]}}', O);
  try
    CheckEq('<?xml version="1.0"?><a><s><item>x</item><item>y</item></s></a>', D.ToXml, 'wrapped arrays');
  finally
    D.Free;
  end;
  try
    D := TXmlJsonConverter.JsonToXml('{"a":{"1bad name":"x"}}');
    D.Free;
    Check(False, 'invalid element name rejected');
  except
    on EXmlConversionException do Check(True, 'invalid element name rejected');
  end;
  O := TJsonToXmlOptions.Default;
  O.ValidateElementNames := False;
  D := TXmlJsonConverter.JsonToXml('{"a":{"1bad name":"x"}}', O);
  try
    CheckEq('_1bad_name', D.DocumentElement.Children[0].Name, 'invalid names sanitised when validation is off');
  finally
    D.Free;
  end;
  try
    D := TXmlJsonConverter.JsonToXml('{"q:a":1}');
    D.Free;
    Check(False, 'unbound prefix rejected');
  except
    on EXmlNamespaceException do Check(True, 'unbound prefix rejected');
  end;
  try
    D := TXmlJsonConverter.JsonToXml('{"a": }');
    D.Free;
    Check(False, 'JSON syntax error');
  except
    on E: EXmlConversionException do Check(E.ErrorCode = XFE_CONV_JSON_SYNTAX, 'JSON syntax error');
  end;
  D := TXmlJsonConverter.JsonToXml('{"a":"\u0633\ud83d\ude00\n"}');
  try
    CheckEq(#$0633 + #$D83D#$DE00 + #10, D.DocumentElement.TextContent, 'JSON escapes decoded');
  finally
    D.Free;
  end;
end;

procedure RoundTrip(const Xml, Name: XmlString);
var
  A, B: TXmlDocument;
  J: XmlString;
  Diff: XmlString;
begin
  A := Parse(Xml);
  try
    J := TXmlJsonConverter.XmlToJson(A, cmLossless);
    B := TXmlJsonConverter.JsonToXml(J, cmLossless);
    try
      if TXmlInfosetComparer.Equal(A, B, Diff) then
        Check(True, Name)
      else
      begin
        Check(False, Name + ': ' + Diff);
      end;
      // and the serialised XML must reparse to an equal model
    finally
      B.Free;
    end;
  finally
    A.Free;
  end;
end;

procedure TestLossless;
var
  D, B: TXmlDocument;
  J: XmlString;
  Root: TDataNode;
  Diff: XmlString;
begin
  Group('Lossless (XML Infoset JSON) + round trips');
  RoundTrip(PersonXml, 'round trip: person document');
  RoundTrip('<message id="10">' + #10 + '    Hello' + #10 + '    <name>Shaahin</name>' + #10 + '    <![CDATA[<raw-data>]]>' + #10 + '</message>',
    'round trip: mixed content + CDATA + whitespace');
  RoundTrip('<?xml version="1.1" encoding="UTF-8" standalone="yes"?><a/>', 'round trip: declaration metadata');
  RoundTrip('<a/>', 'round trip: no declaration');
  RoundTrip('<!-- before --><?pi data?><a><!--in--><?x y?></a><!-- after -->', 'round trip: comments and PIs');
  RoundTrip('<r xmlns="urn:d" xmlns:p="urn:p" p:at="1" plain="2"><p:x xmlns:p="urn:q"><y/></p:x><z xmlns=""/></r>',
    'round trip: namespaces, redeclaration, undeclaration');
  RoundTrip('<!DOCTYPE note SYSTEM "note.dtd" [<!ENTITY e "v">]><note>&e;</note>', 'round trip: DOCTYPE (entity expanded)');
  RoundTrip('<a>  </a>', 'round trip: whitespace-only text');
  RoundTrip('<a>x<![CDATA[y]]>z<![CDATA[w]]></a>', 'round trip: adjacent text and CDATA nodes');
  RoundTrip('<a>' + #$0633 + ' &lt;&amp;' + #$D83D#$DE00 + '</a>', 'round trip: unicode and escapes');
  RoundTrip('<a attr="line1&#10;line2&#9;tab"/>', 'round trip: attribute whitespace characters');

  D := Parse('<message id="10">' + #10 + '    Hello' + #10 + '    <name>Shaahin</name>' + #10 + '    <![CDATA[<raw-data>]]>' + #10 + '</message>');
  try
    J := TXmlJsonConverter.XmlToJson(D, cmLossless);
    Root := TJsonParser.ParseText(J);
    try
      CheckEq('XmlForge4D', Root.FindMember('$format').TextValue, '$format');
      CheckEq('1.0', Root.FindMember('$version').TextValue, '$version');
      Check(Root.FindMember('$document') <> nil, '$document member');
    finally
      Root.Free;
    end;
    Check(Pos('"type": "cdata"', J) > 0, 'CDATA node present in Infoset JSON');
    // JSON text -> XML text -> reparse -> equal model
    B := TXmlJsonConverter.JsonToXml(J, cmLossless);
    try
      B.ParseString(B.ToXml);
      Check(TXmlInfosetComparer.Equal(D, B, Diff), 'lossless through serialised XML: ' + Diff);
    finally
      B.Free;
    end;
  finally
    D.Free;
  end;

  try
    B := TXmlJsonConverter.JsonToXml('{"$format":"Other","$version":"1.0","$document":{"children":[]}}', cmLossless);
    B.Free;
    Check(False, 'wrong $format rejected');
  except
    on E: EXmlConversionException do Check(E.ErrorCode = XFE_CONV_BAD_INFOSET, 'wrong $format rejected');
  end;
  try
    B := TXmlJsonConverter.JsonToXml('{"$format":"XmlForge4D","$version":"9.0","$document":{"children":[]}}', cmLossless);
    B.Free;
    Check(False, 'unsupported version rejected');
  except
    on EXmlConversionException do Check(True, 'unsupported version rejected');
  end;
  try
    B := TXmlJsonConverter.JsonToXml('{"$format":"XmlForge4D","$version":"1.0","$document":{"children":[{"type":"bogus"}]}}', cmLossless);
    B.Free;
    Check(False, 'unknown node type rejected');
  except
    on EXmlConversionException do Check(True, 'unknown node type rejected');
  end;
end;

procedure TestXPath;
var
  D: TXmlDocument;
  X: TXPathExpression;
  L: TXmlNodeList;
const
  Lib =
    '<lib xmlns:b="urn:books" xml:lang="en">' +
    '<b:book id="1" price="10.5"><title>A</title><year>2001</year></b:book>' +
    '<b:book id="2" price="20"><title>B</title><year>1999</year></b:book>' +
    '<b:book id="3" price="5"><title>C</title><year>2010</year></b:book>' +
    '<note>hi <i>there</i></note><!--c--><?p d?></lib>';
begin
  Group('XPath 1.0');
  D := Parse(Lib);
  try
    CheckEq('3', XmlFloatToStr(D.SelectNumber('count(/lib/*[local-name()="book"])')), 'local-name()');
    X := TXPathExpression.Create('count(//b:book)');
    try
      X.AddNamespace('b', 'urn:books');
      CheckEq('3', XmlFloatToStr(X.EvaluateNumber(D)), 'registered namespace prefix');
    finally
      X.Free;
    end;
    CheckEq('3', XmlFloatToStr(D.SelectNumber('count(//b:book)')), 'in-scope namespace resolution');
    CheckEq('B', Sel(D, '//b:book[@id="2"]/title'), 'attribute predicate');
    CheckEq('C', Sel(D, '//b:book[3]/title'), 'positional predicate');
    CheckEq('C', Sel(D, '//b:book[last()]/title'), 'last()');
    CheckEq('B', Sel(D, '//b:book[year<2000]/title'), 'numeric comparison on node-set');
    CheckEq('2', XmlFloatToStr(D.SelectNumber('count(//b:book[@price>6])')), 'attribute number comparison');
    CheckEq('35.5', XmlFloatToStr(D.SelectNumber('sum(//b:book/@price)')), 'sum()');
    CheckEq('A', Sel(D, '(//title)[1]'), 'filter expression');
    CheckEq('3', XmlFloatToStr(D.SelectNumber('count(//b:book/title | //b:book/year) div 2')), 'union and div');
    CheckEq('1', XmlFloatToStr(D.SelectNumber('count(//note/i/ancestor::lib)')), 'ancestor axis');
    CheckEq('2', XmlFloatToStr(D.SelectNumber('count(//b:book[2]/preceding-sibling::*)+1')), 'preceding-sibling');
    CheckEq('2', XmlFloatToStr(D.SelectNumber('count(//b:book[1]/following-sibling::b:book)')), 'following-sibling');
    CheckEq('true', Sel(D, 'boolean(//note)'), 'boolean()');
    CheckEq('false', Sel(D, 'not(//note)'), 'not()');
    CheckEq('hi there', Sel(D, 'string(//note)'), 'string-value of element');
    CheckEq('HI', Sel(D, 'translate("hi","hi","HI")'), 'translate()');
    CheckEq('ell', Sel(D, 'substring("hello",2,3)'), 'substring()');
    CheckEq('5', Sel(D, 'string-length("hello")'), 'string-length()');
    CheckEq('a b c', Sel(D, 'normalize-space("  a   b c ")'), 'normalize-space()');
    CheckEq('ab', Sel(D, 'concat("a","b")'), 'concat()');
    CheckEq('true', Sel(D, 'contains("hello","ell") and starts-with("hello","he")'), 'contains/starts-with');
    CheckEq('lo', Sel(D, 'substring-after("hello","hel")'), 'substring-after()');
    CheckEq('he', Sel(D, 'substring-before("hello","llo")'), 'substring-before()');
    CheckEq('3', Sel(D, 'floor(3.7)'), 'floor()');
    CheckEq('4', Sel(D, 'ceiling(3.2)'), 'ceiling()');
    CheckEq('4', Sel(D, 'round(3.5)'), 'round()');
    CheckEq('1', Sel(D, '7 mod 3'), 'mod');
    CheckEq('NaN', Sel(D, 'number("abc")'), 'number() NaN');
    CheckEq('Infinity', Sel(D, '1 div 0'), 'division by zero');
    CheckEq('true', Sel(D, 'boolean(/lib[lang("en")])'), 'lang()');
    CheckEq('1', XmlFloatToStr(D.SelectNumber('count(//comment())')), 'comment() test');
    CheckEq('1', XmlFloatToStr(D.SelectNumber('count(//processing-instruction())')), 'processing-instruction() test');
    CheckEq('1', XmlFloatToStr(D.SelectNumber('count(//text()[normalize-space()="there"])')), 'text() test');
    CheckEq('3', XmlFloatToStr(D.SelectNumber('count(/lib/*) - 1')), 'arithmetic precedence');
    CheckEq('7', XmlFloatToStr(D.SelectNumber('count(//@*)')), 'attribute wildcard excludes namespace declarations');
    CheckEq('lib', Sel(D, 'name(/*)'), 'name()');
    CheckEq('urn:books', Sel(D, 'namespace-uri(//b:book[1])'), 'namespace-uri()');
    CheckEq('b:book', Sel(D, 'name(//b:book[1])'), 'qualified name()');
    CheckEq('3', XmlFloatToStr(D.SelectNumber('count(//b:*)')), 'prefix wildcard');
    CheckEq('lib', Sel(D, 'name(//year/../..)'), 'parent shorthand');
    CheckEq('1', Sel(D, '//b:book[1]/@id'), 'attribute shorthand');
    CheckEq('A', Sel(D, 'string(//b:book[@id=1]/title)'), 'number vs string attribute comparison');
    L := D.SelectNodes('//b:book');
    try
      CheckEq('3', IntToStr(L.Count), 'SelectNodes count');
      CheckEq('book', L[0].LocalName, 'SelectNodes item');
    finally
      L.Free;
    end;
    Check(D.SelectSingleNode('//nothing') = nil, 'SelectSingleNode returns nil');
    Check(D.SelectSingleNode('/lib/note') <> nil, 'SelectSingleNode');
    X := TXPathExpression.Create('//b:book[@id=$id]/title');
    try
      X.AddNamespace('b', 'urn:books');
      X.SetVariableString('id', '3');
      CheckEq('C', X.EvaluateString(D), 'variables');
    finally
      X.Free;
    end;
    X := TXPathExpression.Create('count(//book)');
    try
      X.DefaultElementNamespace := 'urn:books';
      CheckEq('3', XmlFloatToStr(X.EvaluateNumber(D)), 'default element namespace for unprefixed names');
    finally
      X.Free;
    end;
    try
      D.SelectNodes('//book[');
      Check(False, 'syntax error detected');
    except
      on EXmlXPathException do Check(True, 'syntax error detected');
    end;
    try
      D.SelectNodes('//zz:a');
      Check(False, 'unbound XPath prefix detected');
    except
      on EXmlXPathException do Check(True, 'unbound XPath prefix detected');
    end;
    try
      D.SelectNodes('nosuchfunction()');
      Check(False, 'unknown function detected');
    except
      on EXmlXPathException do Check(True, 'unknown function detected');
    end;
  finally
    D.Free;
  end;
  // document order after DOM modification
  D := Parse('<r><a/><b/></r>');
  try
    CheckEq('2', XmlFloatToStr(D.SelectNumber('count(/r/*)')), 'before modification');
    D.DocumentElement.InsertBefore(D.CreateElement('z'), D.DocumentElement.Children[0]);
    CheckEq('z', Sel(D, 'name(/r/*[1])'), 'order refreshed after modification');
    CheckEq('b', Sel(D, 'name((/r//*)[last()])'), 'descendant order');
  finally
    D.Free;
  end;
end;

procedure TestSchema;
var
  S: TXsdSchema;
  V: TXmlValidator;
  D: TXmlDocument;
const
  Xsd =
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="unqualified">' +
    '<xs:simpleType name="Level"><xs:restriction base="xs:string">' +
    '<xs:enumeration value="low"/><xs:enumeration value="high"/></xs:restriction></xs:simpleType>' +
    '<xs:simpleType name="Pct"><xs:restriction base="xs:integer">' +
    '<xs:minInclusive value="0"/><xs:maxInclusive value="100"/></xs:restriction></xs:simpleType>' +
    '<xs:complexType name="Person"><xs:sequence>' +
    '<xs:element name="name" type="xs:string"/>' +
    '<xs:element name="age" type="Pct" minOccurs="0"/>' +
    '<xs:element name="skill" type="xs:string" minOccurs="0" maxOccurs="unbounded"/>' +
    '</xs:sequence><xs:attribute name="id" type="xs:int" use="required"/>' +
    '<xs:attribute name="level" type="Level"/></xs:complexType>' +
    '<xs:element name="person" type="Person"/>' +
    '<xs:element name="when" type="xs:date"/>' +
    '<xs:element name="choice"><xs:complexType><xs:choice maxOccurs="2">' +
    '<xs:element name="a" type="xs:string"/><xs:element name="b" type="xs:string"/></xs:choice></xs:complexType></xs:element>' +
    '<xs:element name="all"><xs:complexType><xs:all>' +
    '<xs:element name="x" type="xs:string"/><xs:element name="y" type="xs:string" minOccurs="0"/></xs:all></xs:complexType></xs:element>' +
    '</xs:schema>';

  function Valid(const Xml: XmlString): Boolean;
  begin
    D := Parse(Xml);
    try
      Result := V.Validate(D);
    finally
      D.Free;
    end;
  end;

begin
  Group('XSD validation');
  S := TXsdSchema.LoadFromString(Xsd);
  V := TXmlValidator.Create(S);
  try
    Check(Valid('<person id="1"><name>S</name><age>35</age><skill>a</skill><skill>b</skill></person>'), 'valid person');
    Check(Valid('<person id="1" level="low"><name>S</name></person>'), 'optional parts omitted');
    Check(not Valid('<person><name>S</name></person>'), 'missing required attribute');
    Check(not Valid('<person id="x"><name>S</name></person>'), 'attribute type error');
    Check(not Valid('<person id="1"><age>5</age></person>'), 'missing required element');
    Check(not Valid('<person id="1"><name>S</name><age>150</age></person>'), 'facet maxInclusive');
    Check(not Valid('<person id="1"><name>S</name><age>abc</age></person>'), 'type error in element');
    Check(not Valid('<person id="1" level="mid"><name>S</name></person>'), 'enumeration violated');
    Check(not Valid('<person id="1"><skill>a</skill><name>S</name></person>'), 'wrong element order');
    Check(not Valid('<person id="1"><name>S</name><extra/></person>'), 'unexpected element');
    Check(not Valid('<person id="1" bogus="1"><name>S</name></person>'), 'undeclared attribute');
    Check(not Valid('<unknown/>'), 'unknown root');
    Check(Valid('<when>2024-02-29</when>'), 'valid date (leap day)');
    Check(not Valid('<when>2023-02-29</when>'), 'invalid date');
    Check(not Valid('<when>2024-13-01</when>'), 'invalid month');
    Check(Valid('<choice><a>1</a><b>2</b></choice>'), 'choice repeated');
    Check(not Valid('<choice><a>1</a><b>2</b><a>3</a></choice>'), 'choice maxOccurs exceeded');
    Check(Valid('<all><y>1</y><x>2</x></all>'), 'xs:all any order');
    Check(not Valid('<all><y>1</y></all>'), 'xs:all missing required');
    D := Parse('<person id="1"><name>S</name><age>150</age></person>');
    try
      V.Validate(D);
      Check(V.ErrorCount = 1, 'one error reported');
      Check(V.Errors[0].Line = 1, 'error has line information');
      Check(Pos('/person/age', V.Errors[0].Path) = 1, 'error has path');
      try
        V.ValidateOrRaise(D);
        Check(False, 'ValidateOrRaise raises');
      except
        on EXmlValidationException do Check(True, 'ValidateOrRaise raises');
      end;
    finally
      D.Free;
    end;
  finally
    V.Free;
    S.Free;
  end;
end;

type
  TTestProc = procedure;

{ Runs one test group; an unexpected exception is reported as a failure and the run continues. }
procedure RunGroup(const Name: string; Proc: TTestProc);
begin
  try
    Proc;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  EXCEPTION in group "', Name, '": ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

function RunAllTests: Integer;
begin
  GPassed := 0;
  GFailed := 0;
  // IEEE-754 behaviour (NaN / Infinity) instead of floating-point exceptions
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  WriteLn('XmlForge4D ', XMLFORGE4D_VERSION, ' test suite');
  RunGroup('Parser', TestParser);
  RunGroup('Large documents / streaming', TestLargeAndStreaming);
  RunGroup('Encodings', TestEncodings);
  RunGroup('Security', TestSecurity);
  RunGroup('SAX', TestSax);
  RunGroup('DOM + writer', TestDomAndWriter);
  RunGroup('XML -> JSON', TestXmlToJson);
  RunGroup('JSON -> XML', TestJsonToXml);
  RunGroup('Lossless', TestLossless);
  RunGroup('XPath', TestXPath);
  RunGroup('XSD', TestSchema);
  WriteLn;
  WriteLn('Passed: ', GPassed, '  Failed: ', GFailed);
  Result := GFailed;
end;

end.
