program XmlForge4DTests;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  XmlForge4D.Types in '..\src\XmlForge4D.Types.pas',
  XmlForge4D.Encoding in '..\src\XmlForge4D.Encoding.pas',
  XmlForge4D.Parser in '..\src\XmlForge4D.Parser.pas',
  XmlForge4D.Writer in '..\src\XmlForge4D.Writer.pas',
  XmlForge4D.Dom in '..\src\XmlForge4D.Dom.pas',
  XmlForge4D.XPath in '..\src\XmlForge4D.XPath.pas',
  XmlForge4D.DataModel in '..\src\XmlForge4D.DataModel.pas',
  XmlForge4D.Json in '..\src\XmlForge4D.Json.pas',
  XmlForge4D.Convert in '..\src\XmlForge4D.Convert.pas',
  XmlForge4D.Schema in '..\src\XmlForge4D.Schema.pas',
  XmlForge4D.TestSuite in 'XmlForge4D.TestSuite.pas';

begin
  try
    ExitCode := RunAllTests;
  except
    on E: Exception do
    begin
      WriteLn('Unhandled exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;

  Readln;
end.
