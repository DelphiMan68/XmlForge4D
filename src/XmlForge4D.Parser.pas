{$I XmlForge4D.inc}
unit XmlForge4D.Parser;

{ Event-based (SAX) XML 1.0/1.1 parser.
  - incremental decoding from TStream (low memory, configurable buffer)
  - namespace aware, well-formedness checks, line/column diagnostics
  - hardened: external entities are never loaded, entity expansion / depth /
    size / attribute limits, optional DOCTYPE prohibition. }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Encoding;

type
  TXmlDtdMode = (dtdAllow, dtdIgnore, dtdProhibit);

  TXmlParserOptions = record
    NamespaceAware: Boolean;          // default True
    PreserveWhitespace: Boolean;      // report whitespace-only text (default True)
    DtdMode: TXmlDtdMode;             // default dtdAllow (internal entities only)
    IgnoreExternalEntities: Boolean;  // False: reference to external entity = security error
    MaxDocumentSize: Int64;           // bytes, 0 = unlimited
    MaxDepth: Integer;                // default 256, 0 = unlimited
    MaxEntityExpansion: Int64;        // total expanded characters, default 1,000,000
    MaxEntityDepth: Integer;          // nested entity depth, default 16
    MaxAttributes: Integer;           // per element, default 1024
    BufferSize: Integer;              // bytes read per chunk, default 65536
    class function Default: TXmlParserOptions; static;
  end;

  { ---- input reader: buffered, decoding, CRLF-normalising ---- }
  TXmlInputReader = class
  private
    FStream: TStream;
    FByteBuf: TBytes;
    FByteLen: Integer;
    FBufSize: Integer;
    FEnc: TXmlEncoding;
    FDetected: Boolean;
    FStreamEof: Boolean;
    FEof: Boolean;
    FChars: TWideCharArray;
    FPos, FLen: Integer;
    FLine, FCol: Integer;
    FBytesRead: Int64;
    FMaxBytes: Int64;
    FCapture: TXmlStrBuf;
    FDeclared: XmlString;
    procedure Fill;
  public
    constructor CreateStream(AStream: TStream; ABufferSize: Integer; AMaxBytes: Int64);
    constructor CreateString(const S: XmlString);
    function Peek: Integer;
    function PeekAt(Offset: Integer): Integer;
    function Next: Integer;
    function Matches(const S: XmlString): Boolean;
    procedure Skip(Count: Integer);
    property Line: Integer read FLine;
    property Column: Integer read FCol;
    property Capture: TXmlStrBuf read FCapture write FCapture;
    property DetectedEncoding: TXmlEncoding read FEnc;
  end;

  { ---- SAX ---- }
  TXmlSaxAttributes = class
  private
    FQName, FPrefix, FLocal, FUri, FValue: array of XmlString;
    FCount: Integer;
    function GetQName(I: Integer): XmlString;
    function GetPrefix(I: Integer): XmlString;
    function GetLocalName(I: Integer): XmlString;
    function GetNamespaceURI(I: Integer): XmlString;
    function GetValue(I: Integer): XmlString;
  public
    procedure Clear;
    procedure Add(const AQName, APrefix, ALocal, AUri, AValue: XmlString);
    function IndexOf(const AQName: XmlString): Integer;
    function IndexOfNS(const AUri, ALocal: XmlString): Integer;
    function ValueOf(const AQName: XmlString): XmlString;
    property Count: Integer read FCount;
    property QName[I: Integer]: XmlString read GetQName;
    property Prefix[I: Integer]: XmlString read GetPrefix;
    property LocalName[I: Integer]: XmlString read GetLocalName;
    property NamespaceURI[I: Integer]: XmlString read GetNamespaceURI;
    property Value[I: Integer]: XmlString read GetValue;
  end;

  TXmlSaxHandler = class
  public
    procedure StartDocument(const Version, Encoding: XmlString; Standalone: TXmlStandalone;
      HasDeclaration: Boolean); virtual;
    procedure EndDocument; virtual;
    procedure DocType(const Name, PublicId, SystemId, InternalSubset: XmlString); virtual;
    procedure StartPrefixMapping(const Prefix, Uri: XmlString); virtual;
    procedure EndPrefixMapping(const Prefix: XmlString); virtual;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); virtual;
    procedure EndElement(const Uri, LocalName, QName: XmlString); virtual;
    procedure Characters(const Text: XmlString); virtual;
    procedure CData(const Text: XmlString); virtual;
    procedure Comment(const Text: XmlString); virtual;
    procedure ProcessingInstruction(const Target, Data: XmlString); virtual;
    { Called just before a fatal error is raised. }
    procedure FatalError(E: EXmlForgeException); virtual;
  end;

  TXmlParser = class
  private
    FOptions: TXmlParserOptions;
    FHandler: TXmlSaxHandler;
    FReader, FMain: TXmlInputReader;
    FOnCancel: TXmlCancelEvent;
    FCancelled: Boolean;
    FText, FTmp, FNameBuf: TXmlStrBuf;
    FAttrs: TXmlSaxAttributes;
    FRawNames, FRawValues: array of XmlString;
    FRawCount: Integer;
    FStackQ, FStackL, FStackU: array of XmlString;
    FStackMark: array of Integer;
    FDepth: Integer;
    FNsPrefix, FNsUri: array of XmlString;
    FNsCount: Integer;
    FEntNames, FEntValues: array of XmlString;
    FEntExternal: array of Boolean;
    FEntCount: Integer;
    FEntStack: array of XmlString;
    FEntDepth: Integer;
    FExpanded: Int64;
    FXml11, FDoctypeSeen, FInDtd: Boolean;
    FVersion, FEncodingDecl: XmlString;
    FStandalone: TXmlStandalone;
    FHasDecl: Boolean;
    FElemCounter: Integer;

    procedure Fail(Code: Integer; const Msg: XmlString);
    procedure FailNs(Code: Integer; const Msg: XmlString);
    procedure FailSec(Code: Integer; const Msg: XmlString);
    procedure CheckCancel;
    procedure DoParse(AReader: TXmlInputReader; AHandler: TXmlSaxHandler);
    function SkipWhite: Integer;
    procedure ReqWhite;
    procedure Expect(Ch: WideChar);
    function ReadName: XmlString;
    function ReadQuoted: XmlString;
    procedure AppendChecked(Buf: TXmlStrBuf; C: Integer);
    procedure ParseXmlDecl;
    procedure ParseComment;
    procedure ParsePI;
    procedure ParseDocType;
    procedure ParseInternalSubset;
    procedure ParseEntityDecl;
    procedure SkipDecl;
    procedure ParseExternalId(out PubId, SysId: XmlString);
    function ProcessEntityLiteral(const Raw: XmlString): XmlString;
    procedure ParseStartTag;
    procedure ParseEndTag(BaseDepth: Integer);
    procedure PopElement;
    procedure ParseContent(BaseDepth: Integer; InEntity: Boolean);
    procedure ParseCharData;
    procedure ParseCData;
    procedure ParseReference;
    procedure ParseCharRef(Buf: TXmlStrBuf);
    function ReadAttrValue: XmlString;
    procedure FlushText;
    procedure FlushPartial;
    function FindEntity(const Name: XmlString): Integer;
    procedure AddEntity(const Name, Value: XmlString; External: Boolean);
    procedure EnterEntity(Idx: Integer);
    procedure LeaveEntity;
    procedure ExpandEntityContent(Idx: Integer);
    procedure ExpandAttrEntity(Idx: Integer);
    function LookupNs(const Prefix: XmlString; out Uri: XmlString): Boolean;
    procedure DeclareNs(const Prefix, Uri: XmlString);
  public
    constructor Create; overload;
    constructor Create(const AOptions: TXmlParserOptions); overload;
    destructor Destroy; override;
    procedure ParseStream(Stream: TStream; Handler: TXmlSaxHandler);
    procedure ParseFile(const FileName: string; Handler: TXmlSaxHandler);
    procedure ParseString(const Xml: XmlString; Handler: TXmlSaxHandler);
    { Requests cancellation; raises EXmlCancelledException from within the parse. }
    procedure Cancel;
    property Options: TXmlParserOptions read FOptions write FOptions;
    property OnCancel: TXmlCancelEvent read FOnCancel write FOnCancel;
  end;

