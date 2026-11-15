{$I XmlForge4D.inc}
unit XmlForge4D.Json;

{ RFC 8259 JSON parser / writer for the Universal Data Model.
  Numbers keep their literal text, so no precision is lost on round trips. }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Encoding, XmlForge4D.DataModel;

type
  TJsonParser = class
  private
    FS: XmlString;
    FPos, FLen, FMaxDepth: Integer;
    FBuf: TXmlStrBuf;
    procedure Fail(const Msg: XmlString);
    procedure SkipWs;
    function ParseValue(Depth: Integer): TDataNode;
    function ParseStringLiteral: XmlString;
    function ParseNumberLiteral: XmlString;
    function ParseHex4: Integer;
  public
    constructor Create(const AJson: XmlString; AMaxDepth: Integer);
    destructor Destroy; override;
    function Parse: TDataNode;
    { Caller owns the result. MaxDepth <= 0 means 512. }
    class function ParseText(const Json: XmlString; MaxDepth: Integer = 512): TDataNode;
    class function ParseStream(Stream: TStream; MaxDepth: Integer = 512): TDataNode;
    class function ParseFile(const FileName: string; MaxDepth: Integer = 512): TDataNode;
  end;

  TJsonWriter = class
  public
    class function Write(Node: TDataNode; Pretty: Boolean = False; IndentSize: Integer = 2;
      EscapeNonAscii: Boolean = False): XmlString;
    class procedure WriteToStream(Node: TDataNode; Stream: TStream; Pretty: Boolean = False;
      IndentSize: Integer = 2);
    class procedure WriteToFile(Node: TDataNode; const FileName: string; Pretty: Boolean = False;
      IndentSize: Integer = 2);
  end;

implementation

{ TJsonParser }

