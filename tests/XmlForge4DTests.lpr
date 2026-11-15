program XmlForge4DTests;

{$mode delphiunicode}
{$APPTYPE CONSOLE}

uses
  SysUtils, XmlForge4D.TestSuite, XmlForge4D.Types;

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