implementation

{ TXmlParserOptions }

class function TXmlParserOptions.Default: TXmlParserOptions;
begin
  Result.NamespaceAware := True;
  Result.PreserveWhitespace := True;
  Result.DtdMode := dtdAllow;
  Result.IgnoreExternalEntities := False;
  Result.MaxDocumentSize := 0;
  Result.MaxDepth := 256;
  Result.MaxEntityExpansion := 1000000;
  Result.MaxEntityDepth := 16;
  Result.MaxAttributes := 1024;
  Result.BufferSize := 65536;
end;

{ TXmlInputReader }

constructor TXmlInputReader.CreateStream(AStream: TStream; ABufferSize: Integer;
  AMaxBytes: Int64);
begin
  inherited Create;
  FStream := AStream;
  if ABufferSize < 256 then ABufferSize := 256;
  FBufSize := ABufferSize;
  SetLength(FByteBuf, FBufSize);
  SetLength(FChars, FBufSize + 64);
  FMaxBytes := AMaxBytes;
  FLine := 1;
  FCol := 1;
end;

constructor TXmlInputReader.CreateString(const S: XmlString);
var
  N: Integer;
begin
  inherited Create;
  N := System.Length(S);
  SetLength(FChars, N + 64);
  if N > 0 then Move(S[1], FChars[0], N * SizeOf(WideChar));
  FLen := N;
  FEof := True;
  FDetected := True;
  FEnc := xeUtf16LE;
  FLine := 1;
  FCol := 1;
end;

procedure TXmlInputReader.Fill;
var
  I, Got, Consumed, Produced, BomLen, Want: Integer;
begin
  if FEof then Exit;
  if FPos > 0 then
  begin
    for I := 0 to FLen - FPos - 1 do FChars[I] := FChars[FPos + I];
    Dec(FLen, FPos);
    FPos := 0;
  end;
  if not FStreamEof then
  begin
    Want := FBufSize - FByteLen;
    if Want > 0 then
    begin
      Got := FStream.Read(FByteBuf[FByteLen], Want);
      if Got <= 0 then
        FStreamEof := True
      else
      begin
        Inc(FByteLen, Got);
        Inc(FBytesRead, Got);
        if (FMaxBytes > 0) and (FBytesRead > FMaxBytes) then
          raise EXmlSecurityException.CreateCode(XFE_SEC_SIZE_LIMIT,
            'Maximum document size exceeded (' + IntToStr(FMaxBytes) + ' bytes)', FLine, FCol);
      end;
    end;
    if not FDetected then
    begin
      while (FByteLen < 4) and (not FStreamEof) do
      begin
        Got := FStream.Read(FByteBuf[FByteLen], FBufSize - FByteLen);
        if Got <= 0 then
          FStreamEof := True
        else
        begin
          Inc(FByteLen, Got);
          Inc(FBytesRead, Got);
        end;
      end;
      FEnc := XmlDetectEncoding(FByteBuf, FByteLen, BomLen, FDeclared);
      if BomLen > 0 then
      begin
        Move(FByteBuf[BomLen], FByteBuf[0], FByteLen - BomLen);
        Dec(FByteLen, BomLen);
      end;
      FDetected := True;
    end;
  end;
  Produced := XmlDecodeBytes(FEnc, FByteBuf, 0, FByteLen, FChars, FLen, Consumed, FStreamEof);
  if Consumed < FByteLen then Move(FByteBuf[Consumed], FByteBuf[0], FByteLen - Consumed);
  Dec(FByteLen, Consumed);
  Inc(FLen, Produced);
  if FStreamEof and (FByteLen = 0) then FEof := True;
end;

function TXmlInputReader.Peek: Integer;
begin
  while (FPos >= FLen) and (not FEof) do Fill;
  if FPos < FLen then
    Result := Ord(FChars[FPos])
  else
    Result := -1;
end;

function TXmlInputReader.PeekAt(Offset: Integer): Integer;
begin
  while (FLen - FPos <= Offset) and (not FEof) do Fill;
  if FPos + Offset < FLen then
    Result := Ord(FChars[FPos + Offset])
  else
    Result := -1;
end;

function TXmlInputReader.Next: Integer;
begin
  Result := Peek;
  if Result < 0 then Exit;
  Inc(FPos);
  if Result = 13 then
  begin
    if Peek = 10 then Inc(FPos);
    Result := 10;
  end;
  if Result = 10 then
  begin
    Inc(FLine);
    FCol := 1;
  end
  else
    Inc(FCol);
  if FCapture <> nil then FCapture.AppendChar(WideChar(Result));
end;

