{$I XmlForge4D.inc}
unit XmlForge4D.Encoding;

{ Self-contained codecs so behaviour is identical on Delphi and Free Pascal,
  on every operating system. Supported: UTF-8, UTF-16 LE/BE, ISO-8859-1, US-ASCII. }

interface

uses
  SysUtils, Classes, XmlForge4D.Types;

type
  TXmlEncoding = (xeUtf8, xeUtf16LE, xeUtf16BE, xeLatin1, xeAscii);

function XmlEncodingName(Enc: TXmlEncoding): XmlString;
function XmlEncodingFromName(const Name: XmlString; out Enc: TXmlEncoding): Boolean;
function XmlMaxCharForEncoding(Enc: TXmlEncoding): Cardinal;

{ Detects a BOM at the start of Buf. }
function XmlDetectBom(const Buf: TBytes; Count: Integer; out Enc: TXmlEncoding;
  out BomLen: Integer): Boolean;

{ BOM -> UTF-16 patterns -> encoding="..." of the XML declaration -> UTF-8.
  Raises EXmlEncodingException for a declared but unsupported encoding. }
function XmlDetectEncoding(const Buf: TBytes; Count: Integer; out BomLen: Integer;
  out DeclaredName: XmlString): TXmlEncoding;

{ Decodes as many complete characters as possible. Dst must have room for
  SrcCount + 1 characters starting at DstStart. Consumed = bytes used. }
function XmlDecodeBytes(Enc: TXmlEncoding; const Src: TBytes; SrcStart, SrcCount: Integer;
  var Dst: TWideCharArray; DstStart: Integer; out Consumed: Integer; Final: Boolean): Integer;

{ Appends the encoded form of S to Dest[0..DestLen-1], growing Dest. }
procedure XmlEncodeAppend(const S: XmlString; Enc: TXmlEncoding; var Dest: TBytes;
  var DestLen: Integer);

function XmlUtf8Encode(const S: XmlString): TBytes;
function XmlUtf8Decode(const B: TBytes): XmlString;

implementation

function XmlEncodingName(Enc: TXmlEncoding): XmlString;
begin
  case Enc of
    xeUtf8: Result := 'UTF-8';
    xeUtf16LE, xeUtf16BE: Result := 'UTF-16';
    xeLatin1: Result := 'ISO-8859-1';
  else
    Result := 'US-ASCII';
  end;
end;

function XmlEncodingFromName(const Name: XmlString; out Enc: TXmlEncoding): Boolean;
var
  U: XmlString;
begin
  U := UpperCase(Name);
  Result := True;
  if (U = 'UTF-8') or (U = 'UTF8') then Enc := xeUtf8
  else if (U = 'UTF-16') or (U = 'UTF-16LE') or (U = 'UTF16') then Enc := xeUtf16LE
  else if U = 'UTF-16BE' then Enc := xeUtf16BE
  else if (U = 'ISO-8859-1') or (U = 'LATIN1') or (U = 'ISO_8859-1') or (U = 'L1') then Enc := xeLatin1
  else if (U = 'US-ASCII') or (U = 'ASCII') then Enc := xeAscii
  else Result := False;
end;

function XmlMaxCharForEncoding(Enc: TXmlEncoding): Cardinal;
begin
  case Enc of
    xeLatin1: Result := $FF;
    xeAscii: Result := $7F;
  else
    Result := $10FFFF;
  end;
end;

function XmlDetectBom(const Buf: TBytes; Count: Integer; out Enc: TXmlEncoding;
  out BomLen: Integer): Boolean;
begin
  Result := True;
  BomLen := 0;
  Enc := xeUtf8;
  if (Count >= 3) and (Buf[0] = $EF) and (Buf[1] = $BB) and (Buf[2] = $BF) then
  begin
    Enc := xeUtf8;
    BomLen := 3;
  end
  else if (Count >= 2) and (Buf[0] = $FF) and (Buf[1] = $FE) then
  begin
    Enc := xeUtf16LE;
    BomLen := 2;
  end
  else if (Count >= 2) and (Buf[0] = $FE) and (Buf[1] = $FF) then
  begin
    Enc := xeUtf16BE;
    BomLen := 2;
  end
  else
    Result := False;
end;

function ScanDeclaredEncoding(const Buf: TBytes; Count: Integer): XmlString;
var
  I, N, Q: Integer;
  Quote: Byte;
