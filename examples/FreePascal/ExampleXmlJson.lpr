{ XmlForge4D example: XML <-> JSON conversion: standard, lossless (XML Infoset JSON) and options.
  Free Pascal.  Build from the repository root:
    fpc -Mdelphiunicode -Fusrc -FUbuild/units -FEbuild/bin examples/FreePascal/ExampleXmlJson.lpr }
program ExampleXmlJson;

{$mode delphiunicode}
{$APPTYPE CONSOLE}

uses
  SysUtils, XmlForge4D.Types, XmlForge4D.Dom, XmlForge4D.Convert;

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
