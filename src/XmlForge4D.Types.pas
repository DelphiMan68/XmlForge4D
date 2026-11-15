{$I XmlForge4D.inc}
unit XmlForge4D.Types;

{ Core types, structured exceptions and small shared helpers. }

interface

uses
  SysUtils, Classes, Math;

const
  XMLFORGE4D_VERSION = '1.0.0';

  XML_NS_URI   = 'http://www.w3.org/XML/1998/namespace';
  XMLNS_NS_URI = 'http://www.w3.org/2000/xmlns/';
  XSI_NS_URI   = 'http://www.w3.org/2001/XMLSchema-instance';
  XSD_NS_URI   = 'http://www.w3.org/2001/XMLSchema';

  { ---- error codes ---- }
  XFE_UNKNOWN              = 1;
  XFE_PARSE_GENERIC        = 100;
  XFE_UNEXPECTED_EOF       = 101;
  XFE_INVALID_CHAR         = 102;
  XFE_INVALID_NAME         = 103;
  XFE_MISMATCHED_TAG       = 104;
  XFE_DUPLICATE_ATTRIBUTE  = 105;
  XFE_BAD_ATTRIBUTE        = 106;
  XFE_BAD_REFERENCE        = 107;
  XFE_UNDEFINED_ENTITY     = 108;
  XFE_MULTIPLE_ROOT        = 109;
  XFE_NO_ROOT              = 110;
  XFE_BAD_DECLARATION      = 111;
  XFE_BAD_COMMENT          = 112;
  XFE_BAD_PI               = 113;
  XFE_BAD_CDATA            = 114;
  XFE_BAD_DOCTYPE          = 115;
  XFE_TEXT_OUTSIDE_ROOT    = 116;
  XFE_NS_UNBOUND_PREFIX    = 200;
  XFE_NS_INVALID           = 201;
  XFE_ENC_INVALID          = 300;
  XFE_ENC_UNSUPPORTED      = 301;
  XFE_SEC_DTD_PROHIBITED   = 400;
  XFE_SEC_EXTERNAL_ENTITY  = 401;
  XFE_SEC_ENTITY_LIMIT     = 402;
  XFE_SEC_DEPTH_LIMIT      = 403;
  XFE_SEC_SIZE_LIMIT       = 404;
  XFE_SEC_RECURSIVE_ENTITY = 405;
  XFE_SEC_ATTRIBUTE_LIMIT  = 406;
  XFE_SER_INVALID_NAME     = 500;
  XFE_SER_INVALID_CHAR     = 501;
  XFE_SER_INVALID_STATE    = 502;
  XFE_SER_INVALID_CONTENT  = 503;
  XFE_CONV_GENERIC         = 600;
  XFE_CONV_JSON_SYNTAX     = 601;
  XFE_CONV_BAD_INFOSET     = 602;
  XFE_CONV_BAD_NAME        = 603;
  XFE_CONV_UNSUPPORTED     = 604;
  XFE_VAL_GENERIC          = 700;
  XFE_VAL_SCHEMA           = 701;
  XFE_XPATH_SYNTAX         = 800;
  XFE_XPATH_EVAL           = 801;
  XFE_CANCELLED            = 900;
  XFE_DOM_INVALID          = 950;

