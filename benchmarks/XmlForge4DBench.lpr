program XmlForge4DBench;

{$mode delphiunicode}
{$APPTYPE CONSOLE}

uses
  SysUtils, XmlForge4D.Bench, XmlForge4D.Types;

begin
  if ParamCount > 0 then
    RunBenchmarks(StrToIntDef(ParamStr(1), 1))
  else
    RunBenchmarks(1);

  Readln;
end.