constructor TJsonParser.Create(const AJson: XmlString; AMaxDepth: Integer);
begin
  inherited Create;
  FS := AJson;
  FLen := System.Length(FS);
  FPos := 1;
  if AMaxDepth <= 0 then AMaxDepth := 512;
  FMaxDepth := AMaxDepth;
  FBuf := TXmlStrBuf.Create(64);
  if (FLen > 0) and (FS[1] = #$FEFF) then Inc(FPos);
end;

destructor TJsonParser.Destroy;
begin
  FBuf.Free;
  inherited Destroy;
end;

procedure TJsonParser.Fail(const Msg: XmlString);
var
  I, Line, Col: Integer;
begin
  Line := 1;
  Col := 1;
  for I := 1 to FPos - 1 do
  begin
    if I > FLen then Break;
    if FS[I] = #10 then
    begin
      Inc(Line);
      Col := 1;
    end
    else
      Inc(Col);
  end;
  raise EXmlConversionException.CreateCode(XFE_CONV_JSON_SYNTAX, 'JSON syntax error: ' + Msg, Line, Col);
end;

procedure TJsonParser.SkipWs;
begin
  while (FPos <= FLen) and ((FS[FPos] = ' ') or (FS[FPos] = #9) or (FS[FPos] = #10) or (FS[FPos] = #13)) do
    Inc(FPos);
end;

function TJsonParser.ParseHex4: Integer;
var
  I, D, C: Integer;
begin
  Result := 0;
  if FPos + 3 > FLen then Fail('Incomplete \u escape');
  for I := 0 to 3 do
  begin
    C := Ord(FS[FPos + I]);
    if (C >= 48) and (C <= 57) then D := C - 48
    else if (C >= 65) and (C <= 70) then D := C - 55
    else if (C >= 97) and (C <= 102) then D := C - 87
    else
    begin
      Fail('Invalid hex digit in \u escape');
      D := 0;
    end;
    Result := Result * 16 + D;
  end;
  Inc(FPos, 4);
end;

function TJsonParser.ParseStringLiteral: XmlString;
var
  C: WideChar;
  U: Integer;
begin
  Inc(FPos); // opening quote
  FBuf.Clear;
  while True do
  begin
    if FPos > FLen then Fail('Unterminated string');
    C := FS[FPos];
    Inc(FPos);
    if C = '"' then Break;
    if C = '\' then
    begin
      if FPos > FLen then Fail('Unterminated escape sequence');
      C := FS[FPos];
      Inc(FPos);
      case C of
        '"': FBuf.Append('"');
        '\': FBuf.Append('\');
        '/': FBuf.Append('/');
        'b': FBuf.Append(#8);
        'f': FBuf.Append(#12);
        'n': FBuf.Append(#10);
        'r': FBuf.Append(#13);
        't': FBuf.Append(#9);
        'u':
          begin
            U := ParseHex4;
            FBuf.AppendChar(WideChar(U));
          end;
      else
        Fail('Invalid escape sequence');
      end;
    end
    else if Ord(C) < 32 then
      Fail('Unescaped control character in string')
    else
      FBuf.AppendChar(C);
  end;
  Result := FBuf.AsString;
end;

function TJsonParser.ParseNumberLiteral: XmlString;
var
  Start: Integer;
begin
  Start := FPos;
  while (FPos <= FLen) and
        (((FS[FPos] >= '0') and (FS[FPos] <= '9')) or (FS[FPos] = '-') or (FS[FPos] = '+') or
         (FS[FPos] = '.') or (FS[FPos] = 'e') or (FS[FPos] = 'E')) do
    Inc(FPos);
  Result := Copy(FS, Start, FPos - Start);
  if not JsonNumberIsValid(Result) then
  begin
    FPos := Start;
    Fail('Invalid number "' + Result + '"');
  end;
end;

function TJsonParser.ParseValue(Depth: Integer): TDataNode;
var
  C: WideChar;
  Name: XmlString;
  Child: TDataNode;
begin
  if Depth > FMaxDepth then Fail('Maximum nesting depth exceeded');
  SkipWs;
  if FPos > FLen then Fail('Unexpected end of input');
  C := FS[FPos];
  case C of
    '{':
      begin
        Inc(FPos);
        Result := TDataNode.NewObject;
        try
          SkipWs;
          if (FPos <= FLen) and (FS[FPos] = '}') then
            Inc(FPos)
          else
            while True do
            begin
              SkipWs;
              if (FPos > FLen) or (FS[FPos] <> '"') then Fail('Object member name expected');
              Name := ParseStringLiteral;
              SkipWs;
              if (FPos > FLen) or (FS[FPos] <> ':') then Fail('":" expected after member name');
              Inc(FPos);
              Child := ParseValue(Depth + 1);
              Result.AddMember(Name, Child);
              SkipWs;
              if FPos > FLen then Fail('Unterminated object');
              if FS[FPos] = ',' then
                Inc(FPos)
              else if FS[FPos] = '}' then
              begin
                Inc(FPos);
                Break;
              end
              else
                Fail('"," or "}" expected');
            end;
        except
          Result.Free;
          raise;
        end;
      end;
    '[':
      begin
        Inc(FPos);
        Result := TDataNode.NewArray;
        try
          SkipWs;
          if (FPos <= FLen) and (FS[FPos] = ']') then
            Inc(FPos)
          else
            while True do
            begin
              Child := ParseValue(Depth + 1);
              Result.Add(Child);
              SkipWs;
              if FPos > FLen then Fail('Unterminated array');
              if FS[FPos] = ',' then
                Inc(FPos)
              else if FS[FPos] = ']' then
              begin
                Inc(FPos);
                Break;
              end
              else
                Fail('"," or "]" expected');
            end;
        except
          Result.Free;
          raise;
        end;
      end;
    '"':
      Result := TDataNode.NewString(ParseStringLiteral);
    't':
      begin
        if Copy(FS, FPos, 4) <> 'true' then Fail('Invalid literal');
        Inc(FPos, 4);
        Result := TDataNode.NewBoolean(True);
      end;
    'f':
      begin
        if Copy(FS, FPos, 5) <> 'false' then Fail('Invalid literal');
        Inc(FPos, 5);
        Result := TDataNode.NewBoolean(False);
      end;
    'n':
      begin
        if Copy(FS, FPos, 4) <> 'null' then Fail('Invalid literal');
        Inc(FPos, 4);
        Result := TDataNode.NewNull;
      end;
    '-', '0'..'9':
      Result := TDataNode.NewNumber(ParseNumberLiteral);
  else
    begin
      Fail('Unexpected character "' + C + '"');
      Result := nil;
    end;
  end;
end;

function TJsonParser.Parse: TDataNode;
begin
  Result := ParseValue(1);
  try
    SkipWs;
    if FPos <= FLen then Fail('Unexpected content after the JSON value');
  except
    Result.Free;
    raise;
  end;
end;

class function TJsonParser.ParseText(const Json: XmlString; MaxDepth: Integer): TDataNode;
var
  P: TJsonParser;
begin
  P := TJsonParser.Create(Json, MaxDepth);
  try
    Result := P.Parse;
  finally
    P.Free;
  end;
end;

class function TJsonParser.ParseStream(Stream: TStream; MaxDepth: Integer): TDataNode;
var
  B: TBytes;
  N: Integer;
begin
  SetLength(B, Stream.Size - Stream.Position);
  N := System.Length(B);
  if N > 0 then Stream.ReadBuffer(B[0], N);
  if (N >= 2) and (((B[0] = $FF) and (B[1] = $FE)) or ((B[0] = $FE) and (B[1] = $FF))) then
    raise EXmlEncodingException.CreateCode(XFE_ENC_UNSUPPORTED, 'JSON input must be UTF-8');
  Result := ParseText(XmlUtf8Decode(B), MaxDepth); // a leading BOM is skipped by the parser
end;

class function TJsonParser.ParseFile(const FileName: string; MaxDepth: Integer): TDataNode;
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ParseStream(FS, MaxDepth);
  finally
    FS.Free;
  end;
end;

{ TJsonWriter }

procedure WriteJsonString(B: TXmlStrBuf; const S: XmlString; EscapeNonAscii: Boolean);
var
  I, C: Integer;
begin
  B.Append('"');
  for I := 1 to System.Length(S) do
  begin
    C := Ord(S[I]);
    case C of
      34: B.Append('\"');
      92: B.Append('\\');
      8: B.Append('\b');
      9: B.Append('\t');
      10: B.Append('\n');
      12: B.Append('\f');
      13: B.Append('\r');
    else
      if (C < 32) or (EscapeNonAscii and (C > 126)) then
        B.Append('\u' + LowerCase(IntToHex(C, 4)))
      else
        B.AppendChar(S[I]);
    end;
  end;
  B.Append('"');
end;

procedure WriteJsonValue(B: TXmlStrBuf; Node: TDataNode; Pretty: Boolean; Indent, Level: Integer;
  EscapeNonAscii: Boolean);

  procedure NewLine(L: Integer);
  var
    K: Integer;
  begin
    B.Append(#10);
    for K := 1 to L * Indent do B.Append(' ');
  end;

var
  I: Integer;
begin
  case Node.Kind of
    dkNull: B.Append('null');
    dkBoolean: B.Append(Node.AsString);
    dkNumber: B.Append(Node.TextValue);
    dkString: WriteJsonString(B, Node.TextValue, EscapeNonAscii);
    dkArray:
      if Node.Count = 0 then
        B.Append('[]')
      else
      begin
        B.Append('[');
        for I := 0 to Node.Count - 1 do
        begin
          if I > 0 then B.Append(',');
          if Pretty then NewLine(Level + 1);
          WriteJsonValue(B, Node[I], Pretty, Indent, Level + 1, EscapeNonAscii);
        end;
        if Pretty then NewLine(Level);
        B.Append(']');
      end;
    dkObject:
      if Node.Count = 0 then
        B.Append('{}')
      else
      begin
        B.Append('{');
        for I := 0 to Node.Count - 1 do
        begin
          if I > 0 then B.Append(',');
          if Pretty then NewLine(Level + 1);
          WriteJsonString(B, Node.Names[I], EscapeNonAscii);
          if Pretty then B.Append(': ') else B.Append(':');
          WriteJsonValue(B, Node[I], Pretty, Indent, Level + 1, EscapeNonAscii);
        end;
        if Pretty then NewLine(Level);
        B.Append('}');
      end;
  end;
end;

class function TJsonWriter.Write(Node: TDataNode; Pretty: Boolean; IndentSize: Integer;
  EscapeNonAscii: Boolean): XmlString;
var
  B: TXmlStrBuf;
begin
  if IndentSize < 0 then IndentSize := 2;
  B := TXmlStrBuf.Create(1024);
  try
    WriteJsonValue(B, Node, Pretty, IndentSize, 0, EscapeNonAscii);
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

class procedure TJsonWriter.WriteToStream(Node: TDataNode; Stream: TStream; Pretty: Boolean;
  IndentSize: Integer);
var
  Bytes: TBytes;
begin
  Bytes := XmlUtf8Encode(Write(Node, Pretty, IndentSize));
  if System.Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], System.Length(Bytes));
end;

class procedure TJsonWriter.WriteToFile(Node: TDataNode; const FileName: string; Pretty: Boolean;
  IndentSize: Integer);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  try
    WriteToStream(Node, FS, Pretty, IndentSize);
  finally
    FS.Free;
  end;
end;

end.
