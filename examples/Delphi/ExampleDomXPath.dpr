{ XmlForge4D example: DOM building, XPath queries and XSD validation.
  Delphi.  Open this project in the IDE, or from a RAD Studio command prompt:
    dcc64 -B ExampleDomXPath.dpr }
program ExampleDomXPath;

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

const
  Xsd =
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">' +
    '<xs:element name="library"><xs:complexType><xs:sequence>' +
    '<xs:element name="book" maxOccurs="unbounded"><xs:complexType><xs:sequence>' +
    '<xs:element name="title" type="xs:string"/><xs:element name="year" type="xs:gYear"/>' +
    '</xs:sequence><xs:attribute name="id" type="xs:int" use="required"/></xs:complexType></xs:element>' +
    '</xs:sequence></xs:complexType></xs:element></xs:schema>';
var
  Doc: TXmlDocument;
  Root, Book: TXmlElement;
  Nodes: TXmlNodeList;
  Schema: TXsdSchema;
  Validator: TXmlValidator;
  I: Integer;
begin
  Doc := TXmlDocument.Create;
  try
    Root := Doc.AddRoot('library');
    Book := Root.AddElement('book');
    Book.SetAttribute('id', '1');
    Book.AddElementWithText('title', 'Object Pascal Handbook');
    Book.AddElementWithText('year', '2023');
    Book := Root.AddElement('book');
    Book.SetAttribute('id', 'two');   // invalid on purpose
    Book.AddElementWithText('title', 'Free Pascal Guide');
    Book.AddElementWithText('year', '2021');

    WriteLn(Doc.ToXml(True));

    Nodes := Doc.SelectNodes('/library/book[year > 2022]/title');
    try
      for I := 0 to Nodes.Count - 1 do
        WriteLn('XPath match: ', Nodes[I].TextContent);
    finally
      Nodes.Free;
    end;
    WriteLn('Books: ', Trunc(Doc.SelectNumber('count(//book)')));

    Schema := TXsdSchema.LoadFromString(Xsd);
    try
      Validator := TXmlValidator.Create(Schema);
      try
        if Validator.Validate(Doc) then
          WriteLn('Document is valid')
        else
          WriteLn(Validator.ErrorsAsText);
      finally
        Validator.Free;
      end;
    finally
      Schema.Free;
    end;
  finally
    Doc.Free;
  end;

  Readln;
end.