type
  XmlString = UnicodeString;
  TWideCharArray = array of WideChar;

  TXmlStandalone = (xsUnspecified, xsYes, xsNo);

  TXmlCancelEvent = procedure(Sender: TObject; var Cancel: Boolean) of object;

  { ---- exceptions ---- }
  EXmlForgeException = class(Exception)
  private
    FErrorCode: Integer;
    FLine: Integer;
    FColumn: Integer;
    FSourceName: XmlString;
    FDiagnostic: XmlString;
  public
    constructor CreateCode(ACode: Integer; const AMessage: XmlString;
      ALine: Integer = 0; AColumn: Integer = 0);
    property ErrorCode: Integer read FErrorCode write FErrorCode;
    property Line: Integer read FLine write FLine;
    property Column: Integer read FColumn write FColumn;
    property SourceName: XmlString read FSourceName write FSourceName;
    property Diagnostic: XmlString read FDiagnostic write FDiagnostic;
  end;

  EXmlParseException         = class(EXmlForgeException);
  EXmlSerializationException = class(EXmlForgeException);
  EXmlConversionException    = class(EXmlForgeException);
  EXmlValidationException    = class(EXmlForgeException);
  EXmlNamespaceException     = class(EXmlForgeException);
  EXmlEncodingException      = class(EXmlForgeException);
  EXmlSecurityException      = class(EXmlForgeException);
  EXmlXPathException         = class(EXmlForgeException);
  EXmlCancelledException     = class(EXmlForgeException);

  { ---- growable UTF-16 string buffer ---- }
  TXmlStrBuf = class
  private
    FData: TWideCharArray;
    FLen: Integer;
    procedure Grow(MinCap: Integer);
  public
    constructor Create(InitialCapacity: Integer = 256);
    procedure Clear;
    procedure AppendChar(C: WideChar);
    procedure Append(const S: XmlString);
    procedure AppendCodePoint(CP: Cardinal);
    function AsString: XmlString;
    function EndsWith(C1, C2: WideChar): Boolean;
    procedure Truncate(NewLen: Integer);
    property Len: Integer read FLen;
  end;

{ ---- character classes (C is a UTF-16 code unit value) ---- }
function XmlIsNameStartChar(C: Integer): Boolean;
function XmlIsNameChar(C: Integer): Boolean;
function XmlIsNCNameStartChar(C: Integer): Boolean;
function XmlIsNCNameChar(C: Integer): Boolean;
function XmlIsWhite(C: Integer): Boolean;

function XmlIsValidName(const S: XmlString): Boolean;
function XmlIsValidNCName(const S: XmlString): Boolean;
function XmlIsValidQName(const S: XmlString): Boolean;
function XmlSplitQName(const QName: XmlString; out Prefix, Local: XmlString): Boolean;
function XmlIsAllWhite(const S: XmlString): Boolean;
function XmlTrimWhite(const S: XmlString): XmlString;
{ Makes an arbitrary string a valid XML name (invalid chars -> '_'). }
function XmlSanitizeName(const S: XmlString; AllowColon: Boolean = False): XmlString;
{ True if code point is allowed in an XML 1.0 document. }
function XmlIsXmlChar(CP: Cardinal): Boolean;

{ ---- number helpers (locale independent) ---- }
function XmlTryParseFloat(const S: XmlString; out V: Double): Boolean;
function XmlFloatToStr(V: Double): XmlString;

implementation

{ EXmlForgeException }

constructor EXmlForgeException.CreateCode(ACode: Integer; const AMessage: XmlString;
  ALine: Integer; AColumn: Integer);
var
  Msg: string;
begin
  if ALine > 0 then
    Msg := Format('%s (line %d, column %d)', [AMessage, ALine, AColumn])
  else
    Msg := AMessage;
  inherited Create(Msg);
  FErrorCode := ACode;
  FLine := ALine;
  FColumn := AColumn;
end;

{ TXmlStrBuf }

constructor TXmlStrBuf.Create(InitialCapacity: Integer);
begin
  inherited Create;
  if InitialCapacity < 16 then InitialCapacity := 16;
  SetLength(FData, InitialCapacity);
  FLen := 0;
end;

procedure TXmlStrBuf.Grow(MinCap: Integer);
var
  NewCap: Integer;
begin
  NewCap := System.Length(FData) * 2;
  if NewCap < MinCap then NewCap := MinCap;
  SetLength(FData, NewCap);
end;

procedure TXmlStrBuf.Clear;
begin
  FLen := 0;
end;

procedure TXmlStrBuf.AppendChar(C: WideChar);
begin
  if FLen >= System.Length(FData) then Grow(FLen + 1);
  FData[FLen] := C;
  Inc(FLen);
end;

procedure TXmlStrBuf.Append(const S: XmlString);
var
  N: Integer;
begin
  N := System.Length(S);
  if N = 0 then Exit;
  if FLen + N > System.Length(FData) then Grow(FLen + N);
  Move(S[1], FData[FLen], N * SizeOf(WideChar));
  Inc(FLen, N);
end;

