{$I XmlForge4D.inc}
unit XmlForge4D.Writer;

{ Forward-only XML writer: stream or string target, pretty printing,
  UTF-8 / UTF-16 / Latin-1 / ASCII output, strict escaping and validation. }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Encoding;

type
  TXmlDeclarationMode = (xdAuto, xdAlways, xdNever);

  TXmlWriterOptions = record
    Indent: Boolean;                  // pretty print (default False)
    IndentSize: Integer;              // spaces per level (default 2)
    NewLine: XmlString;               // default #10
    Encoding: TXmlEncoding;           // default UTF-8
    WriteBom: Boolean;                // default False
    DeclarationMode: TXmlDeclarationMode; // default xdAuto (follow the document)
    SelfCloseEmpty: Boolean;          // <a/> instead of <a></a> (default True)
    ValidateNames: Boolean;           // default True
    ValidateChars: Boolean;           // default True
    BufferSize: Integer;              // characters buffered before flushing
    class function Default: TXmlWriterOptions; static;
  end;

  TXmlWriter = class
  private
    FStream: TStream;
    FBuf: TXmlStrBuf;
    FBytes: TBytes;
    FOpts: TXmlWriterOptions;
    FNames: array of XmlString;
    FHasChildren: array of Boolean;
    FHasText: array of Boolean;
    FDepth: Integer;
    FOpenTag: Boolean;
    FAny: Boolean;
    FBomDone: Boolean;
    FMaxChar: Cardinal;
    procedure Fail(Code: Integer; const Msg: XmlString);
    procedure CloseStartTag;
    procedure BeforeNode(IsText: Boolean);
    procedure WriteIndent(Level: Integer);
    procedure CheckName(const Name: XmlString);
    procedure AppendEscaped(const S: XmlString; Attr: Boolean);
    procedure AppendChecked(const S: XmlString);
    procedure MaybeFlush;
    procedure Emit(const S: XmlString);
  public
    constructor Create(AStream: TStream; const AOptions: TXmlWriterOptions); overload;
    constructor CreateToString(const AOptions: TXmlWriterOptions);
    destructor Destroy; override;
    procedure WriteStartDocument(const Version: XmlString = '1.0';
      const EncodingName: XmlString = ''; Standalone: TXmlStandalone = xsUnspecified);
    procedure WriteDocType(const Name, PublicId, SystemId, InternalSubset: XmlString);
    procedure WriteStartElement(const QName: XmlString);
    procedure WriteAttribute(const QName, Value: XmlString);
    procedure WriteEndElement;
    procedure WriteFullEndElement;
    procedure WriteElementString(const QName, Text: XmlString);
    procedure WriteText(const Text: XmlString);
    procedure WriteCData(const Text: XmlString);
    procedure WriteComment(const Text: XmlString);
    procedure WriteProcessingInstruction(const Target, Data: XmlString);
    procedure WriteRaw(const Xml: XmlString);
    procedure EndDocument;
    procedure Flush;
    { Result of a writer created with CreateToString. }
    function Text: XmlString;
    property Depth: Integer read FDepth;
  end;

function XmlEscapeText(const S: XmlString): XmlString;
function XmlEscapeAttribute(const S: XmlString): XmlString;

implementation

class function TXmlWriterOptions.Default: TXmlWriterOptions;
begin
  Result.Indent := False;
  Result.IndentSize := 2;
  Result.NewLine := #10;
  Result.Encoding := xeUtf8;
  Result.WriteBom := False;
  Result.DeclarationMode := xdAuto;
  Result.SelfCloseEmpty := True;
  Result.ValidateNames := True;
  Result.ValidateChars := True;
  Result.BufferSize := 32768;
end;

function EscapeCore(const S: XmlString; Attr: Boolean): XmlString;
var
  B: TXmlStrBuf;
  I: Integer;
  C: WideChar;
begin
  B := TXmlStrBuf.Create(System.Length(S) + 16);
  try
    for I := 1 to System.Length(S) do
    begin
      C := S[I];
      case C of
        '&': B.Append('&amp;');
        '<': B.Append('&lt;');
        '>': B.Append('&gt;');
        '"': if Attr then B.Append('&quot;') else B.AppendChar(C);
        #9: if Attr then B.Append('&#9;') else B.AppendChar(C);
        #10: if Attr then B.Append('&#10;') else B.AppendChar(C);
        #13: B.Append('&#13;');
      else
        B.AppendChar(C);
      end;
    end;
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

function XmlEscapeText(const S: XmlString): XmlString;
begin
  Result := EscapeCore(S, False);
end;