function TXmlInputReader.Matches(const S: XmlString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to System.Length(S) do
    if PeekAt(I - 1) <> Ord(S[I]) then Exit;
  Result := True;
end;

procedure TXmlInputReader.Skip(Count: Integer);
var
  I: Integer;
begin
  for I := 1 to Count do Next;
end;

{ TXmlSaxAttributes }

procedure TXmlSaxAttributes.Clear;
begin
  FCount := 0;
end;

procedure TXmlSaxAttributes.Add(const AQName, APrefix, ALocal, AUri, AValue: XmlString);
begin
  if FCount >= System.Length(FQName) then
  begin
    SetLength(FQName, FCount * 2 + 8);
    SetLength(FPrefix, FCount * 2 + 8);
    SetLength(FLocal, FCount * 2 + 8);
    SetLength(FUri, FCount * 2 + 8);
    SetLength(FValue, FCount * 2 + 8);
  end;
  FQName[FCount] := AQName;
  FPrefix[FCount] := APrefix;
  FLocal[FCount] := ALocal;
  FUri[FCount] := AUri;
  FValue[FCount] := AValue;
  Inc(FCount);
end;

function TXmlSaxAttributes.GetQName(I: Integer): XmlString;
begin
  Result := FQName[I];
end;

function TXmlSaxAttributes.GetPrefix(I: Integer): XmlString;
begin
  Result := FPrefix[I];
end;

function TXmlSaxAttributes.GetLocalName(I: Integer): XmlString;
begin
  Result := FLocal[I];
end;

function TXmlSaxAttributes.GetNamespaceURI(I: Integer): XmlString;
begin
  Result := FUri[I];
end;

function TXmlSaxAttributes.GetValue(I: Integer): XmlString;
begin
  Result := FValue[I];
end;

function TXmlSaxAttributes.IndexOf(const AQName: XmlString): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FQName[I] = AQName then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TXmlSaxAttributes.IndexOfNS(const AUri, ALocal: XmlString): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if (FLocal[I] = ALocal) and (FUri[I] = AUri) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TXmlSaxAttributes.ValueOf(const AQName: XmlString): XmlString;
var
  I: Integer;
begin
  I := IndexOf(AQName);
  if I >= 0 then Result := FValue[I] else Result := '';
end;

{ TXmlSaxHandler - default no-op implementations }

procedure TXmlSaxHandler.StartDocument(const Version, Encoding: XmlString;
  Standalone: TXmlStandalone; HasDeclaration: Boolean);
begin
end;

procedure TXmlSaxHandler.EndDocument;
begin
end;

procedure TXmlSaxHandler.DocType(const Name, PublicId, SystemId, InternalSubset: XmlString);
begin
end;

procedure TXmlSaxHandler.StartPrefixMapping(const Prefix, Uri: XmlString);
begin
end;

procedure TXmlSaxHandler.EndPrefixMapping(const Prefix: XmlString);
begin
end;

procedure TXmlSaxHandler.StartElement(const Uri, LocalName, QName: XmlString;
  Attrs: TXmlSaxAttributes; Line, Column: Integer);
begin
end;

procedure TXmlSaxHandler.EndElement(const Uri, LocalName, QName: XmlString);
begin
end;

procedure TXmlSaxHandler.Characters(const Text: XmlString);
begin
end;

procedure TXmlSaxHandler.CData(const Text: XmlString);
begin
end;

procedure TXmlSaxHandler.Comment(const Text: XmlString);
begin
end;

procedure TXmlSaxHandler.ProcessingInstruction(const Target, Data: XmlString);
begin
end;

procedure TXmlSaxHandler.FatalError(E: EXmlForgeException);
begin
end;

{ TXmlParser }

constructor TXmlParser.Create;
begin
  Create(TXmlParserOptions.Default);
end;

constructor TXmlParser.Create(const AOptions: TXmlParserOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FText := TXmlStrBuf.Create(1024);
  FTmp := TXmlStrBuf.Create(256);
  FNameBuf := TXmlStrBuf.Create(64);
  FAttrs := TXmlSaxAttributes.Create;
end;

destructor TXmlParser.Destroy;
begin
  FText.Free;
  FTmp.Free;
  FNameBuf.Free;
  FAttrs.Free;
  inherited Destroy;
end;

procedure TXmlParser.Cancel;
begin
  FCancelled := True;
end;

procedure TXmlParser.Fail(Code: Integer; const Msg: XmlString);
var
  E: EXmlParseException;
begin
  E := EXmlParseException.CreateCode(Code, Msg, FMain.Line, FMain.Column);
  if FHandler <> nil then FHandler.FatalError(E);
  raise E;
end;

procedure TXmlParser.FailNs(Code: Integer; const Msg: XmlString);
var
  E: EXmlNamespaceException;
begin
  E := EXmlNamespaceException.CreateCode(Code, Msg, FMain.Line, FMain.Column);
  if FHandler <> nil then FHandler.FatalError(E);
  raise E;
end;

procedure TXmlParser.FailSec(Code: Integer; const Msg: XmlString);
var
  E: EXmlSecurityException;
begin
  E := EXmlSecurityException.CreateCode(Code, Msg, FMain.Line, FMain.Column);
  if FHandler <> nil then FHandler.FatalError(E);
  raise E;
end;

procedure TXmlParser.CheckCancel;
var
  Cn: Boolean;
begin
  Inc(FElemCounter);
  if FCancelled then
    raise EXmlCancelledException.CreateCode(XFE_CANCELLED, 'Parsing cancelled', FMain.Line, FMain.Column);
  if Assigned(FOnCancel) and ((FElemCounter and 63) = 0) then
  begin
    Cn := False;
    FOnCancel(Self, Cn);
    if Cn then
    begin
      FCancelled := True;
      raise EXmlCancelledException.CreateCode(XFE_CANCELLED, 'Parsing cancelled', FMain.Line, FMain.Column);
    end;
  end;
end;

function TXmlParser.SkipWhite: Integer;
begin
  Result := 0;
  while XmlIsWhite(FReader.Peek) do
  begin
    FReader.Next;
    Inc(Result);
  end;
end;

procedure TXmlParser.ReqWhite;
begin
  if SkipWhite = 0 then Fail(XFE_PARSE_GENERIC, 'Whitespace expected');
end;

procedure TXmlParser.Expect(Ch: WideChar);
var
  C: Integer;
begin
  C := FReader.Next;
  if C <> Ord(Ch) then
  begin
    if C < 0 then
      Fail(XFE_UNEXPECTED_EOF, 'Unexpected end of input, expected "' + Ch + '"')
    else
      Fail(XFE_PARSE_GENERIC, 'Expected "' + Ch + '" but found "' + WideChar(C) + '"');
  end;
end;

function TXmlParser.ReadName: XmlString;
var
  C: Integer;
begin
  C := FReader.Peek;
  if (C < 0) or (not XmlIsNameStartChar(C)) then
    Fail(XFE_INVALID_NAME, 'XML name expected');
  FNameBuf.Clear;
  repeat
    FNameBuf.AppendChar(WideChar(FReader.Next));
    C := FReader.Peek;
  until (C < 0) or (not XmlIsNameChar(C));
  Result := FNameBuf.AsString;
end;

function TXmlParser.ReadQuoted: XmlString;
var
  Q, C: Integer;
  B: TXmlStrBuf;
begin
  Q := FReader.Next;
  if (Q <> 34) and (Q <> 39) then Fail(XFE_PARSE_GENERIC, 'Quoted string expected');
  B := TXmlStrBuf.Create(64);
  try
    while True do
    begin
      C := FReader.Next;
      if C < 0 then Fail(XFE_UNEXPECTED_EOF, 'Unterminated quoted string');
      if C = Q then Break;
      B.AppendChar(WideChar(C));
    end;
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

procedure TXmlParser.AppendChecked(Buf: TXmlStrBuf; C: Integer);
var
  D: Integer;
begin
  if C < 32 then
  begin
    if (C <> 9) and (C <> 10) and (C <> 13) then
      Fail(XFE_INVALID_CHAR, 'Invalid XML character U+' + IntToHex(C, 4));
  end
  else if C >= $D800 then
  begin
    if C <= $DBFF then
    begin
      D := FReader.Peek;
      if (D < $DC00) or (D > $DFFF) then
        Fail(XFE_INVALID_CHAR, 'Unpaired high surrogate');
      Buf.AppendChar(WideChar(C));
      FReader.Next;
      Buf.AppendChar(WideChar(D));
      Exit;
    end
    else if C <= $DFFF then
      Fail(XFE_INVALID_CHAR, 'Unpaired low surrogate')
    else if C >= $FFFE then
      Fail(XFE_INVALID_CHAR, 'Invalid XML character U+' + IntToHex(C, 4));
  end;
  Buf.AppendChar(WideChar(C));
end;

{ ---- entities ---- }

function TXmlParser.FindEntity(const Name: XmlString): Integer;
var
  I: Integer;
begin
  for I := 0 to FEntCount - 1 do
    if FEntNames[I] = Name then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

procedure TXmlParser.AddEntity(const Name, Value: XmlString; External: Boolean);
begin
  if FindEntity(Name) >= 0 then Exit; // first declaration wins
  if FEntCount >= System.Length(FEntNames) then
  begin
    SetLength(FEntNames, FEntCount * 2 + 8);
    SetLength(FEntValues, FEntCount * 2 + 8);
    SetLength(FEntExternal, FEntCount * 2 + 8);
  end;
  FEntNames[FEntCount] := Name;
  FEntValues[FEntCount] := Value;
  FEntExternal[FEntCount] := External;
  Inc(FEntCount);
end;

procedure TXmlParser.EnterEntity(Idx: Integer);
var
  I: Integer;
begin
  for I := 0 to FEntDepth - 1 do
    if FEntStack[I] = FEntNames[Idx] then
      FailSec(XFE_SEC_RECURSIVE_ENTITY, 'Recursive entity reference "&' + FEntNames[Idx] + ';"');
  if (FOptions.MaxEntityDepth > 0) and (FEntDepth >= FOptions.MaxEntityDepth) then
    FailSec(XFE_SEC_ENTITY_LIMIT, 'Maximum entity nesting depth exceeded');
  Inc(FExpanded, System.Length(FEntValues[Idx]));
  if (FOptions.MaxEntityExpansion > 0) and (FExpanded > FOptions.MaxEntityExpansion) then
    FailSec(XFE_SEC_ENTITY_LIMIT, 'Maximum entity expansion size exceeded (entity expansion attack?)');
  if FEntDepth >= System.Length(FEntStack) then SetLength(FEntStack, FEntDepth * 2 + 8);
  FEntStack[FEntDepth] := FEntNames[Idx];
  Inc(FEntDepth);
end;

procedure TXmlParser.LeaveEntity;
begin
  Dec(FEntDepth);
end;

procedure TXmlParser.ExpandEntityContent(Idx: Integer);
var
  Sub, Saved: TXmlInputReader;
  BaseDepth: Integer;
begin
  FlushText;
  EnterEntity(Idx);
  Sub := TXmlInputReader.CreateString(FEntValues[Idx]);
  Saved := FReader;
  FReader := Sub;
  BaseDepth := FDepth;
  try
    ParseContent(BaseDepth, True);
  finally
    FReader := Saved;
    Sub.Free;
  end;
  if FDepth <> BaseDepth then
    Fail(XFE_BAD_REFERENCE, 'Entity "&' + FEntNames[Idx] + ';" is not well-formed (unbalanced elements)');
  LeaveEntity;
end;

procedure TXmlParser.ExpandAttrEntity(Idx: Integer);
var
  S, Name: XmlString;
  I, J, C, E: Integer;
  CP: Cardinal;
  Hex: Boolean;
  K: Integer;
begin
  EnterEntity(Idx);
  S := FEntValues[Idx];
  I := 1;
  while I <= System.Length(S) do
  begin
    C := Ord(S[I]);
    Inc(I);
    if C = Ord('&') then
    begin
      J := I;
      while (J <= System.Length(S)) and (S[J] <> ';') do Inc(J);
      if J > System.Length(S) then Fail(XFE_BAD_REFERENCE, 'Malformed reference in entity value');
      Name := Copy(S, I, J - I);
      I := J + 1;
      if (Name <> '') and (Name[1] = '#') then
      begin
        Hex := (System.Length(Name) > 1) and (Name[2] = 'x');
        CP := 0;
        if Hex then K := 3 else K := 2;
        if K > System.Length(Name) then Fail(XFE_BAD_REFERENCE, 'Invalid character reference');
        for K := K to System.Length(Name) do
        begin
          if Hex then
            CP := CP * 16 + Cardinal(StrToIntDef('$' + Name[K], 0))
          else
            CP := CP * 10 + Cardinal(StrToIntDef(Name[K], 0));
          if CP > $10FFFF then Fail(XFE_BAD_REFERENCE, 'Invalid character reference');
        end;
        if not XmlIsXmlChar(CP) then Fail(XFE_BAD_REFERENCE, 'Invalid character reference');
        FTmp.AppendCodePoint(CP);
      end
      else if Name = 'lt' then FTmp.Append('<')
      else if Name = 'gt' then FTmp.Append('>')
      else if Name = 'amp' then FTmp.Append('&')
      else if Name = 'apos' then FTmp.Append('''')
      else if Name = 'quot' then FTmp.Append('"')
      else
      begin
        E := FindEntity(Name);
        if E < 0 then Fail(XFE_UNDEFINED_ENTITY, 'Undefined entity "&' + Name + ';"');
        if FEntExternal[E] then
        begin
          if not FOptions.IgnoreExternalEntities then
            FailSec(XFE_SEC_EXTERNAL_ENTITY, 'External entity "&' + Name + ';" is not allowed');
        end
        else
          ExpandAttrEntity(E);
      end;
    end
    else if C = Ord('<') then
      Fail(XFE_BAD_ATTRIBUTE, '"<" is not allowed in attribute values (via entity)')
    else if (C = 9) or (C = 10) or (C = 13) then
      FTmp.Append(' ')
    else
      FTmp.AppendChar(WideChar(C));
  end;
  LeaveEntity;
end;

procedure TXmlParser.ParseCharRef(Buf: TXmlStrBuf);
var
  C, D, Digits, Base: Integer;
  CP: Cardinal;
  Hex: Boolean;
begin
  FReader.Next; // '#'
  Hex := FReader.Peek = Ord('x');
  if Hex then
  begin
    FReader.Next;
    Base := 16;
  end
  else
    Base := 10;
  CP := 0;
  Digits := 0;
  while True do
  begin
    C := FReader.Peek;
    if (C >= 48) and (C <= 57) then D := C - 48
    else if Hex and (C >= 65) and (C <= 70) then D := C - 55
    else if Hex and (C >= 97) and (C <= 102) then D := C - 87
    else Break;
    FReader.Next;
    Inc(Digits);
    if CP <= $10FFFF then CP := CP * Cardinal(Base) + Cardinal(D);
  end;
  if Digits = 0 then Fail(XFE_BAD_REFERENCE, 'Invalid character reference');
  Expect(';');
  if not (XmlIsXmlChar(CP) or (FXml11 and (CP >= 1) and (CP <= 31))) then
    Fail(XFE_BAD_REFERENCE, 'Character reference to an invalid XML character (U+' + IntToHex(CP, 4) + ')');
  Buf.AppendCodePoint(CP);
end;

procedure TXmlParser.ParseReference;
var
  Name: XmlString;
  Idx: Integer;
begin
  if FReader.Peek = Ord('#') then
  begin
    ParseCharRef(FText);
    Exit;
  end;
  Name := ReadName;
  Expect(';');
  if Name = 'lt' then FText.Append('<')
  else if Name = 'gt' then FText.Append('>')
  else if Name = 'amp' then FText.Append('&')
  else if Name = 'apos' then FText.Append('''')
  else if Name = 'quot' then FText.Append('"')
  else
  begin
    Idx := FindEntity(Name);
    if Idx < 0 then Fail(XFE_UNDEFINED_ENTITY, 'Undefined entity "&' + Name + ';"');
    if FEntExternal[Idx] then
    begin
      if not FOptions.IgnoreExternalEntities then
        FailSec(XFE_SEC_EXTERNAL_ENTITY,
          'External entity "&' + Name + ';" is not allowed (external entity resolution is disabled)');
    end
    else
      ExpandEntityContent(Idx);
  end;
end;

function TXmlParser.ReadAttrValue: XmlString;
var
  Q, C, Idx: Integer;
  Name: XmlString;
begin
  Q := FReader.Next;
  if (Q <> 34) and (Q <> 39) then Fail(XFE_BAD_ATTRIBUTE, 'Quoted attribute value expected');
  FTmp.Clear;
  while True do
  begin
    C := FReader.Next;
    if C < 0 then
      Fail(XFE_UNEXPECTED_EOF, 'Unterminated attribute value')
    else if C = Q then
      Break
    else if C = Ord('<') then
      Fail(XFE_BAD_ATTRIBUTE, '"<" is not allowed in attribute values')
    else if C = Ord('&') then
    begin
      if FReader.Peek = Ord('#') then
        ParseCharRef(FTmp)
      else
      begin
        Name := ReadName;
        Expect(';');
        if Name = 'lt' then FTmp.Append('<')
        else if Name = 'gt' then FTmp.Append('>')
        else if Name = 'amp' then FTmp.Append('&')
        else if Name = 'apos' then FTmp.Append('''')
        else if Name = 'quot' then FTmp.Append('"')
        else
        begin
          Idx := FindEntity(Name);
          if Idx < 0 then Fail(XFE_UNDEFINED_ENTITY, 'Undefined entity "&' + Name + ';"');
          if FEntExternal[Idx] then
          begin
            if not FOptions.IgnoreExternalEntities then
              FailSec(XFE_SEC_EXTERNAL_ENTITY, 'External entity "&' + Name + ';" is not allowed');
          end
          else
            ExpandAttrEntity(Idx);
        end;
      end;
    end
    else if (C = 9) or (C = 10) then
      FTmp.Append(' ')
    else
      AppendChecked(FTmp, C);
  end;
  Result := FTmp.AsString;
end;

{ ---- text flushing ---- }

procedure TXmlParser.FlushText;
var
  S: XmlString;
begin
  if FText.Len = 0 then Exit;
  S := FText.AsString;
  FText.Clear;
  if FOptions.PreserveWhitespace or (not XmlIsAllWhite(S)) then FHandler.Characters(S);
end;

procedure TXmlParser.FlushPartial;
var
  S: XmlString;
begin
  S := FText.AsString;
  if (not FOptions.PreserveWhitespace) and XmlIsAllWhite(S) then Exit;
  FText.Clear;
  FHandler.Characters(S);
end;

{ ---- namespaces ---- }

function TXmlParser.LookupNs(const Prefix: XmlString; out Uri: XmlString): Boolean;
var
  I: Integer;
begin
  if Prefix = 'xml' then
  begin
    Uri := XML_NS_URI;
    Result := True;
    Exit;
  end;
  for I := FNsCount - 1 downto 0 do
    if FNsPrefix[I] = Prefix then
    begin
      Uri := FNsUri[I];
      Result := True;
      Exit;
    end;
  Uri := '';
  Result := Prefix = '';
end;

procedure TXmlParser.DeclareNs(const Prefix, Uri: XmlString);
begin
  if Prefix = 'xmlns' then FailNs(XFE_NS_INVALID, 'The prefix "xmlns" must not be declared');
  if (Prefix <> '') and (not XmlIsValidNCName(Prefix)) then
    FailNs(XFE_NS_INVALID, 'Invalid namespace prefix "' + Prefix + '"');
  if Prefix = 'xml' then
  begin
    if Uri <> XML_NS_URI then FailNs(XFE_NS_INVALID, 'The prefix "xml" is bound to a fixed namespace');
    Exit;
  end;
  if Uri = XML_NS_URI then FailNs(XFE_NS_INVALID, 'The XML namespace cannot be bound to another prefix');
  if Uri = XMLNS_NS_URI then FailNs(XFE_NS_INVALID, 'The xmlns namespace cannot be declared');
  if (Prefix <> '') and (Uri = '') and (not FXml11) then
    FailNs(XFE_NS_INVALID, 'Prefix "' + Prefix + '" cannot be undeclared in XML 1.0');
  if FNsCount >= System.Length(FNsPrefix) then
  begin
    SetLength(FNsPrefix, FNsCount * 2 + 8);
    SetLength(FNsUri, FNsCount * 2 + 8);
  end;
  FNsPrefix[FNsCount] := Prefix;
  FNsUri[FNsCount] := Uri;
  Inc(FNsCount);
  FHandler.StartPrefixMapping(Prefix, Uri);
end;

{ ---- elements ---- }

procedure TXmlParser.ParseStartTag;
var
  Line, Col, I, J, Mark, C: Integer;
  QName, Prefix, Local, Uri, AName, AValue, APrefix, ALocal, AUri: XmlString;
  SelfClose, HadWhite: Boolean;
begin
  CheckCancel;
  if (FOptions.MaxDepth > 0) and (FDepth >= FOptions.MaxDepth) then
    FailSec(XFE_SEC_DEPTH_LIMIT, 'Maximum element nesting depth exceeded (' + IntToStr(FOptions.MaxDepth) + ')');
  Line := FMain.Line;
  Col := FMain.Column;
  FReader.Next; // '<'
  QName := ReadName;
  FRawCount := 0;
  SelfClose := False;
  while True do
  begin
    HadWhite := SkipWhite > 0;
    C := FReader.Peek;
    if C = Ord('>') then
    begin
      FReader.Next;
      Break;
    end;
    if C = Ord('/') then
    begin
      FReader.Next;
      Expect('>');
      SelfClose := True;
      Break;
    end;
    if C < 0 then Fail(XFE_UNEXPECTED_EOF, 'Unexpected end of input inside start tag <' + QName + '>');
    if not HadWhite then Fail(XFE_BAD_ATTRIBUTE, 'Whitespace required between attributes');
    AName := ReadName;
    SkipWhite;
    Expect('=');
    SkipWhite;
    AValue := ReadAttrValue;
    if (FOptions.MaxAttributes > 0) and (FRawCount >= FOptions.MaxAttributes) then
      FailSec(XFE_SEC_ATTRIBUTE_LIMIT, 'Too many attributes on element <' + QName + '>');
    for I := 0 to FRawCount - 1 do
      if FRawNames[I] = AName then
        Fail(XFE_DUPLICATE_ATTRIBUTE, 'Duplicate attribute "' + AName + '" on element <' + QName + '>');
    if FRawCount >= System.Length(FRawNames) then
    begin
      SetLength(FRawNames, FRawCount * 2 + 8);
      SetLength(FRawValues, FRawCount * 2 + 8);
    end;
    FRawNames[FRawCount] := AName;
    FRawValues[FRawCount] := AValue;
    Inc(FRawCount);
  end;

  Mark := FNsCount;
  FAttrs.Clear;
  if FOptions.NamespaceAware then
  begin
    for I := 0 to FRawCount - 1 do
    begin
      AName := FRawNames[I];
      if AName = 'xmlns' then
        DeclareNs('', FRawValues[I])
      else if Copy(AName, 1, 6) = 'xmlns:' then
        DeclareNs(Copy(AName, 7, MaxInt), FRawValues[I]);
    end;
    if not XmlSplitQName(QName, Prefix, Local) then
      FailNs(XFE_NS_INVALID, 'Invalid qualified name "' + QName + '"');
    if not LookupNs(Prefix, Uri) then
      FailNs(XFE_NS_UNBOUND_PREFIX, 'Unbound namespace prefix "' + Prefix + '" on element <' + QName + '>');
    for I := 0 to FRawCount - 1 do
    begin
      AName := FRawNames[I];
      if (AName = 'xmlns') or (Copy(AName, 1, 6) = 'xmlns:') then Continue;
      if not XmlSplitQName(AName, APrefix, ALocal) then
        FailNs(XFE_NS_INVALID, 'Invalid qualified attribute name "' + AName + '"');
      if APrefix = '' then
        AUri := ''
      else if not LookupNs(APrefix, AUri) then
        FailNs(XFE_NS_UNBOUND_PREFIX, 'Unbound namespace prefix "' + APrefix + '" on attribute "' + AName + '"');
      for J := 0 to FAttrs.Count - 1 do
        if (FAttrs.LocalName[J] = ALocal) and (FAttrs.NamespaceURI[J] = AUri) then
          Fail(XFE_DUPLICATE_ATTRIBUTE, 'Duplicate (expanded) attribute "' + AName + '"');
      FAttrs.Add(AName, APrefix, ALocal, AUri, FRawValues[I]);
    end;
  end
  else
  begin
    Prefix := '';
    Local := QName;
    Uri := '';
    for I := 0 to FRawCount - 1 do
      FAttrs.Add(FRawNames[I], '', FRawNames[I], '', FRawValues[I]);
  end;

  FHandler.StartElement(Uri, Local, QName, FAttrs, Line, Col);
  if FDepth >= System.Length(FStackQ) then
  begin
    SetLength(FStackQ, FDepth * 2 + 16);
    SetLength(FStackL, FDepth * 2 + 16);
    SetLength(FStackU, FDepth * 2 + 16);
    SetLength(FStackMark, FDepth * 2 + 16);
  end;
  FStackQ[FDepth] := QName;
  FStackL[FDepth] := Local;
  FStackU[FDepth] := Uri;
  FStackMark[FDepth] := Mark;
  Inc(FDepth);
  if SelfClose then PopElement;
end;

procedure TXmlParser.PopElement;
var
  I, D: Integer;
begin
  D := FDepth - 1;
  FHandler.EndElement(FStackU[D], FStackL[D], FStackQ[D]);
  for I := FNsCount - 1 downto FStackMark[D] do
    FHandler.EndPrefixMapping(FNsPrefix[I]);
  FNsCount := FStackMark[D];
  Dec(FDepth);
end;

procedure TXmlParser.ParseEndTag(BaseDepth: Integer);
var
  Name: XmlString;
begin
  FReader.Skip(2); // '</'
  Name := ReadName;
  SkipWhite;
  Expect('>');
  if FDepth <= BaseDepth then
    Fail(XFE_MISMATCHED_TAG, 'Unexpected end tag </' + Name + '>');
  if Name <> FStackQ[FDepth - 1] then
    Fail(XFE_MISMATCHED_TAG, 'Mismatched end tag: expected </' + FStackQ[FDepth - 1] + '> but found </' + Name + '>');
  PopElement;
end;

procedure TXmlParser.ParseCharData;
var
  C: Integer;
begin
  while True do
  begin
    C := FReader.Peek;
    if (C < 0) or (C = Ord('<')) or (C = Ord('&')) then Break;
    C := FReader.Next;   // Next normalises CR / CRLF to LF
    if (C = Ord('>')) and FText.EndsWith(']', ']') then
      Fail(XFE_INVALID_CHAR, 'The sequence "]]>" is not allowed in character data');
    AppendChecked(FText, C);
    if FText.Len >= 65536 then FlushPartial;
  end;
end;

procedure TXmlParser.ParseCData;
var
  C: Integer;
begin
  FReader.Skip(9); // '<![CDATA['
  FTmp.Clear;
  while True do
  begin
    C := FReader.Next;
    if C < 0 then Fail(XFE_BAD_CDATA, 'Unterminated CDATA section');
    if (C = Ord(']')) and (FReader.PeekAt(0) = Ord(']')) and (FReader.PeekAt(1) = Ord('>')) then
    begin
      FReader.Skip(2);
      Break;
    end;
    AppendChecked(FTmp, C);
  end;
  FHandler.CData(FTmp.AsString);
end;

procedure TXmlParser.ParseComment;
var
  C: Integer;
begin
  FReader.Skip(4); // '<!--'
  FTmp.Clear;
  while True do
  begin
    C := FReader.Next;
    if C < 0 then Fail(XFE_BAD_COMMENT, 'Unterminated comment');
    if C = Ord('-') then
    begin
      if FReader.Peek = Ord('-') then
      begin
        FReader.Next;
        if FReader.Peek = Ord('>') then
        begin
          FReader.Next;
          Break;
        end;
        Fail(XFE_BAD_COMMENT, 'The sequence "--" is not allowed inside comments');
      end;
    end;
    AppendChecked(FTmp, C);
  end;
  if not FInDtd then FHandler.Comment(FTmp.AsString);
end;

procedure TXmlParser.ParsePI;
var
  Target: XmlString;
  C: Integer;
begin
  FReader.Skip(2); // '<?'
  Target := ReadName;
  if SameText(Target, 'xml') then
    Fail(XFE_BAD_PI, 'The processing instruction target "xml" is reserved');
  FTmp.Clear;
  if FReader.Matches('?>') then
    FReader.Skip(2)
  else
  begin
    ReqWhite;
    while True do
    begin
      C := FReader.Next;
      if C < 0 then Fail(XFE_BAD_PI, 'Unterminated processing instruction');
      if (C = Ord('?')) and (FReader.Peek = Ord('>')) then
      begin
        FReader.Next;
        Break;
      end;
      AppendChecked(FTmp, C);
    end;
  end;
  if not FInDtd then FHandler.ProcessingInstruction(Target, FTmp.AsString);
end;

procedure TXmlParser.ParseContent(BaseDepth: Integer; InEntity: Boolean);
var
  C: Integer;
begin
  while True do
  begin
    C := FReader.Peek;
    if C < 0 then
    begin
      if InEntity then
      begin
        FlushText;
        Exit;
      end;
      Fail(XFE_UNEXPECTED_EOF, 'Unexpected end of document: unclosed element <' + FStackQ[FDepth - 1] + '>');
    end;
    if C = Ord('<') then
    begin
      FlushText;
      if FReader.Matches('</') then
      begin
        ParseEndTag(BaseDepth);
        if (not InEntity) and (FDepth = 0) then Exit;
      end
      else if FReader.Matches('<!--') then
        ParseComment
      else if FReader.Matches('<![CDATA[') then
        ParseCData
      else if FReader.Matches('<?') then
        ParsePI
      else if FReader.Matches('<!') then
        Fail(XFE_PARSE_GENERIC, 'Unexpected markup declaration inside element content')
      else
        ParseStartTag;
    end
    else if C = Ord('&') then
    begin
      FReader.Next;
      ParseReference;
    end
    else
      ParseCharData;
  end;
end;

{ ---- prolog, declaration, DOCTYPE ---- }

procedure TXmlParser.ParseXmlDecl;
var
  Name, Value: XmlString;
  HadWhite: Boolean;
begin
  FReader.Skip(5); // '<?xml'
  FHasDecl := True;
  SkipWhite;
  Name := ReadName;
  if Name <> 'version' then Fail(XFE_BAD_DECLARATION, 'XML declaration must start with "version"');
  SkipWhite;
  Expect('=');
  SkipWhite;
  FVersion := ReadQuoted;
  if (FVersion <> '1.0') and (FVersion <> '1.1') then
    Fail(XFE_BAD_DECLARATION, 'Unsupported XML version "' + FVersion + '"');
  FXml11 := FVersion = '1.1';
  while True do
  begin
    HadWhite := SkipWhite > 0;
    if FReader.Matches('?>') then
    begin
      FReader.Skip(2);
      Break;
    end;
    if not HadWhite then Fail(XFE_BAD_DECLARATION, 'Malformed XML declaration');
    Name := ReadName;
    SkipWhite;
    Expect('=');
    SkipWhite;
    Value := ReadQuoted;
    if Name = 'encoding' then
      FEncodingDecl := Value
    else if Name = 'standalone' then
    begin
      if Value = 'yes' then FStandalone := xsYes
      else if Value = 'no' then FStandalone := xsNo
      else Fail(XFE_BAD_DECLARATION, 'standalone must be "yes" or "no"');
    end
    else
      Fail(XFE_BAD_DECLARATION, 'Unexpected pseudo-attribute "' + Name + '" in XML declaration');
  end;
end;

procedure TXmlParser.ParseExternalId(out PubId, SysId: XmlString);
begin
  PubId := '';
  SysId := '';
  if FReader.Matches('SYSTEM') then
  begin
    FReader.Skip(6);
    ReqWhite;
    SysId := ReadQuoted;
  end
  else if FReader.Matches('PUBLIC') then
  begin
    FReader.Skip(6);
    ReqWhite;
    PubId := ReadQuoted;
    SkipWhite;
    if (FReader.Peek = 34) or (FReader.Peek = 39) then SysId := ReadQuoted;
  end;
end;

procedure TXmlParser.SkipDecl;
var
  C, Q: Integer;
begin
  FReader.Skip(2); // '<!'
  while True do
  begin
    C := FReader.Next;
    if C < 0 then Fail(XFE_BAD_DOCTYPE, 'Unterminated markup declaration in DOCTYPE');
    if (C = 34) or (C = 39) then
    begin
      Q := C;
      repeat
        C := FReader.Next;
        if C < 0 then Fail(XFE_BAD_DOCTYPE, 'Unterminated literal in DOCTYPE');
      until C = Q;
    end
    else if C = Ord('>') then
      Break;
  end;
end;

function TXmlParser.ProcessEntityLiteral(const Raw: XmlString): XmlString;
var
  B: TXmlStrBuf;
  I, J: Integer;
  CP: Cardinal;
  Hex: Boolean;
  Digits: Integer;
  C: Integer;
begin
  B := TXmlStrBuf.Create(System.Length(Raw) + 8);
  try
    I := 1;
    while I <= System.Length(Raw) do
    begin
      if (Raw[I] = '&') and (I < System.Length(Raw)) and (Raw[I + 1] = '#') then
      begin
        J := I + 2;
        Hex := (J <= System.Length(Raw)) and (Raw[J] = 'x');
        if Hex then Inc(J);
        CP := 0;
        Digits := 0;
        while J <= System.Length(Raw) do
        begin
          C := Ord(Raw[J]);
          if (C >= 48) and (C <= 57) then C := C - 48
          else if Hex and (C >= 65) and (C <= 70) then C := C - 55
          else if Hex and (C >= 97) and (C <= 102) then C := C - 87
          else Break;
          if CP <= $10FFFF then
          begin
            if Hex then CP := CP * 16 + Cardinal(C) else CP := CP * 10 + Cardinal(C);
          end;
          Inc(Digits);
          Inc(J);
        end;
        if (Digits = 0) or (J > System.Length(Raw)) or (Raw[J] <> ';') or (not XmlIsXmlChar(CP)) then
          Fail(XFE_BAD_DOCTYPE, 'Invalid character reference in entity value');
        B.AppendCodePoint(CP);
        I := J + 1;
      end
      else
      begin
        B.AppendChar(Raw[I]);
        Inc(I);
      end;
    end;
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

procedure TXmlParser.ParseEntityDecl;
var
  IsPE: Boolean;
  Name, Value, Pub, Sys: XmlString;
  External: Boolean;
begin
  FReader.Skip(8); // '<!ENTITY'
  ReqWhite;
  IsPE := FReader.Peek = Ord('%');
  if IsPE then
  begin
    FReader.Next;
    ReqWhite;
  end;
  Name := ReadName;
  ReqWhite;
  External := False;
  Value := '';
  if (FReader.Peek = 34) or (FReader.Peek = 39) then
    Value := ProcessEntityLiteral(ReadQuoted)
  else
  begin
    External := True;
    ParseExternalId(Pub, Sys);
    if SkipWhite > 0 then
    begin
      if FReader.Matches('NDATA') then
      begin
        FReader.Skip(5);
        ReqWhite;
        ReadName;
      end;
    end;
  end;
  SkipWhite;
  Expect('>');
  if (not IsPE) and (FOptions.DtdMode = dtdAllow) then AddEntity(Name, Value, External);
end;

procedure TXmlParser.ParseInternalSubset;
var
  C: Integer;
begin
  FInDtd := True;
  try
  while True do
  begin
    C := FReader.Peek;
    if C < 0 then Fail(XFE_BAD_DOCTYPE, 'Unterminated DOCTYPE internal subset');
    if XmlIsWhite(C) then
      FReader.Next
    else if C = Ord(']') then
      Break
    else if C = Ord('%') then
    begin
      FReader.Next;
      ReadName;
      Expect(';');
    end
    else if FReader.Matches('<!--') then
      ParseComment
    else if FReader.Matches('<?') then
      ParsePI
    else if FReader.Matches('<!ENTITY') then
      ParseEntityDecl
    else if FReader.Matches('<!') then
      SkipDecl
    else
      Fail(XFE_BAD_DOCTYPE, 'Unexpected content in DOCTYPE internal subset');
  end;
  finally
    FInDtd := False;
  end;
end;

procedure TXmlParser.ParseDocType;
var
  Name, Pub, Sys, Subset: XmlString;
  Cap: TXmlStrBuf;
begin
  if FOptions.DtdMode = dtdProhibit then
    FailSec(XFE_SEC_DTD_PROHIBITED, 'DOCTYPE declarations are prohibited by the parser options');
  FReader.Skip(9); // '<!DOCTYPE'
  ReqWhite;
  Name := ReadName;
  SkipWhite;
  ParseExternalId(Pub, Sys);
  SkipWhite;
  Subset := '';
  if FReader.Peek = Ord('[') then
  begin
    FReader.Next;
    Cap := TXmlStrBuf.Create(256);
    try
      FReader.Capture := Cap;
      try
        ParseInternalSubset;
      finally
        FReader.Capture := nil;
      end;
      Subset := Cap.AsString;
    finally
      Cap.Free;
    end;
    Expect(']');
    SkipWhite;
  end;
  Expect('>');
  FHandler.DocType(Name, Pub, Sys, Subset);
end;

{ ---- driver ---- }

procedure TXmlParser.DoParse(AReader: TXmlInputReader; AHandler: TXmlSaxHandler);
var
  C: Integer;
begin
  FReader := AReader;
  FMain := AReader;
  FHandler := AHandler;
  FText.Clear;
  FDepth := 0;
  FNsCount := 0;
  FEntCount := 0;
  FEntDepth := 0;
  FExpanded := 0;
  FXml11 := False;
  FDoctypeSeen := False;
  FInDtd := False;
  FVersion := '1.0';
  FEncodingDecl := '';
  FStandalone := xsUnspecified;
  FHasDecl := False;
  FElemCounter := 0;
  FCancelled := False;

  if FReader.Peek = $FEFF then FReader.Next; // stray BOM char (string input)
  if FReader.Matches('<?xml') and XmlIsWhite(FReader.PeekAt(5)) then ParseXmlDecl;
  FHandler.StartDocument(FVersion, FEncodingDecl, FStandalone, FHasDecl);

  repeat
    SkipWhite;
    C := FReader.Peek;
    if C < 0 then Fail(XFE_NO_ROOT, 'The document has no root element');
    if C <> Ord('<') then
      Fail(XFE_TEXT_OUTSIDE_ROOT, 'Text content is not allowed outside the root element');
    if FReader.Matches('<!--') then
      ParseComment
    else if FReader.Matches('<?') then
      ParsePI
    else if FReader.Matches('<!DOCTYPE') then
    begin
      if FDoctypeSeen then Fail(XFE_BAD_DOCTYPE, 'Only one DOCTYPE declaration is allowed');
      FDoctypeSeen := True;
      ParseDocType;
    end
    else if FReader.Matches('<!') then
      Fail(XFE_BAD_DOCTYPE, 'Unexpected markup declaration before the root element')
    else
      Break;
  until False;

  ParseStartTag;
  if FDepth > 0 then ParseContent(0, False);
  FlushText;

  repeat
    SkipWhite;
    C := FReader.Peek;
    if C < 0 then Break;
    if C <> Ord('<') then
      Fail(XFE_TEXT_OUTSIDE_ROOT, 'Content is not allowed after the root element');
    if FReader.Matches('<!--') then
      ParseComment
    else if FReader.Matches('<?') then
      ParsePI
    else
      Fail(XFE_MULTIPLE_ROOT, 'Only one root element is allowed');
  until False;

  FHandler.EndDocument;
end;

procedure TXmlParser.ParseStream(Stream: TStream; Handler: TXmlSaxHandler);
var
  R: TXmlInputReader;
begin
  R := TXmlInputReader.CreateStream(Stream, FOptions.BufferSize, FOptions.MaxDocumentSize);
  try
    DoParse(R, Handler);
  finally
    R.Free;
  end;
end;

procedure TXmlParser.ParseFile(const FileName: string; Handler: TXmlSaxHandler);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    ParseStream(FS, Handler);
  finally
    FS.Free;
  end;
end;

procedure TXmlParser.ParseString(const Xml: XmlString; Handler: TXmlSaxHandler);
var
  R: TXmlInputReader;
begin
  if (FOptions.MaxDocumentSize > 0) and
     (Int64(System.Length(Xml)) * 2 > FOptions.MaxDocumentSize) then
    raise EXmlSecurityException.CreateCode(XFE_SEC_SIZE_LIMIT, 'Maximum document size exceeded');
  R := TXmlInputReader.CreateString(Xml);
  try
    DoParse(R, Handler);
  finally
    R.Free;
  end;
end;

end.