begin
  Result := '';
  N := Count;
  if N > 512 then N := 512;
  if (N < 6) or (Buf[0] <> 60) or (Buf[1] <> 63) or (Buf[2] <> 120) or (Buf[3] <> 109) or
     (Buf[4] <> 108) then Exit;
  I := 5;
  while I < N - 1 do
  begin
    if (Buf[I] = 63) and (Buf[I + 1] = 62) then Exit;
    if (I + 8 < N) and (Buf[I] = 101) and (Buf[I + 1] = 110) and (Buf[I + 2] = 99) and
       (Buf[I + 3] = 111) and (Buf[I + 4] = 100) and (Buf[I + 5] = 105) and
       (Buf[I + 6] = 110) and (Buf[I + 7] = 103) then
    begin
      Q := I + 8;
      while (Q < N) and ((Buf[Q] = 32) or (Buf[Q] = 9) or (Buf[Q] = 10) or (Buf[Q] = 13)) do Inc(Q);
      if (Q < N) and (Buf[Q] = 61) then
      begin
        Inc(Q);
        while (Q < N) and ((Buf[Q] = 32) or (Buf[Q] = 9) or (Buf[Q] = 10) or (Buf[Q] = 13)) do Inc(Q);
        if (Q < N) and ((Buf[Q] = 34) or (Buf[Q] = 39)) then
        begin
          Quote := Buf[Q];
          Inc(Q);
          while (Q < N) and (Buf[Q] <> Quote) do
          begin
            Result := Result + WideChar(Buf[Q]);
            Inc(Q);
          end;
          Exit;
        end;
      end;
    end;
    Inc(I);
  end;
end;

function XmlDetectEncoding(const Buf: TBytes; Count: Integer; out BomLen: Integer;
  out DeclaredName: XmlString): TXmlEncoding;
var
  Enc: TXmlEncoding;
begin
  DeclaredName := '';
  if XmlDetectBom(Buf, Count, Result, BomLen) then Exit;
  BomLen := 0;
  if Count >= 2 then
  begin
    // '<' as UTF-16 without BOM (NUL is never valid at this position in UTF-8)
    if (Buf[0] = $3C) and (Buf[1] = 0) then
    begin
      Result := xeUtf16LE;
      Exit;
    end;
    if (Buf[0] = 0) and (Buf[1] = $3C) then
    begin
      Result := xeUtf16BE;
      Exit;
    end;
  end;
  DeclaredName := ScanDeclaredEncoding(Buf, Count);
  Result := xeUtf8;
  if DeclaredName <> '' then
  begin
    if not XmlEncodingFromName(DeclaredName, Enc) then
      raise EXmlEncodingException.CreateCode(XFE_ENC_UNSUPPORTED,
        'Unsupported encoding "' + DeclaredName + '" (supported: UTF-8, UTF-16, ISO-8859-1, US-ASCII)');
    // A declared UTF-16 without BOM/pattern cannot be honoured for ASCII-looking bytes.
    if (Enc <> xeUtf16LE) and (Enc <> xeUtf16BE) then Result := Enc;
  end;
end;

function XmlDecodeBytes(Enc: TXmlEncoding; const Src: TBytes; SrcStart, SrcCount: Integer;
  var Dst: TWideCharArray; DstStart: Integer; out Consumed: Integer; Final: Boolean): Integer;
var
  I, IEnd, O, Need, K: Integer;
  B, B2: Byte;
  CP, MinCP: Cardinal;
  W: Word;
begin
  I := SrcStart;
  IEnd := SrcStart + SrcCount;
  O := DstStart;
  case Enc of
    xeUtf8:
      while I < IEnd do
      begin
        B := Src[I];
        if B < $80 then
        begin
          Dst[O] := WideChar(B);
          Inc(O);
          Inc(I);
          Continue;
        end;
        if (B and $E0) = $C0 then begin Need := 1; CP := B and $1F; MinCP := $80; end
        else if (B and $F0) = $E0 then begin Need := 2; CP := B and $0F; MinCP := $800; end
        else if (B and $F8) = $F0 then begin Need := 3; CP := B and $07; MinCP := $10000; end
        else
          raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID,
            'Invalid UTF-8 lead byte at offset ' + IntToStr(I));
        if I + Need > IEnd - 1 then
        begin
          if Final then
            raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID, 'Truncated UTF-8 sequence at end of input');
          Break;
        end;
        for K := 1 to Need do
        begin
          B2 := Src[I + K];
          if (B2 and $C0) <> $80 then
            raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID,
              'Invalid UTF-8 continuation byte at offset ' + IntToStr(I + K));
          CP := (CP shl 6) or (B2 and $3F);
        end;
        if (CP < MinCP) or (CP > $10FFFF) or ((CP >= $D800) and (CP <= $DFFF)) then
          raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID,
            'Invalid UTF-8 code point at offset ' + IntToStr(I));
        if CP >= $10000 then
        begin
          Dec(CP, $10000);
          Dst[O] := WideChar($D800 + (CP shr 10));
          Dst[O + 1] := WideChar($DC00 + (CP and $3FF));
          Inc(O, 2);
        end
        else
        begin
          Dst[O] := WideChar(CP);
          Inc(O);
        end;
        Inc(I, Need + 1);
      end;
    xeUtf16LE, xeUtf16BE:
      begin
        while I + 1 < IEnd do
        begin
          if Enc = xeUtf16LE then
            W := Src[I] or (Word(Src[I + 1]) shl 8)
          else
            W := Src[I + 1] or (Word(Src[I]) shl 8);
          Dst[O] := WideChar(W);
          Inc(O);
          Inc(I, 2);
        end;
        if Final and (I < IEnd) then
          raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID, 'Odd number of bytes in UTF-16 input');
      end;
    xeLatin1:
      while I < IEnd do
      begin
        Dst[O] := WideChar(Src[I]);
        Inc(O);
        Inc(I);
      end;
    xeAscii:
      while I < IEnd do
      begin
        if Src[I] > $7F then
          raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID,
            'Non-ASCII byte in US-ASCII input at offset ' + IntToStr(I));
        Dst[O] := WideChar(Src[I]);
        Inc(O);
        Inc(I);
      end;
  end;
  Consumed := I - SrcStart;
  Result := O - DstStart;