function XmlEscapeAttribute(const S: XmlString): XmlString;
begin
  Result := EscapeCore(S, True);
end;

{ TXmlWriter }

constructor TXmlWriter.Create(AStream: TStream; const AOptions: TXmlWriterOptions);
begin
  inherited Create;
  FStream := AStream;
  FOpts := AOptions;
  FBuf := TXmlStrBuf.Create(FOpts.BufferSize + 1024);
  FMaxChar := XmlMaxCharForEncoding(FOpts.Encoding);
end;

constructor TXmlWriter.CreateToString(const AOptions: TXmlWriterOptions);
begin
  inherited Create;
  FStream := nil;
  FOpts := AOptions;
  FBuf := TXmlStrBuf.Create(4096);
  FMaxChar := $10FFFF;
end;

destructor TXmlWriter.Destroy;
begin
  FBuf.Free;
  inherited Destroy;
end;

procedure TXmlWriter.Fail(Code: Integer; const Msg: XmlString);
begin
  raise EXmlSerializationException.CreateCode(Code, Msg);
end;

procedure TXmlWriter.Emit(const S: XmlString);
begin
  FBuf.Append(S);
  FAny := True;
end;

procedure TXmlWriter.MaybeFlush;
begin
  if (FStream <> nil) and (FBuf.Len >= FOpts.BufferSize) then Flush;
end;

procedure TXmlWriter.Flush;
var
  Len: Integer;
  Bom: TBytes;
begin
  if FStream = nil then Exit;
  if (not FBomDone) then
  begin
    FBomDone := True;
    if FOpts.WriteBom then
    begin
      case FOpts.Encoding of
        xeUtf8:
          begin
            SetLength(Bom, 3);
            Bom[0] := $EF; Bom[1] := $BB; Bom[2] := $BF;
            FStream.WriteBuffer(Bom[0], 3);
          end;
        xeUtf16LE:
          begin
            SetLength(Bom, 2);
            Bom[0] := $FF; Bom[1] := $FE;
            FStream.WriteBuffer(Bom[0], 2);
          end;
        xeUtf16BE:
          begin
            SetLength(Bom, 2);
            Bom[0] := $FE; Bom[1] := $FF;
            FStream.WriteBuffer(Bom[0], 2);
          end;
      end;
    end;
  end;
  if FBuf.Len = 0 then Exit;
  Len := 0;
  XmlEncodeAppend(FBuf.AsString, FOpts.Encoding, FBytes, Len);
  if Len > 0 then FStream.WriteBuffer(FBytes[0], Len);
  FBuf.Clear;
end;

function TXmlWriter.Text: XmlString;
begin
  Result := FBuf.AsString;
end;

procedure TXmlWriter.CheckName(const Name: XmlString);
begin
  if FOpts.ValidateNames and (not XmlIsValidName(Name)) then
    Fail(XFE_SER_INVALID_NAME, 'Invalid XML name "' + Name + '"');
end;

procedure TXmlWriter.AppendChecked(const S: XmlString);
var
  I, C, D: Integer;
begin
  if FOpts.ValidateChars then
  begin
    I := 1;
    while I <= System.Length(S) do
    begin
      C := Ord(S[I]);
      if C < 32 then
      begin
        if (C <> 9) and (C <> 10) and (C <> 13) then
          Fail(XFE_SER_INVALID_CHAR, 'Character U+' + IntToHex(C, 4) + ' is not allowed in XML');
      end
      else if C >= $D800 then
      begin
        if C <= $DBFF then
        begin
          if I < System.Length(S) then D := Ord(S[I + 1]) else D := 0;
          if (D < $DC00) or (D > $DFFF) then
            Fail(XFE_SER_INVALID_CHAR, 'Unpaired surrogate in text');
          Inc(I);
        end
        else if C <= $DFFF then
          Fail(XFE_SER_INVALID_CHAR, 'Unpaired surrogate in text')
        else if C >= $FFFE then
          Fail(XFE_SER_INVALID_CHAR, 'Character U+' + IntToHex(C, 4) + ' is not allowed in XML');
      end;
      Inc(I);
    end;
  end;
  Emit(S);
end;

procedure TXmlWriter.AppendEscaped(const S: XmlString; Attr: Boolean);
var
  I, C, D: Integer;
  CP: Cardinal;
