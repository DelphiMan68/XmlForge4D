{ XmlForge4D example: SAX / streaming parsing without building a DOM.
  Free Pascal.  Build from the repository root:
    fpc -Mdelphiunicode -Fusrc -FUbuild/units -FEbuild/bin examples/FreePascal/ExampleSax.lpr }
program ExampleSax;

{$mode delphiunicode}
{$APPTYPE CONSOLE}

uses
  SysUtils, XmlForge4D.Types, XmlForge4D.Parser;

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
