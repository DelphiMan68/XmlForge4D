{ XmlForge4D example: XML <-> JSON conversion: standard, lossless (XML Infoset JSON) and options.
  Delphi.  Open this project in the IDE, or from a RAD Studio command prompt:
    dcc64 -B ExampleXmlJson.dpr }
program ExampleXmlJson;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  XmlForge4D.Types in '..\..\src\XmlForge4D.Types.pas',
  XmlForge4D.Encoding in '..\..\src\XmlForge4D.Encoding.pas',
  XmlForge4D.Parser in '..\..\src\XmlForge4D.Parser.pas',
  XmlForge4D.Writer in '..\..\src\XmlForge4D.Writer.pas',
  XmlForge4D.Dom in '..\..\src\XmlForge4D.Dom.pas',
  XmlForge4D.XPath in '..\..\src\XmlForge4D.XPath.pas',
  XmlForge4D.DataModel in '..\..\src\XmlForge4D.DataModel.pas',
  XmlForge4D.Json in '..\..\src\XmlForge4D.Json.pas',
  XmlForge4D.Convert in '..\..\src\XmlForge4D.Convert.pas',
  XmlForge4D.Schema in '..\..\src\XmlForge4D.Schema.pas';

var
  Doc: TXmlDocument;
  Opts: TJsonToXmlOptions;
  Xml, Json: XmlString;
begin
  Xml :=
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<person id="123"><name>Shaahin</name><age>35</age><active>true</active>' +
    '<address city="Tehran"><street>Example Street</street></address>' +
    '<skill>Delphi</skill><skill>Free Pascal</skill></person>';

  WriteLn('--- XML -> JSON (standard) ---');
  WriteLn(TXmlJsonConverter.XmlTextToJson(Xml));

  WriteLn('--- XML -> XML Infoset JSON (lossless) ---');
  Doc := TXmlDocument.LoadFromString(Xml);
  try
    Json := TXmlJsonConverter.XmlToJson(Doc, cmLossless);
    WriteLn(Json);
  finally
    Doc.Free;
  end;

  WriteLn('--- Infoset JSON -> XML ---');
  Doc := TXmlJsonConverter.JsonToXml(Json, cmLossless);
  try
    WriteLn(Doc.ToXml(True));
  finally
    Doc.Free;
  end;

  WriteLn('--- JSON -> XML with options ---');
  Opts := TJsonToXmlOptions.Default;
  Opts.RootElementName := 'person';
  Opts.PrettyPrint := True;
  Opts.IncludeXMLDeclaration := True;
  WriteLn(TXmlJsonConverter.JsonToXmlText('{"@id":"7","name":"Ali","skill":["Delphi","FPC"]}', Opts));

  Readln;
end.