procedure TXmlStrBuf.AppendCodePoint(CP: Cardinal);
begin
  if CP >= $10000 then
  begin
    Dec(CP, $10000);
    AppendChar(WideChar($D800 + (CP shr 10)));
    AppendChar(WideChar($DC00 + (CP and $3FF)));
  end
  else
    AppendChar(WideChar(CP));
end;

function TXmlStrBuf.AsString: XmlString;
begin
  if FLen = 0 then
    Result := ''
  else
    SetString(Result, PWideChar(@FData[0]), FLen);
end;

function TXmlStrBuf.EndsWith(C1, C2: WideChar): Boolean;
begin
  Result := (FLen >= 2) and (FData[FLen - 2] = C1) and (FData[FLen - 1] = C2);
end;

procedure TXmlStrBuf.Truncate(NewLen: Integer);
begin
  if (NewLen >= 0) and (NewLen < FLen) then FLen := NewLen;
end;

{ character classes }

function XmlIsNameStartChar(C: Integer): Boolean;
begin
  Result :=
    ((C >= 97) and (C <= 122)) or ((C >= 65) and (C <= 90)) or (C = 95) or (C = 58) or
    ((C >= $C0) and (C <= $D6)) or ((C >= $D8) and (C <= $F6)) or
    ((C >= $F8) and (C <= $2FF)) or ((C >= $370) and (C <= $37D)) or
    ((C >= $37F) and (C <= $1FFF)) or ((C >= $200C) and (C <= $200D)) or
    ((C >= $2070) and (C <= $218F)) or ((C >= $2C00) and (C <= $2FEF)) or
    ((C >= $3001) and (C <= $D7FF)) or ((C >= $D800) and (C <= $DFFF)) or
    ((C >= $F900) and (C <= $FDCF)) or ((C >= $FDF0) and (C <= $FFFD));
end;

function XmlIsNameChar(C: Integer): Boolean;
begin
  Result := XmlIsNameStartChar(C) or (C = 45) or (C = 46) or
    ((C >= 48) and (C <= 57)) or (C = $B7) or
    ((C >= $300) and (C <= $36F)) or ((C >= $203F) and (C <= $2040));
end;

function XmlIsNCNameStartChar(C: Integer): Boolean;
begin
  Result := (C <> 58) and XmlIsNameStartChar(C);
end;

function XmlIsNCNameChar(C: Integer): Boolean;
begin
  Result := (C <> 58) and XmlIsNameChar(C);
end;

function XmlIsWhite(C: Integer): Boolean;
begin
  Result := (C = 32) or (C = 10) or (C = 9) or (C = 13);
end;

