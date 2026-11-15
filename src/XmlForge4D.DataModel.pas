{$I XmlForge4D.inc}
unit XmlForge4D.DataModel;

{ Universal Data Model (UDM).
  A serialization-neutral, ordered value tree (null, boolean, number, string,
  array, object). XML/JSON/YAML/... serializers and parsers map to and from
  this model. XML-specific information (node kinds, namespaces, ordering of
  mixed content) lives in the DOM and is mapped onto UDM by the conversion
  layer, either with the Standard rules or with the lossless XML Infoset
  JSON schema. Object members keep insertion order and may repeat names. }

interface

uses
  SysUtils, Classes, XmlForge4D.Types;

type
  TDataKind = (dkNull, dkBoolean, dkNumber, dkString, dkArray, dkObject);

  TDataNode = class
  private
    FKind: TDataKind;
    FText: XmlString;     // string value, or the literal text of a number
    FBool: Boolean;
    FItems: array of TDataNode;
    FNames: array of XmlString;
    FCount: Integer;
    function GetItem(Index: Integer): TDataNode;
    function GetName(Index: Integer): XmlString;
    procedure Grow;
  public
    constructor Create(AKind: TDataKind = dkNull);
    destructor Destroy; override;

    class function NewNull: TDataNode;
    class function NewBoolean(Value: Boolean): TDataNode;
    { Number is stored as its literal text (must be valid JSON number syntax). }
    class function NewNumber(const LiteralText: XmlString): TDataNode;
    class function NewString(const Value: XmlString): TDataNode;
    class function NewArray: TDataNode;
    class function NewObject: TDataNode;

    property Kind: TDataKind read FKind;
    function IsScalar: Boolean;
    function IsContainer: Boolean;

    { scalars }
    property BoolValue: Boolean read FBool;
    property TextValue: XmlString read FText;
    { Text form of a scalar ('' for null/containers). }
    function AsString: XmlString;
    function AsDouble: Double;

    { containers: element count (array) or member count (object) }
    property Count: Integer read FCount;
    property Items[Index: Integer]: TDataNode read GetItem; default;
    property Names[Index: Integer]: XmlString read GetName;

    { array }
    function Add(Item: TDataNode): TDataNode;
    { object }
    function AddMember(const Name: XmlString; Value: TDataNode): TDataNode;
    function InsertMember(Index: Integer; const Name: XmlString; Value: TDataNode): TDataNode;
    function IndexOfMember(const Name: XmlString): Integer;
    function FindMember(const Name: XmlString): TDataNode;
    { Replaces the value of member Index (frees the old one) / detaches it. }
    procedure SetItem(Index: Integer; Value: TDataNode);
    { Replaces item Index by an array that contains the old value. }
    procedure WrapItemInArray(Index: Integer);

    function Clone: TDataNode;
    function SameAs(Other: TDataNode): Boolean;
  end;

function JsonNumberIsValid(const S: XmlString): Boolean;

implementation

function JsonNumberIsValid(const S: XmlString): Boolean;
var
  I, N: Integer;
begin
  Result := False;
  N := System.Length(S);
  I := 1;
  if (I <= N) and (S[I] = '-') then Inc(I);
  if I > N then Exit;
  if S[I] = '0' then
    Inc(I)
  else if (S[I] >= '1') and (S[I] <= '9') then
  begin
    while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do Inc(I);
  end
  else
    Exit;
  if (I <= N) and (S[I] = '.') then
  begin
    Inc(I);
    if (I > N) or (S[I] < '0') or (S[I] > '9') then Exit;
    while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do Inc(I);
  end;
  if (I <= N) and ((S[I] = 'e') or (S[I] = 'E')) then
  begin
    Inc(I);
    if (I <= N) and ((S[I] = '+') or (S[I] = '-')) then Inc(I);
    if (I > N) or (S[I] < '0') or (S[I] > '9') then Exit;
    while (I <= N) and (S[I] >= '0') and (S[I] <= '9') do Inc(I);
  end;
  Result := I > N;
end;

{ TDataNode }

constructor TDataNode.Create(AKind: TDataKind);
begin
  inherited Create;
  FKind := AKind;
end;

destructor TDataNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do FItems[I].Free;
  inherited Destroy;
end;

class function TDataNode.NewNull: TDataNode;
begin
  Result := TDataNode.Create(dkNull);
end;

class function TDataNode.NewBoolean(Value: Boolean): TDataNode;
begin
  Result := TDataNode.Create(dkBoolean);
  Result.FBool := Value;
end;

class function TDataNode.NewNumber(const LiteralText: XmlString): TDataNode;
begin
  if not JsonNumberIsValid(LiteralText) then
    raise EXmlConversionException.CreateCode(XFE_CONV_GENERIC, 'Invalid number literal "' + LiteralText + '"');
  Result := TDataNode.Create(dkNumber);
  Result.FText := LiteralText;
