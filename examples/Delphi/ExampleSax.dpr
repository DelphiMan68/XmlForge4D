{ XmlForge4D example: SAX / streaming parsing without building a DOM.
  Delphi.  Open this project in the IDE, or from a RAD Studio command prompt:
    dcc64 -B ExampleSax.dpr }
program ExampleSax;

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

type
  TCountHandler = class(TXmlSaxHandler)
  public
    Elements: Integer;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); override;
  end;

procedure TCountHandler.StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
  Line, Column: Integer);
begin
  Inc(Elements);
  if QName = 'item' then WriteLn('item at line ', Line, ': id=', Attrs.ValueOf('id'));
end;

var
  P: TXmlParser;
  H: TCountHandler;
  Opts: TXmlParserOptions;
begin
  Opts := TXmlParserOptions.Default;
  Opts.BufferSize := 64 * 1024;        // streaming chunk size
  Opts.MaxDocumentSize := 512 * 1024 * 1024;
  P := TXmlParser.Create(Opts);
  H := TCountHandler.Create;
  try
    P.ParseString('<root><item id="1"/><item id="2"/><other/></root>', H);
    WriteLn('Elements: ', H.Elements);
  finally
    H.Free;
    P.Free;
  end;

  Readln;
end.