end;

procedure XmlEncodeAppend(const S: XmlString; Enc: TXmlEncoding; var Dest: TBytes;
  var DestLen: Integer);
var
  I, N: Integer;
  C, C2: Cardinal;
  Limit: Cardinal;
begin
  N := System.Length(S);
  if N = 0 then Exit;
  if DestLen + N * 3 + 4 > System.Length(Dest) then
    SetLength(Dest, (DestLen + N * 3 + 4) * 2);
  I := 1;
  Limit := XmlMaxCharForEncoding(Enc);
  while I <= N do
  begin
    C := Ord(S[I]);
    Inc(I);
    case Enc of
      xeUtf8:
        begin
          if (C >= $D800) and (C <= $DBFF) then
          begin
            if I <= N then C2 := Ord(S[I]) else C2 := 0;
            if (C2 < $DC00) or (C2 > $DFFF) then
              raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID, 'Unpaired high surrogate in text');
            Inc(I);
            C := $10000 + ((C - $D800) shl 10) + (C2 - $DC00);
          end
          else if (C >= $DC00) and (C <= $DFFF) then
            raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID, 'Unpaired low surrogate in text');
          if C < $80 then
          begin
            Dest[DestLen] := Byte(C);
            Inc(DestLen);
          end
          else if C < $800 then
          begin
            Dest[DestLen] := Byte($C0 or (C shr 6));
            Dest[DestLen + 1] := Byte($80 or (C and $3F));
            Inc(DestLen, 2);
          end
          else if C < $10000 then
          begin
            Dest[DestLen] := Byte($E0 or (C shr 12));
            Dest[DestLen + 1] := Byte($80 or ((C shr 6) and $3F));
            Dest[DestLen + 2] := Byte($80 or (C and $3F));
            Inc(DestLen, 3);
          end
          else
          begin
            Dest[DestLen] := Byte($F0 or (C shr 18));
            Dest[DestLen + 1] := Byte($80 or ((C shr 12) and $3F));
            Dest[DestLen + 2] := Byte($80 or ((C shr 6) and $3F));
            Dest[DestLen + 3] := Byte($80 or (C and $3F));
            Inc(DestLen, 4);
          end;
        end;
      xeUtf16LE:
        begin
          Dest[DestLen] := Byte(C and $FF);
          Dest[DestLen + 1] := Byte(C shr 8);
          Inc(DestLen, 2);
        end;
      xeUtf16BE:
        begin
          Dest[DestLen] := Byte(C shr 8);
          Dest[DestLen + 1] := Byte(C and $FF);
          Inc(DestLen, 2);
        end;
      xeLatin1, xeAscii:
        begin
          if C > Limit then
            raise EXmlEncodingException.CreateCode(XFE_ENC_INVALID,
              'Character U+' + IntToHex(C, 4) + ' cannot be represented in ' + XmlEncodingName(Enc));
          Dest[DestLen] := Byte(C);
          Inc(DestLen);
        end;
    end;
  end;
end;

function XmlUtf8Encode(const S: XmlString): TBytes;
var
  Len: Integer;
begin
  SetLength(Result, System.Length(S) * 3 + 4);
  Len := 0;
  XmlEncodeAppend(S, xeUtf8, Result, Len);
  SetLength(Result, Len);
end;

function XmlUtf8Decode(const B: TBytes): XmlString;
var
  Dst: TWideCharArray;
  Consumed, Produced: Integer;
begin
  if System.Length(B) = 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Dst, System.Length(B) + 2);
  Produced := XmlDecodeBytes(xeUtf8, B, 0, System.Length(B), Dst, 0, Consumed, True);
  SetString(Result, PWideChar(@Dst[0]), Produced);
end;

end.