end;

class function TDataNode.NewString(const Value: XmlString): TDataNode;
begin
  Result := TDataNode.Create(dkString);
  Result.FText := Value;
end;

class function TDataNode.NewArray: TDataNode;
begin
  Result := TDataNode.Create(dkArray);
end;

class function TDataNode.NewObject: TDataNode;
begin
  Result := TDataNode.Create(dkObject);
end;

function TDataNode.IsScalar: Boolean;
begin
  Result := FKind in [dkNull, dkBoolean, dkNumber, dkString];
end;

function TDataNode.IsContainer: Boolean;
begin
  Result := FKind in [dkArray, dkObject];
end;

function TDataNode.AsString: XmlString;
begin
  case FKind of
    dkBoolean: if FBool then Result := 'true' else Result := 'false';
    dkNumber, dkString: Result := FText;
  else
    Result := '';
  end;
end;

function TDataNode.AsDouble: Double;
begin
  if (FKind <> dkNumber) or (not XmlTryParseFloat(FText, Result)) then Result := 0;
end;

function TDataNode.GetItem(Index: Integer): TDataNode;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'Data node index out of range: ' + IntToStr(Index));
  Result := FItems[Index];
end;

function TDataNode.GetName(Index: Integer): XmlString;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'Data node index out of range: ' + IntToStr(Index));
  if FKind = dkObject then Result := FNames[Index] else Result := '';
end;

procedure TDataNode.Grow;
begin
  if FCount >= System.Length(FItems) then
  begin
    SetLength(FItems, FCount * 2 + 4);
    SetLength(FNames, FCount * 2 + 4);
  end;
end;

function TDataNode.Add(Item: TDataNode): TDataNode;
begin
  if FKind <> dkArray then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'Add is only valid on arrays');
  Grow;
  FItems[FCount] := Item;
  FNames[FCount] := '';
  Inc(FCount);
  Result := Item;
end;

function TDataNode.AddMember(const Name: XmlString; Value: TDataNode): TDataNode;
begin
  Result := InsertMember(FCount, Name, Value);
end;

function TDataNode.InsertMember(Index: Integer; const Name: XmlString; Value: TDataNode): TDataNode;
var
  I: Integer;
begin
  if FKind <> dkObject then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'AddMember is only valid on objects');
  if (Index < 0) or (Index > FCount) then Index := FCount;
  Grow;
  for I := FCount downto Index + 1 do
  begin
    FItems[I] := FItems[I - 1];
    FNames[I] := FNames[I - 1];
  end;
  FItems[Index] := Value;
  FNames[Index] := Name;
  Inc(FCount);
  Result := Value;
end;

function TDataNode.IndexOfMember(const Name: XmlString): Integer;
var
  I: Integer;
begin
  if FKind = dkObject then
    for I := 0 to FCount - 1 do
      if FNames[I] = Name then
      begin
        Result := I;
        Exit;
      end;
  Result := -1;
end;

function TDataNode.FindMember(const Name: XmlString): TDataNode;
var
  I: Integer;
begin
  I := IndexOfMember(Name);
  if I >= 0 then Result := FItems[I] else Result := nil;
end;

procedure TDataNode.SetItem(Index: Integer; Value: TDataNode);
begin
  if (Index < 0) or (Index >= FCount) then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'Data node index out of range: ' + IntToStr(Index));
  if FItems[Index] <> Value then
  begin
    FItems[Index].Free;
    FItems[Index] := Value;
  end;
end;

procedure TDataNode.WrapItemInArray(Index: Integer);
var
  Arr: TDataNode;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EXmlForgeException.CreateCode(XFE_UNKNOWN, 'Data node index out of range: ' + IntToStr(Index));
  Arr := TDataNode.NewArray;
  Arr.Add(FItems[Index]);
  FItems[Index] := Arr;
end;

function TDataNode.Clone: TDataNode;
var
  I: Integer;
begin
  Result := TDataNode.Create(FKind);
  Result.FText := FText;
  Result.FBool := FBool;
  for I := 0 to FCount - 1 do
  begin
    if FKind = dkObject then
      Result.AddMember(FNames[I], FItems[I].Clone)
    else
      Result.Add(FItems[I].Clone);
  end;
end;

function TDataNode.SameAs(Other: TDataNode): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Other = nil) or (Other.FKind <> FKind) then Exit;
  case FKind of
    dkNull: Result := True;
    dkBoolean: Result := FBool = Other.FBool;
    dkNumber, dkString: Result := FText = Other.FText;
  else
    begin
      if FCount <> Other.FCount then Exit;
      for I := 0 to FCount - 1 do
      begin
        if (FKind = dkObject) and (FNames[I] <> Other.FNames[I]) then Exit;
        if not FItems[I].SameAs(Other.FItems[I]) then Exit;
      end;
      Result := True;
    end;
  end;
end;

end.
