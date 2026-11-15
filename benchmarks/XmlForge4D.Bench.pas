{$I ../src/XmlForge4D.inc}
unit XmlForge4D.Bench;

{ Benchmarks: parsing (DOM / SAX), serialisation, XML<->JSON conversion, memory.
  Usage:  XmlForge4DBench [scale]     (scale 1 = default, 5 = 5x larger documents) }

interface

procedure RunBenchmarks(Scale: Integer);

implementation

uses
  SysUtils, Classes, DateUtils,
  XmlForge4D.Types, XmlForge4D.Encoding, XmlForge4D.Parser, XmlForge4D.Writer,
  XmlForge4D.Dom, XmlForge4D.DataModel, XmlForge4D.Json, XmlForge4D.Convert;

type
  TCounter = class(TXmlSaxHandler)
  public
    Elements: Int64;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); override;
  end;

procedure TCounter.StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
  Line, Column: Integer);
begin
  Inc(Elements);
end;

function HeapUsed: Int64;
{$IFDEF FPC}
begin
  Result := GetFPCHeapStatus.CurrHeapUsed;
end;
{$ELSE}
var
  St: TMemoryManagerState;
  I: Integer;
begin
  GetMemoryManagerState(St);
  Result := St.TotalAllocatedMediumBlockSize + St.TotalAllocatedLargeBlockSize;
  for I := Low(St.SmallBlockTypeStates) to High(St.SmallBlockTypeStates) do
    Inc(Result, Int64(St.SmallBlockTypeStates[I].UseableBlockSize) * St.SmallBlockTypeStates[I].AllocatedBlockCount);
end;
{$ENDIF}

function Ms(const T0: TDateTime): Int64;
begin
  Result := MilliSecondsBetween(Now, T0);
end;

function MB(Bytes: Int64): string;
begin
  Result := FormatFloat('0.0', Bytes / (1024 * 1024)) + ' MB';
end;

function Gen(const Kind: string; Scale: Integer): TBytes;
var
  B: TXmlStrBuf;
  I, J, N: Integer;
begin
  B := TXmlStrBuf.Create(1 shl 20);
  try
    B.Append('<?xml version="1.0" encoding="UTF-8"?><root>');
    if (Kind = 'small') or (Kind = 'medium') or (Kind = 'large') then
    begin
      if Kind = 'small' then N := 10
      else if Kind = 'medium' then N := 10000 * Scale
      else N := 200000 * Scale;
      for I := 1 to N do
        B.Append('<item id="' + IntToStr(I) + '" kind="k' + IntToStr(I mod 7) + '"><name>Item ' + IntToStr(I) +
          '</name><price>' + IntToStr(I mod 1000) + '.5</price><tag>a</tag><tag>b</tag></item>');
    end
    else if Kind = 'deep' then
    begin
      for I := 1 to 200 do B.Append('<d>');
      B.Append('x');
      for I := 1 to 200 do B.Append('</d>');
    end
    else if Kind = 'attributes' then
    begin
      for I := 1 to 3000 * Scale do
      begin
        B.Append('<e');
        for J := 1 to 50 do B.Append(' a' + IntToStr(J) + '="' + IntToStr(I + J) + '"');
        B.Append('/>');
      end;
    end
    else if Kind = 'repeated' then
    begin
      for I := 1 to 100000 * Scale do B.Append('<v>' + IntToStr(I) + '</v>');
    end
    else if Kind = 'mixed' then
    begin
      for I := 1 to 30000 * Scale do
        B.Append('<p>text ' + IntToStr(I) + ' <b>bold</b> more <i>it</i> end</p>');
    end;
    B.Append('</root>');
    Result := XmlUtf8Encode(B.AsString);
  finally
    B.Free;
  end;
end;

procedure Bench(const Kind: string; Scale: Integer);
var
  Data: TBytes;
  M, Out: TMemoryStream;
  D, Doc2: TXmlDocument;
  P: TXmlParser;
  C: TCounter;
  T0: TDateTime;
  H0, H1: Int64;
  Json, Lossless: XmlString;
  Opt: TXmlParserOptions;
begin
  Data := Gen(Kind, Scale);
  WriteLn;
  WriteLn('== ', Kind, ' (', MB(Length(Data)), ') ==');
  M := TMemoryStream.Create;
  try
    M.WriteBuffer(Data[0], Length(Data));
    Opt := TXmlParserOptions.Default;
    Opt.MaxDepth := 1000;

    M.Position := 0;
    H0 := HeapUsed;
    T0 := Now;
    D := TXmlDocument.LoadFromStream(M, Opt);
    try
      H1 := HeapUsed;
      WriteLn('DOM parse            : ', Ms(T0), ' ms, DOM memory ~ ', MB(H1 - H0));

      Out := TMemoryStream.Create;
      try
        T0 := Now;
        D.SaveToStream(Out);
        WriteLn('DOM serialise        : ', Ms(T0), ' ms (', MB(Out.Size), ')');
      finally
        Out.Free;
      end;

      if Length(Data) < 60 * 1024 * 1024 then
      begin
        T0 := Now;
        Json := TXmlJsonConverter.XmlToJson(D);
        WriteLn('XML -> JSON standard : ', Ms(T0), ' ms (', MB(Length(Json) * 2), ' as UTF-16)');
        T0 := Now;
        Doc2 := TXmlJsonConverter.JsonToXml(Json);
        WriteLn('JSON -> XML standard : ', Ms(T0), ' ms');
        Doc2.Free;
        T0 := Now;
        Lossless := TXmlJsonConverter.XmlToJson(D, cmLossless);
        WriteLn('XML -> Infoset JSON  : ', Ms(T0), ' ms (', MB(Length(Lossless) * 2), ' as UTF-16)');
        T0 := Now;
        Doc2 := TXmlJsonConverter.JsonToXml(Lossless, cmLossless);
        WriteLn('Infoset JSON -> XML  : ', Ms(T0), ' ms');
        Doc2.Free;
      end;
    finally
      D.Free;
    end;

    M.Position := 0;
    H0 := HeapUsed;
    P := TXmlParser.Create(Opt);
    C := TCounter.Create;
    try
      T0 := Now;
      P.ParseStream(M, C);
      WriteLn('SAX parse            : ', Ms(T0), ' ms, ', C.Elements, ' elements, memory delta ~ ',
        MB(HeapUsed - H0));
    finally
      C.Free;
      P.Free;
    end;
  finally
    M.Free;
  end;
end;

procedure RunBenchmarks(Scale: Integer);
begin
  if Scale < 1 then Scale := 1;
  WriteLn('XmlForge4D ', XMLFORGE4D_VERSION, ' benchmarks (scale ', Scale, ')');
  Bench('small', Scale);
  Bench('medium', Scale);
  Bench('large', Scale);
  Bench('deep', Scale);
  Bench('attributes', Scale);
  Bench('repeated', Scale);
  Bench('mixed', Scale);
end;

end.