begin
  I := 1;
  while I <= System.Length(S) do
  begin
    C := Ord(S[I]);
    case C of
      38: FBuf.Append('&amp;');
      60: FBuf.Append('&lt;');
      62: FBuf.Append('&gt;');
      34: if Attr then FBuf.Append('&quot;') else FBuf.Append('"');
      9: if Attr then FBuf.Append('&#9;') else FBuf.Append(#9);
      10: if Attr then FBuf.Append('&#10;') else FBuf.Append(#10);
      13: FBuf.Append('&#13;');
    else
      begin
        if C < 32 then
        begin
          if FOpts.ValidateChars then
            Fail(XFE_SER_INVALID_CHAR, 'Character U+' + IntToHex(C, 4) + ' is not allowed in XML');
          FBuf.AppendChar(WideChar(C));
        end
        else if (C >= $D800) and (C <= $DBFF) then
        begin
          if I < System.Length(S) then D := Ord(S[I + 1]) else D := 0;
          if (D < $DC00) or (D > $DFFF) then
            Fail(XFE_SER_INVALID_CHAR, 'Unpaired surrogate in text');
          CP := $10000 + (Cardinal(C - $D800) shl 10) + Cardinal(D - $DC00);
          Inc(I);
          if CP > FMaxChar then
            FBuf.Append('&#x' + IntToHex(CP, 1) + ';')
          else
          begin
            FBuf.AppendChar(WideChar(C));
            FBuf.AppendChar(WideChar(D));
          end;
        end
        else if (C >= $DC00) and (C <= $DFFF) then
          Fail(XFE_SER_INVALID_CHAR, 'Unpaired surrogate in text')
        else if (C = $FFFE) or (C = $FFFF) then
        begin
          if FOpts.ValidateChars then
            Fail(XFE_SER_INVALID_CHAR, 'Character U+' + IntToHex(C, 4) + ' is not allowed in XML');
          FBuf.AppendChar(WideChar(C));
        end
        else if Cardinal(C) > FMaxChar then
          FBuf.Append('&#x' + IntToHex(C, 1) + ';')
        else
          FBuf.AppendChar(WideChar(C));
      end;
    end;
    Inc(I);
  end;
  FAny := True;
end;

procedure TXmlWriter.WriteIndent(Level: Integer);
var
  I: Integer;
begin
  if FAny then FBuf.Append(FOpts.NewLine);
  for I := 1 to Level * FOpts.IndentSize do FBuf.Append(' ');
end;

procedure TXmlWriter.CloseStartTag;
begin
  if FOpenTag then
  begin
    FBuf.Append('>');
    FOpenTag := False;
  end;
end;

procedure TXmlWriter.BeforeNode(IsText: Boolean);
begin
  CloseStartTag;
  if IsText then
  begin
    if FDepth > 0 then FHasText[FDepth - 1] := True;
  end
  else
  begin
    if FOpts.Indent then
    begin
      if (FDepth = 0) or (not FHasText[FDepth - 1]) then WriteIndent(FDepth);
    end;
    if FDepth > 0 then FHasChildren[FDepth - 1] := True;
  end;
end;

procedure TXmlWriter.WriteStartDocument(const Version, EncodingName: XmlString;
  Standalone: TXmlStandalone);
begin
  if FAny or (FDepth > 0) then Fail(XFE_SER_INVALID_STATE, 'XML declaration must be the first item written');
  Emit('<?xml version="' + Version + '"');
  if EncodingName <> '' then Emit(' encoding="' + EncodingName + '"');
  case Standalone of
    xsYes: Emit(' standalone="yes"');
    xsNo: Emit(' standalone="no"');
  end;
  Emit('?>');
  MaybeFlush;
end;

procedure TXmlWriter.WriteDocType(const Name, PublicId, SystemId, InternalSubset: XmlString);
var
  Q: XmlString;
begin
  if FDepth > 0 then Fail(XFE_SER_INVALID_STATE, 'DOCTYPE must appear before the root element');
  CheckName(Name);
  BeforeNode(False);
  Emit('<!DOCTYPE ' + Name);
  if PublicId <> '' then
  begin
    Emit(' PUBLIC "' + PublicId + '"');
    if SystemId <> '' then
    begin
      if Pos('"', SystemId) > 0 then Q := '''' else Q := '"';
      Emit(' ' + Q + SystemId + Q);
    end;
  end
  else if SystemId <> '' then
  begin
    if Pos('"', SystemId) > 0 then Q := '''' else Q := '"';
    Emit(' SYSTEM ' + Q + SystemId + Q);
  end;
  if InternalSubset <> '' then Emit(' [' + InternalSubset + ']');
  Emit('>');
  MaybeFlush;
end;

procedure TXmlWriter.WriteStartElement(const QName: XmlString);
begin
  CheckName(QName);
  BeforeNode(False);
  if FDepth >= System.Length(FNames) then
  begin
    SetLength(FNames, FDepth * 2 + 16);
    SetLength(FHasChildren, FDepth * 2 + 16);
    SetLength(FHasText, FDepth * 2 + 16);
  end;
  FNames[FDepth] := QName;
  FHasChildren[FDepth] := False;
  FHasText[FDepth] := False;
  Inc(FDepth);
  Emit('<' + QName);
  FOpenTag := True;
end;

procedure TXmlWriter.WriteAttribute(const QName, Value: XmlString);
begin
  if not FOpenTag then
    Fail(XFE_SER_INVALID_STATE, 'WriteAttribute is only valid directly after WriteStartElement');
  CheckName(QName);
  FBuf.Append(' ');
  FBuf.Append(QName);
  FBuf.Append('="');
  AppendEscaped(Value, True);
  FBuf.Append('"');
end;

procedure TXmlWriter.WriteEndElement;
var
  D: Integer;
begin
  if FDepth = 0 then Fail(XFE_SER_INVALID_STATE, 'No open element to close');
  D := FDepth - 1;
  if FOpenTag then
  begin
    if FOpts.SelfCloseEmpty then
      FBuf.Append('/>')
    else
      FBuf.Append('></' + FNames[D] + '>');
    FOpenTag := False;
  end
  else
  begin
    if FOpts.Indent and FHasChildren[D] and (not FHasText[D]) then WriteIndent(D);
    FBuf.Append('</' + FNames[D] + '>');
  end;
  Dec(FDepth);
  MaybeFlush;
end;

procedure TXmlWriter.WriteFullEndElement;
var
  D: Integer;
begin
  if FDepth = 0 then Fail(XFE_SER_INVALID_STATE, 'No open element to close');
  D := FDepth - 1;
  if FOpenTag then
  begin
    FBuf.Append('>');
    FOpenTag := False;
  end
  else if FOpts.Indent and FHasChildren[D] and (not FHasText[D]) then
    WriteIndent(D);
  FBuf.Append('</' + FNames[D] + '>');
  Dec(FDepth);
  MaybeFlush;
end;

procedure TXmlWriter.WriteElementString(const QName, Text: XmlString);
begin
  WriteStartElement(QName);
  WriteText(Text);
  WriteEndElement;
end;

procedure TXmlWriter.WriteText(const Text: XmlString);
begin
  if Text = '' then Exit;
  if FDepth = 0 then Fail(XFE_SER_INVALID_STATE, 'Text is not allowed outside the root element');
  BeforeNode(True);
  AppendEscaped(Text, False);
  MaybeFlush;
end;

procedure TXmlWriter.WriteCData(const Text: XmlString);
var
  P: Integer;
  S: XmlString;
begin
  if FDepth = 0 then Fail(XFE_SER_INVALID_STATE, 'CDATA is not allowed outside the root element');
  BeforeNode(True);
  S := Text;
  Emit('<![CDATA[');
  repeat
    P := Pos(']]>', S);
    if P = 0 then
    begin
      AppendChecked(S);
      Break;
    end;
    AppendChecked(Copy(S, 1, P + 1));
    Emit(']]><![CDATA[');
    S := Copy(S, P + 2, MaxInt);
  until False;
  Emit(']]>');
  MaybeFlush;
end;

procedure TXmlWriter.WriteComment(const Text: XmlString);
begin
  if (Pos('--', Text) > 0) or ((Text <> '') and (Text[System.Length(Text)] = '-')) then
    Fail(XFE_SER_INVALID_CONTENT, 'Comment text must not contain "--" or end with "-"');
  BeforeNode(False);
  Emit('<!--');
  AppendChecked(Text);
  Emit('-->');
  MaybeFlush;
end;

procedure TXmlWriter.WriteProcessingInstruction(const Target, Data: XmlString);
begin
  CheckName(Target);
  if SameText(Target, 'xml') then Fail(XFE_SER_INVALID_NAME, 'PI target "xml" is reserved');
  if Pos('?>', Data) > 0 then Fail(XFE_SER_INVALID_CONTENT, 'PI data must not contain "?>"');
  BeforeNode(False);
  Emit('<?' + Target);
  if Data <> '' then
  begin
    Emit(' ');
    AppendChecked(Data);
  end;
  Emit('?>');
  MaybeFlush;
end;

procedure TXmlWriter.WriteRaw(const Xml: XmlString);
begin
  BeforeNode(True);
  Emit(Xml);
  MaybeFlush;
end;

procedure TXmlWriter.EndDocument;
begin
  while FDepth > 0 do WriteEndElement;
  Flush;
end;

end.