function XmlIsValidName(const S: XmlString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if S = '' then Exit;
  if not XmlIsNameStartChar(Ord(S[1])) then Exit;
  for I := 2 to System.Length(S) do
    if not XmlIsNameChar(Ord(S[I])) then Exit;
  Result := True;
end;

function XmlIsValidNCName(const S: XmlString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if S = '' then Exit;
  if not XmlIsNCNameStartChar(Ord(S[1])) then Exit;
  for I := 2 to System.Length(S) do
    if not XmlIsNCNameChar(Ord(S[I])) then Exit;
  Result := True;
end;

function XmlSplitQName(const QName: XmlString; out Prefix, Local: XmlString): Boolean;
var
  P: Integer;
begin
  P := Pos(':', QName);
  if P = 0 then
  begin
    Prefix := '';
    Local := QName;
    Result := QName <> '';
  end
  else
  begin
    Prefix := Copy(QName, 1, P - 1);
    Local := Copy(QName, P + 1, MaxInt);
    Result := (Prefix <> '') and (Local <> '') and (Pos(':', Local) = 0);
  end;
end;

function XmlIsValidQName(const S: XmlString): Boolean;
var
  P, L: XmlString;
begin
  Result := XmlSplitQName(S, P, L) and ((P = '') or XmlIsValidNCName(P)) and
    XmlIsValidNCName(L);
end;

function XmlIsAllWhite(const S: XmlString): Boolean;
var
  I: Integer;
begin
  for I := 1 to System.Length(S) do
    if not XmlIsWhite(Ord(S[I])) then
    begin
      Result := False;
      Exit;
    end;
  Result := True;
end;

function XmlTrimWhite(const S: XmlString): XmlString;
var
  A, B: Integer;
begin
  A := 1;
  B := System.Length(S);
  while (A <= B) and XmlIsWhite(Ord(S[A])) do Inc(A);
  while (B >= A) and XmlIsWhite(Ord(S[B])) do Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

function XmlSanitizeName(const S: XmlString; AllowColon: Boolean): XmlString;
var
  I: Integer;
  C: Integer;
begin
  if S = '' then
  begin
    Result := '_';
    Exit;
  end;
  Result := S;
  for I := 1 to System.Length(Result) do
  begin
    C := Ord(Result[I]);
    if C = 58 then
    begin
      if not AllowColon then Result[I] := '_';
    end
    else if not XmlIsNameChar(C) then
      Result[I] := '_';
  end;
  C := Ord(Result[1]);
  if not (XmlIsNameStartChar(C) and (AllowColon or (C <> 58))) then
    Result := '_' + Result;
end;

function XmlIsXmlChar(CP: Cardinal): Boolean;
begin
  Result := (CP = 9) or (CP = 10) or (CP = 13) or
    ((CP >= $20) and (CP <= $D7FF)) or ((CP >= $E000) and (CP <= $FFFD)) or
    ((CP >= $10000) and (CP <= $10FFFF));
end;

{ numbers }

function XmlTryParseFloat(const S: XmlString; out V: Double): Boolean;
var
  I, N: Integer;
  Neg, HasDigits: Boolean;
  Mant: Double;
  FracDigits, Exp, ExpSign: Integer;
  C: Integer;
begin
  Result := False;
  V := 0;
  N := System.Length(S);
  I := 1;
  Neg := False;
  if (I <= N) and ((S[I] = '-') or (S[I] = '+')) then
  begin
    Neg := S[I] = '-';
    Inc(I);
  end;
  Mant := 0;
  HasDigits := False;
  FracDigits := 0;
  while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do
  begin
    Mant := Mant * 10 + (Ord(S[I]) - 48);
    HasDigits := True;
    Inc(I);
  end;
  if (I <= N) and (S[I] = '.') then
  begin
    Inc(I);
    while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do
    begin
      Mant := Mant * 10 + (Ord(S[I]) - 48);
      Inc(FracDigits);
      HasDigits := True;
      Inc(I);
    end;
  end;
  if not HasDigits then Exit;
  Exp := 0;
  if (I <= N) and ((S[I] = 'e') or (S[I] = 'E')) then
  begin
    Inc(I);
    ExpSign := 1;
    if (I <= N) and ((S[I] = '-') or (S[I] = '+')) then
    begin
      if S[I] = '-' then ExpSign := -1;
      Inc(I);
    end;
    if (I > N) or (S[I] < '0') or (S[I] > '9') then Exit;
    while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do
    begin
      C := Ord(S[I]) - 48;
      if Exp < 10000 then Exp := Exp * 10 + C;
      Inc(I);
    end;
    Exp := Exp * ExpSign;
  end;
  if I <= N then Exit;
  Exp := Exp - FracDigits;
  if Exp <> 0 then Mant := Mant * IntPower(10, Exp);
  if Neg then Mant := -Mant;
  V := Mant;
  Result := True;
end;

function XmlFloatToStr(V: Double): XmlString;
var
  S: ShortString;
  L: Integer;
begin
  if IsNan(V) then
    Result := 'NaN'
  else if IsInfinite(V) then
  begin
    if V > 0 then Result := 'Infinity' else Result := '-Infinity';
  end
  else if V = 0 then
    Result := '0'
  else if (Frac(V) = 0) and (Abs(V) < 1e15) then
    Result := IntToStr(Trunc(V))
  else
  begin
    Str(V:0:15, S);
    L := Length(S);
    while (L > 0) and (S[L] = '0') do Dec(L);
    if (L > 0) and (S[L] = '.') then Dec(L);
    Result := XmlString(Copy(S, 1, L));
    if Result = '-0' then Result := '0';
  end;
end;

end.
