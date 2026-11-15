{$I XmlForge4D.inc}
unit XmlForge4D.Schema;

{ XML Schema (XSD 1.0) validation - documented subset.

  SUPPORTED
    schema: targetNamespace, elementFormDefault/attributeFormDefault, global
      elements/attributes/types/groups/attributeGroups, named + anonymous types,
      element ref / group ref / attributeGroup ref, schemas assembled from several
      documents via AddSchemaDocument
    particles: sequence, choice, all, any (accepted unvalidated), minOccurs/maxOccurs,
      unbounded
    complex types: element content, mixed, empty, simpleContent (extension/restriction),
      complexContent extension (restriction is treated as a fresh definition), attributes
      (use required/optional/prohibited, default/fixed), anyAttribute, nillable + xsi:nil
    simple types: restriction with enumeration, length, minLength, maxLength,
      minInclusive, maxInclusive, minExclusive, maxExclusive, whiteSpace; the usual
      built-in types (string family, boolean, decimal/integer family, float, double,
      date, dateTime, time, gYear, duration, anyURI, base64Binary, hexBinary, NCName,
      Name, ID, IDREF, language, QName)
    namespaces: element/attribute names are matched by namespace URI + local name

  NOT SUPPORTED (reported in TXsdSchema.Warnings, ignored during validation)
    pattern facet, totalDigits/fractionDigits, list/union simple types, xsi:type,
    substitution groups, key/keyref/unique, ID uniqueness / IDREF resolution,
    import/include/redefine loading (no network or file access is ever performed by the
    schema loader; pass the documents yourself with AddSchemaDocument), XSD 1.1.

  Type names are matched by local name only (prefixes are used to tell XSD built-ins
  from user types). }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Parser, XmlForge4D.Dom;

type
  TXsdBuiltin = (xbAnyType, xbAnySimple, xbString, xbNormalizedString, xbToken, xbBoolean,
    xbDecimal, xbInteger, xbLong, xbInt, xbShort, xbByte, xbNonNegativeInteger,
    xbPositiveInteger, xbNonPositiveInteger, xbNegativeInteger, xbUnsignedLong, xbUnsignedInt,
    xbUnsignedShort, xbUnsignedByte, xbFloat, xbDouble, xbDate, xbDateTime, xbTime, xbGYear,
    xbDuration, xbAnyUri, xbBase64, xbHexBinary, xbNCName, xbName, xbID, xbIDREF, xbLanguage,
    xbQName);

  TXsdSimpleType = class
  public
    Name, BaseName: XmlString;
    BaseIsXsd: Boolean;
    Base: TXsdSimpleType;
    IsBuiltin: Boolean;
    Builtin: TXsdBuiltin;
    Enums: array of XmlString;
    LengthFacet, MinLength, MaxLength: Integer;
    MinInc, MaxInc, MinExc, MaxExc: XmlString;
    HasMinInc, HasMaxInc, HasMinExc, HasMaxExc: Boolean;
    WhiteSpace: XmlString;
    constructor Create;
  end;

  TXsdComplexType = class;
  TXsdParticle = class;

  TXsdAttribute = class
  public
    Name, Uri: XmlString;
    TypeName: XmlString;
    TypeIsXsd: Boolean;
    InlineT: TXsdSimpleType;
    Required, Prohibited, HasFixed, HasDefault: Boolean;
    Fixed, DefaultValue: XmlString;
    RefName: XmlString;
  end;

  TXsdElementDecl = class
  public
    Name, Uri: XmlString;
    RefName: XmlString;
    TypeName: XmlString;
    TypeIsXsd: Boolean;
    InlineSimple: TXsdSimpleType;
    InlineComplex: TXsdComplexType;
    Nillable, HasFixed: Boolean;
    Fixed: XmlString;
  end;

  TXsdParticleKind = (pkElement, pkSequence, pkChoice, pkAll, pkAny, pkGroupRef);

  TXsdParticle = class
  public
    Kind: TXsdParticleKind;
    MinOccurs, MaxOccurs: Integer; // MaxOccurs -1 = unbounded
    Elem: TXsdElementDecl;
    Children: array of TXsdParticle;
    GroupName: XmlString;
    constructor Create;
  end;

  TXsdComplexType = class
  public
    Name: XmlString;
    Mixed: Boolean;
    Content: TXsdParticle;
    EffContent: TXsdParticle;
    Finalized, Finalizing: Boolean;
    Attrs: array of TXsdAttribute;
    AttrGroupRefs: array of XmlString;
    AnyAttribute: Boolean;
    HasSimpleContent: Boolean;
    SimpleBaseName: XmlString;
    SimpleBaseIsXsd: Boolean;
    SimpleRestriction: TXsdSimpleType; // facets applied on top of the simple base
    BaseName: XmlString;
    IsExtension: Boolean;
  end;

  TXsdNamedGroup = record
    Name: XmlString;
    Particle: TXsdParticle;
  end;

  TXsdNamedAttrGroup = record
    Name: XmlString;
    Attrs: array of TXsdAttribute;
    Refs: array of XmlString;
    AnyAttribute: Boolean;
  end;

  TXsdSchema = class
  private
    FObjs: array of TObject;
    FObjCount: Integer;
    FTargetNs: XmlString;
    FWarnings: TStringList;
    FSimple: array of TXsdSimpleType;
    FComplex: array of TXsdComplexType;
    FGroups: array of TXsdNamedGroup;
    FAttrGroups: array of TXsdNamedAttrGroup;
    FElements: array of TXsdElementDecl;
    FAttributes: array of TXsdAttribute;
    FBuiltinCache: array[TXsdBuiltin] of TXsdSimpleType;
    function Own(O: TObject): TObject;
    function NewSimple: TXsdSimpleType;
    procedure Warn(const Msg: XmlString);
    function ResolveTypeName(E: TXmlElement; const QName: XmlString; out IsXsd: Boolean): XmlString;
    procedure ParseRestrictionInto(R: TXmlElement; ST: TXsdSimpleType);
    function ParseSimpleType(E: TXmlElement; const AName: XmlString): TXsdSimpleType;
    function ParseComplexType(E: TXmlElement; const AName: XmlString; const Ctx: TObject): TXsdComplexType;
    function ParseElement(E: TXmlElement; Global, Qualified: Boolean; const TargetNs: XmlString): TXsdElementDecl;
    function ParseAttribute(E: TXmlElement; Global, Qualified: Boolean; const TargetNs: XmlString): TXsdAttribute;
    function ParseModelGroup(E: TXmlElement; Qualified: Boolean; const TargetNs: XmlString): TXsdParticle;
    function ParseOccurs(E: TXmlElement; const AttrName: XmlString; DefaultValue: Integer): Integer;
    procedure ParseAttributeChildren(E: TXmlElement; Attrs: TList; Refs: TStrings; var AnyAttr: Boolean;
      Qualified: Boolean; const TargetNs: XmlString);
  public
    constructor Create;
    destructor Destroy; override;
    class function LoadFromFile(const FileName: string): TXsdSchema;
    class function LoadFromString(const Xsd: XmlString): TXsdSchema;
    { Adds the declarations of one schema document (may be called several times). }
    procedure AddSchemaDocument(Doc: TXmlDocument);

    function FindGlobalElement(const Uri, Local: XmlString): TXsdElementDecl;
    function FindGlobalAttribute(const Local: XmlString): TXsdAttribute;
    function FindSimple(const Name: XmlString; IsXsd: Boolean): TXsdSimpleType;
    function FindComplex(const Name: XmlString): TXsdComplexType;
    function FindGroup(const Name: XmlString): TXsdParticle;
    function BuiltinType(B: TXsdBuiltin): TXsdSimpleType;
    function FinalizeComplex(CT: TXsdComplexType): TXsdParticle;
    procedure GatherAttributes(CT: TXsdComplexType; Attrs: TList; var AnyAttr: Boolean);
    function GroupAttributes(const Name: XmlString; Attrs: TList; var AnyAttr: Boolean; Depth: Integer): Boolean;
    function OwnParticle(P: TXsdParticle): TXsdParticle;

    property TargetNamespace: XmlString read FTargetNs;
    { Unsupported constructs found while loading. }
    property Warnings: TStringList read FWarnings;
  end;

  TXmlValidationError = record
    Code: Integer;
    Message: XmlString;
    Line, Column: Integer;
    Path: XmlString;
  end;

  TXmlValidator = class
  private
    FSchema: TXsdSchema;
    FErrors: array of TXmlValidationError;
    FErrorCount: Integer;
    FKids: array of TXmlElement;
    FKidCount: Integer;
    FAssigned: array of TXsdElementDecl;
    FFailPos: Integer;
    FExpected: XmlString;
    function GetError(Index: Integer): TXmlValidationError;
    procedure AddError(Node: TXmlNode; const Msg: XmlString);
    function PathOf(Node: TXmlNode): XmlString;
    function ResolveDecl(D: TXsdElementDecl): TXsdElementDecl;
    function ElementMatches(D: TXsdElementDecl; E: TXmlElement): Boolean;
    procedure ValidateElement(E: TXmlElement; Decl: TXsdElementDecl);
    procedure ValidateComplex(E: TXmlElement; CT: TXsdComplexType);
    procedure ValidateAttributes(E: TXmlElement; CT: TXsdComplexType);
    procedure ValidateSimpleValue(Node: TXmlNode; const Value: XmlString; ST: TXsdSimpleType;
      const What: XmlString);
    function MatchOnce(P: TXsdParticle; var Pos: Integer): Boolean;
    function MatchP(P: TXsdParticle; var Pos: Integer): Boolean;
    procedure NoteExpected(D: TXsdElementDecl; At: Integer);
    function SimpleFor(const TypeName: XmlString; IsXsd: Boolean; InlineT: TXsdSimpleType): TXsdSimpleType;
  public
    constructor Create(ASchema: TXsdSchema);
    { Returns True when the document is valid; problems are collected in Errors. }
    function Validate(Doc: TXmlDocument): Boolean;
    { Raises EXmlValidationException (first error, with line/column) when invalid. }
    procedure ValidateOrRaise(Doc: TXmlDocument);
    procedure Clear;
    property ErrorCount: Integer read FErrorCount;
    property Errors[Index: Integer]: TXmlValidationError read GetError;
    function ErrorsAsText: XmlString;
  end;

implementation

const
  BuiltinNames: array[TXsdBuiltin] of string = ('anyType', 'anySimpleType', 'string',
    'normalizedString', 'token', 'boolean', 'decimal', 'integer', 'long', 'int', 'short', 'byte',
    'nonNegativeInteger', 'positiveInteger', 'nonPositiveInteger', 'negativeInteger',
    'unsignedLong', 'unsignedInt', 'unsignedShort', 'unsignedByte', 'float', 'double', 'date',
    'dateTime', 'time', 'gYear', 'duration', 'anyURI', 'base64Binary', 'hexBinary', 'NCName',
    'Name', 'ID', 'IDREF', 'language', 'QName');

function BuiltinFromName(const N: XmlString; out B: TXsdBuiltin): Boolean;
var
  X: TXsdBuiltin;
begin
  for X := Low(TXsdBuiltin) to High(TXsdBuiltin) do
    if BuiltinNames[X] = N then
    begin
      B := X;
      Result := True;
      Exit;
    end;
  // a few common aliases that behave like string for validation purposes
  if (N = 'NMTOKEN') or (N = 'IDREFS') or (N = 'NMTOKENS') or (N = 'ENTITY') or (N = 'NOTATION') or
     (N = 'gYearMonth') or (N = 'gMonth') or (N = 'gMonthDay') or (N = 'gDay') then
  begin
    B := xbString;
    Result := True;
    Exit;
  end;
  Result := False;
end;

{ ---------------- small classes ---------------- }

constructor TXsdSimpleType.Create;
begin
  inherited Create;
  LengthFacet := -1;
  MinLength := -1;
  MaxLength := -1;
end;

constructor TXsdParticle.Create;
begin
  inherited Create;
  MinOccurs := 1;
  MaxOccurs := 1;
end;

{ ---------------- loader ---------------- }

constructor TXsdSchema.Create;
begin
  inherited Create;
  FWarnings := TStringList.Create;
end;

destructor TXsdSchema.Destroy;
var
  I: Integer;
begin
  for I := FObjCount - 1 downto 0 do FObjs[I].Free;
  FWarnings.Free;
  inherited Destroy;
end;

function TXsdSchema.Own(O: TObject): TObject;
begin
  if FObjCount >= System.Length(FObjs) then SetLength(FObjs, FObjCount * 2 + 16);
  FObjs[FObjCount] := O;
  Inc(FObjCount);
  Result := O;
end;

function TXsdSchema.OwnParticle(P: TXsdParticle): TXsdParticle;
begin
  Result := TXsdParticle(Own(P));
end;

function TXsdSchema.NewSimple: TXsdSimpleType;
begin
  Result := TXsdSimpleType(Own(TXsdSimpleType.Create));
end;

procedure TXsdSchema.Warn(const Msg: XmlString);
begin
  if FWarnings.IndexOf(Msg) < 0 then FWarnings.Add(Msg);
end;

class function TXsdSchema.LoadFromFile(const FileName: string): TXsdSchema;
var
  D: TXmlDocument;
begin
  D := TXmlDocument.LoadFromFile(FileName);
  try
    Result := TXsdSchema.Create;
    try
      Result.AddSchemaDocument(D);
    except
      Result.Free;
      raise;
    end;
  finally
    D.Free;
  end;
end;

class function TXsdSchema.LoadFromString(const Xsd: XmlString): TXsdSchema;
var
  D: TXmlDocument;
begin
  D := TXmlDocument.LoadFromString(Xsd);
  try
    Result := TXsdSchema.Create;
    try
      Result.AddSchemaDocument(D);
    except
      Result.Free;
      raise;
    end;
  finally
    D.Free;
  end;
end;

function IsXsd(N: TXmlNode; const Local: XmlString): Boolean;
begin
  Result := (N.NodeType = ntElement) and (N.NamespaceURI = XSD_NS_URI) and (N.LocalName = Local);
end;

procedure SchemaError(const Msg: XmlString; Node: TXmlNode);
begin
  if Node <> nil then
    raise EXmlValidationException.CreateCode(XFE_VAL_SCHEMA, 'Invalid schema: ' + Msg, Node.Line, Node.Column)
  else
    raise EXmlValidationException.CreateCode(XFE_VAL_SCHEMA, 'Invalid schema: ' + Msg);
end;

function TXsdSchema.ResolveTypeName(E: TXmlElement; const QName: XmlString; out IsXsd: Boolean): XmlString;
var
  Pfx, Loc, Uri: XmlString;
begin
  IsXsd := False;
  if not XmlSplitQName(QName, Pfx, Loc) then
  begin
    Result := QName;
    Exit;
  end;
  Result := Loc;
  if E.LookupNamespaceURI(Pfx, Uri) then IsXsd := Uri = XSD_NS_URI;
end;

function TXsdSchema.ParseOccurs(E: TXmlElement; const AttrName: XmlString; DefaultValue: Integer): Integer;
var
  V: XmlString;
begin
  if not E.TryGetAttribute(AttrName, V) then
  begin
    Result := DefaultValue;
    Exit;
  end;
  V := XmlTrimWhite(Copy(V, 1, MaxInt));
  if V = 'unbounded' then Result := -1
  else
  begin
    Result := StrToIntDef(V, -2);
    if Result < 0 then SchemaError('invalid ' + AttrName + ' "' + V + '"', E);
  end;
end;

procedure TXsdSchema.ParseRestrictionInto(R: TXmlElement; ST: TXsdSimpleType);
var
  J: Integer;
  C: TXmlNode;
  V, F: XmlString;
begin
  if R.TryGetAttribute('base', V) then
    ST.BaseName := ResolveTypeName(R, V, ST.BaseIsXsd);
  for J := 0 to R.ChildCount - 1 do
  begin
    C := R.Children[J];
    if C.NodeType <> ntElement then Continue;
    if IsXsd(C, 'simpleType') then
      ST.Base := ParseSimpleType(TXmlElement(C), '')
    else if IsXsd(C, 'annotation') then
    begin
    end
    else if C.NamespaceURI = XSD_NS_URI then
    begin
      F := C.LocalName;
      V := TXmlElement(C).AttributeValue['value'];
      if F = 'enumeration' then
      begin
        SetLength(ST.Enums, System.Length(ST.Enums) + 1);
        ST.Enums[System.Length(ST.Enums) - 1] := V;
      end
      else if F = 'length' then ST.LengthFacet := StrToIntDef(V, -1)
      else if F = 'minLength' then ST.MinLength := StrToIntDef(V, -1)
      else if F = 'maxLength' then ST.MaxLength := StrToIntDef(V, -1)
      else if F = 'minInclusive' then begin ST.MinInc := V; ST.HasMinInc := True; end
      else if F = 'maxInclusive' then begin ST.MaxInc := V; ST.HasMaxInc := True; end
      else if F = 'minExclusive' then begin ST.MinExc := V; ST.HasMinExc := True; end
      else if F = 'maxExclusive' then begin ST.MaxExc := V; ST.HasMaxExc := True; end
      else if F = 'whiteSpace' then ST.WhiteSpace := V
      else Warn('facet "' + F + '" is not supported and is ignored');
    end;
  end;
end;

function TXsdSchema.ParseSimpleType(E: TXmlElement; const AName: XmlString): TXsdSimpleType;
var
  I: Integer;
  R: TXmlNode;
begin
  Result := NewSimple;
  Result.Name := AName;
  for I := 0 to E.ChildCount - 1 do
  begin
    R := E.Children[I];
    if IsXsd(R, 'list') or IsXsd(R, 'union') then
    begin
      Warn('simpleType ' + R.LocalName + ' is not supported (treated as xs:string)');
      Result.BaseName := 'string';
      Result.BaseIsXsd := True;
      Exit;
    end;
    if IsXsd(R, 'restriction') then ParseRestrictionInto(TXmlElement(R), Result);
  end;
end;

procedure TXsdSchema.ParseAttributeChildren(E: TXmlElement; Attrs: TList; Refs: TStrings;
  var AnyAttr: Boolean; Qualified: Boolean; const TargetNs: XmlString);
var
  I: Integer;
  C: TXmlNode;
  Pfx, Loc: XmlString;
begin
  for I := 0 to E.ChildCount - 1 do
  begin
    C := E.Children[I];
    if IsXsd(C, 'attribute') then
      Attrs.Add(ParseAttribute(TXmlElement(C), False, Qualified, TargetNs))
    else if IsXsd(C, 'attributeGroup') then
    begin
      XmlSplitQName(TXmlElement(C).AttributeValue['ref'], Pfx, Loc);
      Refs.Add(Loc);
    end
    else if IsXsd(C, 'anyAttribute') then
      AnyAttr := True;
  end;
end;

function TXsdSchema.ParseAttribute(E: TXmlElement; Global, Qualified: Boolean;
  const TargetNs: XmlString): TXsdAttribute;
var
  V, U: XmlString;
  C: TXmlElement;
  Pfx, Loc: XmlString;
begin
  Result := TXsdAttribute(Own(TXsdAttribute.Create));
  if E.TryGetAttribute('ref', V) then
  begin
    XmlSplitQName(V, Pfx, Loc);
    Result.RefName := Loc;
    Result.Name := Loc;
  end
  else
    Result.Name := E.AttributeValue['name'];
  if Global or (Qualified and (E.AttributeValue['form'] <> 'unqualified')) or
     (E.AttributeValue['form'] = 'qualified') then
    Result.Uri := TargetNs
  else
    Result.Uri := '';
  if E.TryGetAttribute('type', V) then
    Result.TypeName := ResolveTypeName(E, V, Result.TypeIsXsd);
  C := nil;
  if E.ChildCount > 0 then
    C := TXmlElement(E.FindChildElementNS(XSD_NS_URI, 'simpleType'));
  if C <> nil then Result.InlineT := ParseSimpleType(C, '');
  U := E.AttributeValue['use'];
  Result.Required := U = 'required';
  Result.Prohibited := U = 'prohibited';
  if E.TryGetAttribute('fixed', V) then begin Result.HasFixed := True; Result.Fixed := V; end;
  if E.TryGetAttribute('default', V) then begin Result.HasDefault := True; Result.DefaultValue := V; end;
end;

function TXsdSchema.ParseElement(E: TXmlElement; Global, Qualified: Boolean;
  const TargetNs: XmlString): TXsdElementDecl;
var
  V: XmlString;
  C: TXmlElement;
  Pfx, Loc: XmlString;
begin
  Result := TXsdElementDecl(Own(TXsdElementDecl.Create));
  if E.TryGetAttribute('ref', V) then
  begin
    XmlSplitQName(V, Pfx, Loc);
    Result.RefName := Loc;
    Result.Name := Loc;
    Exit;
  end;
  Result.Name := E.AttributeValue['name'];
  if Result.Name = '' then SchemaError('element without name or ref', E);
  if Global or (Qualified and (E.AttributeValue['form'] <> 'unqualified')) or
     (E.AttributeValue['form'] = 'qualified') then
    Result.Uri := TargetNs
  else
    Result.Uri := '';
  Result.Nillable := E.AttributeValue['nillable'] = 'true';
  if E.TryGetAttribute('fixed', V) then begin Result.HasFixed := True; Result.Fixed := V; end;
  if E.TryGetAttribute('type', V) then
    Result.TypeName := ResolveTypeName(E, V, Result.TypeIsXsd);
  C := E.FindChildElementNS(XSD_NS_URI, 'complexType');
  if C <> nil then Result.InlineComplex := ParseComplexType(C, '', nil);
  C := E.FindChildElementNS(XSD_NS_URI, 'simpleType');
  if C <> nil then Result.InlineSimple := ParseSimpleType(C, '');
  if E.FindChildElementNS(XSD_NS_URI, 'key') <> nil then Warn('xs:key is not supported');
  if E.FindChildElementNS(XSD_NS_URI, 'keyref') <> nil then Warn('xs:keyref is not supported');
  if E.FindChildElementNS(XSD_NS_URI, 'unique') <> nil then Warn('xs:unique is not supported');
  if E.HasAttribute('substitutionGroup') then Warn('substitutionGroup is not supported');
end;

function TXsdSchema.ParseModelGroup(E: TXmlElement; Qualified: Boolean; const TargetNs: XmlString): TXsdParticle;
var
  I: Integer;
  C: TXmlNode;
  P: TXsdParticle;
  Pfx, Loc: XmlString;
begin
  Result := TXsdParticle(Own(TXsdParticle.Create));
  if IsXsd(E, 'sequence') then Result.Kind := pkSequence
  else if IsXsd(E, 'choice') then Result.Kind := pkChoice
  else Result.Kind := pkAll;
  Result.MinOccurs := ParseOccurs(E, 'minOccurs', 1);
  Result.MaxOccurs := ParseOccurs(E, 'maxOccurs', 1);
  for I := 0 to E.ChildCount - 1 do
  begin
    C := E.Children[I];
    P := nil;
    if IsXsd(C, 'element') then
    begin
      P := TXsdParticle(Own(TXsdParticle.Create));
      P.Kind := pkElement;
      P.Elem := ParseElement(TXmlElement(C), False, Qualified, TargetNs);
      P.MinOccurs := ParseOccurs(TXmlElement(C), 'minOccurs', 1);
      P.MaxOccurs := ParseOccurs(TXmlElement(C), 'maxOccurs', 1);
    end
    else if IsXsd(C, 'sequence') or IsXsd(C, 'choice') or IsXsd(C, 'all') then
      P := ParseModelGroup(TXmlElement(C), Qualified, TargetNs)
    else if IsXsd(C, 'any') then
    begin
      P := TXsdParticle(Own(TXsdParticle.Create));
      P.Kind := pkAny;
      P.MinOccurs := ParseOccurs(TXmlElement(C), 'minOccurs', 1);
      P.MaxOccurs := ParseOccurs(TXmlElement(C), 'maxOccurs', 1);
    end
    else if IsXsd(C, 'group') then
    begin
      P := TXsdParticle(Own(TXsdParticle.Create));
      P.Kind := pkGroupRef;
      XmlSplitQName(TXmlElement(C).AttributeValue['ref'], Pfx, Loc);
      P.GroupName := Loc;
      P.MinOccurs := ParseOccurs(TXmlElement(C), 'minOccurs', 1);
      P.MaxOccurs := ParseOccurs(TXmlElement(C), 'maxOccurs', 1);
    end;
    if P <> nil then
    begin
      SetLength(Result.Children, System.Length(Result.Children) + 1);
      Result.Children[System.Length(Result.Children) - 1] := P;
    end;
  end;
end;

function TXsdSchema.ParseComplexType(E: TXmlElement; const AName: XmlString;
  const Ctx: TObject): TXsdComplexType;
var
  I, J, K: Integer;
  C, D: TXmlNode;
  Attrs: TList;
  Refs: TStringList;
  Qualified, QualAttr: Boolean;
  TargetNs, V, Pfx, Loc: XmlString;
  AnyAttr: Boolean;
  P: TXsdParticle;
  Deriv: TXmlElement;
begin
  Result := TXsdComplexType(Own(TXsdComplexType.Create));
  Result.Name := AName;
  Result.Mixed := E.AttributeValue['mixed'] = 'true';
  // schema-level defaults are looked up on the schema root element
  TargetNs := '';
  Qualified := False;
  QualAttr := False;
  C := E;
  while (C <> nil) and (C.ParentNode <> nil) and (C.ParentNode.NodeType <> ntDocument) do C := C.ParentNode;
  if (C <> nil) and (C.NodeType = ntElement) then
  begin
    TargetNs := TXmlElement(C).AttributeValue['targetNamespace'];
    Qualified := TXmlElement(C).AttributeValue['elementFormDefault'] = 'qualified';
    QualAttr := TXmlElement(C).AttributeValue['attributeFormDefault'] = 'qualified';
  end;
  Attrs := TList.Create;
  Refs := TStringList.Create;
  try
    AnyAttr := False;
    for I := 0 to E.ChildCount - 1 do
    begin
      C := E.Children[I];
      if IsXsd(C, 'sequence') or IsXsd(C, 'choice') or IsXsd(C, 'all') then
        Result.Content := ParseModelGroup(TXmlElement(C), Qualified, TargetNs)
      else if IsXsd(C, 'group') then
      begin
        P := TXsdParticle(Own(TXsdParticle.Create));
        P.Kind := pkGroupRef;
        XmlSplitQName(TXmlElement(C).AttributeValue['ref'], Pfx, Loc);
        P.GroupName := Loc;
        P.MinOccurs := ParseOccurs(TXmlElement(C), 'minOccurs', 1);
        P.MaxOccurs := ParseOccurs(TXmlElement(C), 'maxOccurs', 1);
        Result.Content := P;
      end
      else if IsXsd(C, 'simpleContent') or IsXsd(C, 'complexContent') then
      begin
        if IsXsd(C, 'simpleContent') then Result.HasSimpleContent := True;
        if IsXsd(C, 'complexContent') and (TXmlElement(C).AttributeValue['mixed'] = 'true') then
          Result.Mixed := True;
        for J := 0 to C.ChildCount - 1 do
        begin
          D := C.Children[J];
          if not (IsXsd(D, 'extension') or IsXsd(D, 'restriction')) then Continue;
          Deriv := TXmlElement(D);
          V := Deriv.AttributeValue['base'];
          if Result.HasSimpleContent then
          begin
            Result.SimpleBaseName := ResolveTypeName(Deriv, V, Result.SimpleBaseIsXsd);
            if IsXsd(D, 'restriction') then
            begin
              Result.SimpleRestriction := NewSimple;
              ParseRestrictionInto(Deriv, Result.SimpleRestriction);
              Result.SimpleRestriction.BaseName := '';
            end;
          end
          else if IsXsd(D, 'extension') then
          begin
            Result.BaseName := ResolveTypeName(Deriv, V, Result.SimpleBaseIsXsd);
            Result.IsExtension := True;
          end;
          for K := 0 to Deriv.ChildCount - 1 do
          begin
            if IsXsd(Deriv.Children[K], 'sequence') or IsXsd(Deriv.Children[K], 'choice') or
               IsXsd(Deriv.Children[K], 'all') then
              Result.Content := ParseModelGroup(TXmlElement(Deriv.Children[K]), Qualified, TargetNs);
          end;
          ParseAttributeChildren(Deriv, Attrs, Refs, AnyAttr, QualAttr, TargetNs);
        end;
      end;
    end;
    ParseAttributeChildren(E, Attrs, Refs, AnyAttr, QualAttr, TargetNs);
    SetLength(Result.Attrs, Attrs.Count);
    for I := 0 to Attrs.Count - 1 do Result.Attrs[I] := TXsdAttribute(Attrs[I]);
    SetLength(Result.AttrGroupRefs, Refs.Count);
    for I := 0 to Refs.Count - 1 do Result.AttrGroupRefs[I] := Refs[I];
    Result.AnyAttribute := AnyAttr;
  finally
    Attrs.Free;
    Refs.Free;
  end;
end;

procedure TXsdSchema.AddSchemaDocument(Doc: TXmlDocument);
var
  Root: TXmlElement;
  I, J: Integer;
  C: TXmlNode;
  Qualified, QualAttr: Boolean;
  Ns, Nm, Pfx, Loc: XmlString;
  Attrs: TList;
  Refs: TStringList;
  AnyAttr: Boolean;
  CT: TXsdComplexType;
  G: TXmlElement;
begin
  Root := Doc.DocumentElement;
  if (Root = nil) or (not IsXsd(Root, 'schema')) then
    SchemaError('the root element must be xs:schema in the namespace ' + XSD_NS_URI, Root);
  Ns := Root.AttributeValue['targetNamespace'];
  if FTargetNs = '' then FTargetNs := Ns;
  Qualified := Root.AttributeValue['elementFormDefault'] = 'qualified';
  QualAttr := Root.AttributeValue['attributeFormDefault'] = 'qualified';
  for I := 0 to Root.ChildCount - 1 do
  begin
    C := Root.Children[I];
    if C.NodeType <> ntElement then Continue;
    if C.NamespaceURI <> XSD_NS_URI then Continue;
    Nm := TXmlElement(C).AttributeValue['name'];
    if IsXsd(C, 'element') then
    begin
      SetLength(FElements, System.Length(FElements) + 1);
      FElements[High(FElements)] := ParseElement(TXmlElement(C), True, Qualified, Ns);
    end
    else if IsXsd(C, 'complexType') then
    begin
      SetLength(FComplex, System.Length(FComplex) + 1);
      FComplex[High(FComplex)] := ParseComplexType(TXmlElement(C), Nm, nil);
    end
    else if IsXsd(C, 'simpleType') then
    begin
      SetLength(FSimple, System.Length(FSimple) + 1);
      FSimple[High(FSimple)] := ParseSimpleType(TXmlElement(C), Nm);
    end
    else if IsXsd(C, 'attribute') then
    begin
      SetLength(FAttributes, System.Length(FAttributes) + 1);
      FAttributes[High(FAttributes)] := ParseAttribute(TXmlElement(C), True, QualAttr, Ns);
    end
    else if IsXsd(C, 'group') then
    begin
      for J := 0 to C.ChildCount - 1 do
        if IsXsd(C.Children[J], 'sequence') or IsXsd(C.Children[J], 'choice') or IsXsd(C.Children[J], 'all') then
        begin
          SetLength(FGroups, System.Length(FGroups) + 1);
          FGroups[High(FGroups)].Name := Nm;
          FGroups[High(FGroups)].Particle := ParseModelGroup(TXmlElement(C.Children[J]), Qualified, Ns);
        end;
    end
    else if IsXsd(C, 'attributeGroup') then
    begin
      Attrs := TList.Create;
      Refs := TStringList.Create;
      try
        AnyAttr := False;
        G := TXmlElement(C);
        ParseAttributeChildren(G, Attrs, Refs, AnyAttr, QualAttr, Ns);
        SetLength(FAttrGroups, System.Length(FAttrGroups) + 1);
        FAttrGroups[High(FAttrGroups)].Name := Nm;
        FAttrGroups[High(FAttrGroups)].AnyAttribute := AnyAttr;
        SetLength(FAttrGroups[High(FAttrGroups)].Attrs, Attrs.Count);
        for J := 0 to Attrs.Count - 1 do
          FAttrGroups[High(FAttrGroups)].Attrs[J] := TXsdAttribute(Attrs[J]);
        SetLength(FAttrGroups[High(FAttrGroups)].Refs, Refs.Count);
        for J := 0 to Refs.Count - 1 do
          FAttrGroups[High(FAttrGroups)].Refs[J] := Refs[J];
      finally
        Attrs.Free;
        Refs.Free;
      end;
    end
    else if IsXsd(C, 'annotation') or IsXsd(C, 'notation') then
    else if IsXsd(C, 'import') or IsXsd(C, 'include') or IsXsd(C, 'redefine') then
      Warn('xs:' + C.LocalName + ' is not followed; pass additional schema documents to AddSchemaDocument');
  end;
end;

{ ---------------- lookup ---------------- }

function TXsdSchema.FindGlobalElement(const Uri, Local: XmlString): TXsdElementDecl;
var
  I: Integer;
begin
  for I := 0 to High(FElements) do
    if (FElements[I].Name = Local) and (FElements[I].Uri = Uri) then
    begin
      Result := FElements[I];
      Exit;
    end;
  Result := nil;
end;

function TXsdSchema.FindGlobalAttribute(const Local: XmlString): TXsdAttribute;
var
  I: Integer;
begin
  for I := 0 to High(FAttributes) do
    if FAttributes[I].Name = Local then
    begin
      Result := FAttributes[I];
      Exit;
    end;
  Result := nil;
end;

function TXsdSchema.BuiltinType(B: TXsdBuiltin): TXsdSimpleType;
begin
  if FBuiltinCache[B] = nil then
  begin
    FBuiltinCache[B] := NewSimple;
    FBuiltinCache[B].IsBuiltin := True;
    FBuiltinCache[B].Builtin := B;
    FBuiltinCache[B].Name := BuiltinNames[B];
  end;
  Result := FBuiltinCache[B];
end;

function TXsdSchema.FindSimple(const Name: XmlString; IsXsd: Boolean): TXsdSimpleType;
var
  I: Integer;
  B: TXsdBuiltin;
begin
  Result := nil;
  if IsXsd then
  begin
    if BuiltinFromName(Name, B) then Result := BuiltinType(B);
    Exit;
  end;
  for I := 0 to High(FSimple) do
    if FSimple[I].Name = Name then
    begin
      Result := FSimple[I];
      if (Result.Base = nil) and (Result.BaseName <> '') then
        Result.Base := FindSimple(Result.BaseName, Result.BaseIsXsd);
      Exit;
    end;
end;

function TXsdSchema.FindComplex(const Name: XmlString): TXsdComplexType;
var
  I: Integer;
begin
  for I := 0 to High(FComplex) do
    if FComplex[I].Name = Name then
    begin
      Result := FComplex[I];
      Exit;
    end;
  Result := nil;
end;

function TXsdSchema.FindGroup(const Name: XmlString): TXsdParticle;
var
  I: Integer;
begin
  for I := 0 to High(FGroups) do
    if FGroups[I].Name = Name then
    begin
      Result := FGroups[I].Particle;
      Exit;
    end;
  Result := nil;
end;

function TXsdSchema.FinalizeComplex(CT: TXsdComplexType): TXsdParticle;
var
  Base: TXsdComplexType;
  BP: TXsdParticle;
  S: TXsdParticle;
begin
  if CT.Finalized then
  begin
    Result := CT.EffContent;
    Exit;
  end;
  if CT.Finalizing then
    raise EXmlValidationException.CreateCode(XFE_VAL_SCHEMA, 'Invalid schema: circular type derivation at "' + CT.Name + '"');
  CT.Finalizing := True;
  CT.EffContent := CT.Content;
  if CT.IsExtension and (CT.BaseName <> '') and (not CT.SimpleBaseIsXsd) then
  begin
    Base := FindComplex(CT.BaseName);
    if Base <> nil then
    begin
      BP := FinalizeComplex(Base);
      if CT.Content = nil then
        CT.EffContent := BP
      else if BP <> nil then
      begin
        S := OwnParticle(TXsdParticle.Create);
        S.Kind := pkSequence;
        SetLength(S.Children, 2);
        S.Children[0] := BP;
        S.Children[1] := CT.Content;
        CT.EffContent := S;
      end;
      if Base.Mixed then CT.Mixed := True;
    end;
  end;
  CT.Finalizing := False;
  CT.Finalized := True;
  Result := CT.EffContent;
end;

function TXsdSchema.GroupAttributes(const Name: XmlString; Attrs: TList; var AnyAttr: Boolean;
  Depth: Integer): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Depth > 32 then Exit;
  for I := 0 to High(FAttrGroups) do
    if FAttrGroups[I].Name = Name then
    begin
      Result := True;
      for J := 0 to High(FAttrGroups[I].Attrs) do Attrs.Add(FAttrGroups[I].Attrs[J]);
      for J := 0 to High(FAttrGroups[I].Refs) do GroupAttributes(FAttrGroups[I].Refs[J], Attrs, AnyAttr, Depth + 1);
      if FAttrGroups[I].AnyAttribute then AnyAttr := True;
      Exit;
    end;
end;

procedure TXsdSchema.GatherAttributes(CT: TXsdComplexType; Attrs: TList; var AnyAttr: Boolean);
var
  I: Integer;
  Base: TXsdComplexType;
begin
  if CT.IsExtension and (CT.BaseName <> '') then
  begin
    Base := FindComplex(CT.BaseName);
    if (Base <> nil) and (Base <> CT) then GatherAttributes(Base, Attrs, AnyAttr);
  end;
  for I := 0 to High(CT.Attrs) do Attrs.Add(CT.Attrs[I]);
  for I := 0 to High(CT.AttrGroupRefs) do GroupAttributes(CT.AttrGroupRefs[I], Attrs, AnyAttr, 0);
  if CT.AnyAttribute then AnyAttr := True;
end;

{ ---------------- built-in value checks ---------------- }

function IsDigits(const S: XmlString; From: Integer): Boolean;
var
  I: Integer;
begin
  Result := From <= System.Length(S);
  for I := From to System.Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
    begin
      Result := False;
      Exit;
    end;
end;

function IntegerForm(const V: XmlString; out Neg: Boolean; out Digits: XmlString): Boolean;
var
  I: Integer;
begin
  Result := False;
  Neg := False;
  I := 1;
  if (V <> '') and ((V[1] = '-') or (V[1] = '+')) then
  begin
    Neg := V[1] = '-';
    Inc(I);
  end;
  if not IsDigits(V, I) then Exit;
  Digits := Copy(V, I, MaxInt);
  while (System.Length(Digits) > 1) and (Digits[1] = '0') do Delete(Digits, 1, 1);
  if Digits = '0' then Neg := False;
  Result := True;
end;

function InInt64Range(Neg: Boolean; const Digits: XmlString; Min, Max: Int64): Boolean;
var
  N: Int64;
begin
  Result := False;
  if System.Length(Digits) > 19 then Exit;
  if Neg then
  begin
    if not TryStrToInt64('-' + Digits, N) then Exit;
  end
  else if not TryStrToInt64(Digits, N) then Exit;
  Result := (N >= Min) and (N <= Max);
end;

function DateOk(const S: XmlString; var P: Integer): Boolean;
var
  Y, M, D, MaxD, I: Integer;
  YS: XmlString;
begin
  Result := False;
  I := P;
  if (I <= System.Length(S)) and (S[I] = '-') then Inc(I);
  YS := '';
  while (I <= System.Length(S)) and (S[I] >= '0') and (S[I] <= '9') do
  begin
    YS := YS + S[I];
    Inc(I);
  end;
  if System.Length(YS) < 4 then Exit;
  if I + 5 > System.Length(S) then Exit;
  if (S[I] <> '-') or (S[I + 3] <> '-') then Exit;
  if not (IsDigits(Copy(S, I + 1, 2), 1) and IsDigits(Copy(S, I + 4, 2), 1)) then Exit;
  M := StrToInt(Copy(S, I + 1, 2));
  D := StrToInt(Copy(S, I + 4, 2));
  Y := StrToIntDef(Copy(YS, System.Length(YS) - 3, 4), 1);
  if (M < 1) or (M > 12) or (D < 1) then Exit;
  case M of
    4, 6, 9, 11: MaxD := 30;
    2: if ((Y mod 4 = 0) and (Y mod 100 <> 0)) or (Y mod 400 = 0) then MaxD := 29 else MaxD := 28;
  else
    MaxD := 31;
  end;
  if D > MaxD then Exit;
  P := I + 6;
  Result := True;
end;

function TimeOk(const S: XmlString; var P: Integer): Boolean;
var
  I: Integer;
  H, Mi, Se: Integer;
begin
  Result := False;
  I := P;
  if I + 7 > System.Length(S) then Exit;
  if (S[I + 2] <> ':') or (S[I + 5] <> ':') then Exit;
  if not (IsDigits(Copy(S, I, 2), 1) and IsDigits(Copy(S, I + 3, 2), 1) and IsDigits(Copy(S, I + 6, 2), 1)) then Exit;
  H := StrToInt(Copy(S, I, 2));
  Mi := StrToInt(Copy(S, I + 3, 2));
  Se := StrToInt(Copy(S, I + 6, 2));
  if (H > 24) or (Mi > 59) or (Se > 60) or ((H = 24) and ((Mi <> 0) or (Se <> 0))) then Exit;
  Inc(I, 8);
  if (I <= System.Length(S)) and (S[I] = '.') then
  begin
    Inc(I);
    if (I > System.Length(S)) or (S[I] < '0') or (S[I] > '9') then Exit;
    while (I <= System.Length(S)) and (S[I] >= '0') and (S[I] <= '9') do Inc(I);
  end;
  P := I;
  Result := True;
end;

function TzOk(const S: XmlString; P: Integer): Boolean;
var
  H, M: Integer;
begin
  if P > System.Length(S) then
  begin
    Result := True;
    Exit;
  end;
  if (S[P] = 'Z') and (P = System.Length(S)) then
  begin
    Result := True;
    Exit;
  end;
  Result := False;
  if (P + 5 <> System.Length(S)) or ((S[P] <> '+') and (S[P] <> '-')) or (S[P + 3] <> ':') then Exit;
  if not (IsDigits(Copy(S, P + 1, 2), 1) and IsDigits(Copy(S, P + 4, 2), 1)) then Exit;
  H := StrToInt(Copy(S, P + 1, 2));
  M := StrToInt(Copy(S, P + 4, 2));
  Result := (H < 14) and (M < 60) or ((H = 14) and (M = 0));
end;

function DurationOk(const S: XmlString): Boolean;
var
  I, N: Integer;
  InTime, HasComp: Boolean;
  Seen: set of Byte;
  Order: Byte;
  C: WideChar;
  HasDigit, HasDot: Boolean;
begin
  Result := False;
  N := System.Length(S);
  I := 1;
  if (I <= N) and (S[I] = '-') then Inc(I);
  if (I > N) or (S[I] <> 'P') then Exit;
  Inc(I);
  InTime := False;
  HasComp := False;
  Seen := [];
  while I <= N do
  begin
    if S[I] = 'T' then
    begin
      if InTime then Exit;
      InTime := True;
      Inc(I);
      if I > N then Exit;
      Continue;
    end;
    HasDigit := False;
    HasDot := False;
    while (I <= N) and (((S[I] >= '0') and (S[I] <= '9')) or (S[I] = '.')) do
    begin
      if S[I] = '.' then
      begin
        if HasDot then Exit;
        HasDot := True;
      end
      else
        HasDigit := True;
      Inc(I);
    end;
    if (not HasDigit) or (I > N) then Exit;
    C := S[I];
    Inc(I);
    if InTime then
    begin
      case C of
        'H': Order := 4;
        'M': Order := 5;
        'S': Order := 6;
      else
        Exit;
      end;
      if HasDot and (C <> 'S') then Exit;
    end
    else
    begin
      case C of
        'Y': Order := 1;
        'M': Order := 2;
        'D': Order := 3;
      else
        Exit;
      end;
      if HasDot then Exit;
    end;
    if Order in Seen then Exit;
    Include(Seen, Order);
    HasComp := True;
  end;
  Result := HasComp;
end;

function Base64Ok(const S: XmlString): Boolean;
var
  I, Cnt, Pad: Integer;
  C: WideChar;
begin
  Cnt := 0;
  Pad := 0;
  Result := False;
  for I := 1 to System.Length(S) do
  begin
    C := S[I];
    if XmlIsWhite(Ord(C)) then Continue;
    if C = '=' then Inc(Pad)
    else if (Pad > 0) or (not (((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
       ((C >= '0') and (C <= '9')) or (C = '+') or (C = '/'))) then Exit;
    Inc(Cnt);
  end;
  Result := (Cnt mod 4 = 0) and (Pad <= 2);
end;

function HexOk(const S: XmlString): Boolean;
var
  I: Integer;
begin
  Result := (System.Length(S) mod 2 = 0);
  if not Result then Exit;
  for I := 1 to System.Length(S) do
    if not (((S[I] >= '0') and (S[I] <= '9')) or ((S[I] >= 'a') and (S[I] <= 'f')) or
       ((S[I] >= 'A') and (S[I] <= 'F'))) then
    begin
      Result := False;
      Exit;
    end;
end;

function LanguageOk(const S: XmlString): Boolean;
var
  I, Run: Integer;
begin
  Result := False;
  Run := 0;
  if S = '' then Exit;
  for I := 1 to System.Length(S) + 1 do
  begin
    if (I > System.Length(S)) or (S[I] = '-') then
    begin
      if (Run < 1) or (Run > 8) then Exit;
      Run := 0;
    end
    else if ((S[I] >= 'a') and (S[I] <= 'z')) or ((S[I] >= 'A') and (S[I] <= 'Z')) or
            ((I > 1) and (S[I] >= '0') and (S[I] <= '9')) then
      Inc(Run)
    else
      Exit;
  end;
  Result := True;
end;

function BuiltinOk(B: TXsdBuiltin; const V: XmlString): Boolean;
var
  Neg: Boolean;
  Dg: XmlString;
  P, I: Integer;
  D: Double;
  Dot: Boolean;
begin
  Result := True;
  case B of
    xbAnyType, xbAnySimple, xbString, xbNormalizedString, xbToken, xbAnyUri: ;
    xbBoolean: Result := (V = 'true') or (V = 'false') or (V = '1') or (V = '0');
    xbDecimal:
      begin
        I := 1;
        if (V <> '') and ((V[1] = '-') or (V[1] = '+')) then Inc(I);
        Dot := False;
        Result := I <= System.Length(V);
        P := 0;
        while Result and (I <= System.Length(V)) do
        begin
          if V[I] = '.' then
          begin
            if Dot then Result := False;
            Dot := True;
          end
          else if (V[I] >= '0') and (V[I] <= '9') then Inc(P)
          else Result := False;
          Inc(I);
        end;
        Result := Result and (P > 0);
      end;
    xbInteger: Result := IntegerForm(V, Neg, Dg);
    xbNonNegativeInteger: Result := IntegerForm(V, Neg, Dg) and not Neg;
    xbPositiveInteger: Result := IntegerForm(V, Neg, Dg) and (not Neg) and (Dg <> '0');
    xbNonPositiveInteger: Result := IntegerForm(V, Neg, Dg) and (Neg or (Dg = '0'));
    xbNegativeInteger: Result := IntegerForm(V, Neg, Dg) and Neg;
    xbLong: Result := IntegerForm(V, Neg, Dg) and InInt64Range(Neg, Dg, Low(Int64), High(Int64));
    xbInt: Result := IntegerForm(V, Neg, Dg) and InInt64Range(Neg, Dg, -2147483648, 2147483647);
    xbShort: Result := IntegerForm(V, Neg, Dg) and InInt64Range(Neg, Dg, -32768, 32767);
    xbByte: Result := IntegerForm(V, Neg, Dg) and InInt64Range(Neg, Dg, -128, 127);
    xbUnsignedLong:
      Result := IntegerForm(V, Neg, Dg) and (not Neg) and
        ((System.Length(Dg) < 20) or ((System.Length(Dg) = 20) and (Dg <= '18446744073709551615')));
    xbUnsignedInt: Result := IntegerForm(V, Neg, Dg) and (not Neg) and InInt64Range(False, Dg, 0, 4294967295);
    xbUnsignedShort: Result := IntegerForm(V, Neg, Dg) and (not Neg) and InInt64Range(False, Dg, 0, 65535);
    xbUnsignedByte: Result := IntegerForm(V, Neg, Dg) and (not Neg) and InInt64Range(False, Dg, 0, 255);
    xbFloat, xbDouble:
      Result := (V = 'INF') or (V = '-INF') or (V = '+INF') or (V = 'NaN') or XmlTryParseFloat(V, D);
    xbDate:
      begin
        P := 1;
        Result := DateOk(V, P) and TzOk(V, P);
      end;
    xbDateTime:
      begin
        P := 1;
        Result := DateOk(V, P) and (P <= System.Length(V)) and (V[P] = 'T');
        if Result then
        begin
          Inc(P);
          Result := TimeOk(V, P) and TzOk(V, P);
        end;
      end;
    xbTime:
      begin
        P := 1;
        Result := TimeOk(V, P) and TzOk(V, P);
      end;
    xbGYear:
      begin
        P := 1;
        if (V <> '') and (V[1] = '-') then Inc(P);
        I := P;
        while (I <= System.Length(V)) and (V[I] >= '0') and (V[I] <= '9') do Inc(I);
        Result := (I - P >= 4) and TzOk(V, I);
      end;
    xbDuration: Result := DurationOk(V);
    xbBase64: Result := Base64Ok(V);
    xbHexBinary: Result := HexOk(V);
    xbNCName, xbID, xbIDREF: Result := XmlIsValidNCName(V);
    xbName: Result := XmlIsValidName(V);
    xbLanguage: Result := LanguageOk(V);
    xbQName: Result := XmlIsValidQName(V);
  end;
end;

function RootBuiltin(ST: TXsdSimpleType): TXsdBuiltin;
var
  T: TXsdSimpleType;
  Guard: Integer;
begin
  T := ST;
  Guard := 0;
  while (T <> nil) and (not T.IsBuiltin) and (Guard < 64) do
  begin
    T := T.Base;
    Inc(Guard);
  end;
  if T <> nil then Result := T.Builtin else Result := xbString;
end;

function IsNumericBuiltin(B: TXsdBuiltin): Boolean;
begin
  Result := B in [xbDecimal, xbInteger, xbLong, xbInt, xbShort, xbByte, xbNonNegativeInteger,
    xbPositiveInteger, xbNonPositiveInteger, xbNegativeInteger, xbUnsignedLong, xbUnsignedInt,
    xbUnsignedShort, xbUnsignedByte, xbFloat, xbDouble];
end;

function ApplyWhitespace(const V: XmlString; Mode: XmlString): XmlString;
var
  I: Integer;
  B: TXmlStrBuf;
  InWs, Started: Boolean;
begin
  if Mode = 'preserve' then
  begin
    Result := V;
    Exit;
  end;
  if Mode = 'replace' then
  begin
    Result := V;
    for I := 1 to System.Length(Result) do
      if (Result[I] = #9) or (Result[I] = #10) or (Result[I] = #13) then Result[I] := ' ';
    Exit;
  end;
  B := TXmlStrBuf.Create(System.Length(V) + 1);
  try
    InWs := False;
    Started := False;
    for I := 1 to System.Length(V) do
      if XmlIsWhite(Ord(V[I])) then InWs := True
      else
      begin
        if InWs and Started then B.Append(' ');
        InWs := False;
        Started := True;
        B.AppendChar(V[I]);
      end;
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

function WhitespaceModeFor(ST: TXsdSimpleType): XmlString;
var
  T: TXsdSimpleType;
  Guard: Integer;
begin
  T := ST;
  Guard := 0;
  while (T <> nil) and (Guard < 64) do
  begin
    if T.WhiteSpace <> '' then
    begin
      Result := T.WhiteSpace;
      Exit;
    end;
    if T.IsBuiltin then Break;
    T := T.Base;
    Inc(Guard);
  end;
  case RootBuiltin(ST) of
    xbString, xbAnyType, xbAnySimple: Result := 'preserve';
    xbNormalizedString: Result := 'replace';
  else
    Result := 'collapse';
  end;
end;

function CheckFacets(ST: TXsdSimpleType; const V: XmlString; RootB: TXsdBuiltin; out Msg: XmlString): Boolean;
var
  I: Integer;
  Found: Boolean;
  A, B: Double;
  Numeric: Boolean;
  Cr: Integer;

  function Cmp(const Lim: XmlString): Integer; // -1,0,1 ; 2 = not comparable
  var
    L: Double;
  begin
    if Numeric then
    begin
      if XmlTryParseFloat(Lim, L) and XmlTryParseFloat(V, A) then
      begin
        if A < L then Result := -1 else if A > L then Result := 1 else Result := 0;
      end
      else
        Result := 2;
    end
    else if RootB in [xbDate, xbDateTime, xbTime, xbGYear] then
    begin
      if V < Lim then Result := -1 else if V > Lim then Result := 1 else Result := 0;
    end
    else
      Result := 2;
  end;

begin
  Result := False;
  Numeric := IsNumericBuiltin(RootB);
  B := 0;
  if ST.LengthFacet >= 0 then
    if System.Length(V) <> ST.LengthFacet then
    begin
      Msg := 'length must be ' + IntToStr(ST.LengthFacet);
      Exit;
    end;
  if (ST.MinLength >= 0) and (System.Length(V) < ST.MinLength) then
  begin
    Msg := 'length must be at least ' + IntToStr(ST.MinLength);
    Exit;
  end;
  if (ST.MaxLength >= 0) and (System.Length(V) > ST.MaxLength) then
  begin
    Msg := 'length must be at most ' + IntToStr(ST.MaxLength);
    Exit;
  end;
  if System.Length(ST.Enums) > 0 then
  begin
    Found := False;
    for I := 0 to High(ST.Enums) do
      if (ST.Enums[I] = V) or
         (Numeric and XmlTryParseFloat(ST.Enums[I], A) and XmlTryParseFloat(V, B) and (A = B)) then
      begin
        Found := True;
        Break;
      end;
    if not Found then
    begin
      Msg := 'value is not one of the allowed enumeration values';
      Exit;
    end;
  end;
  if ST.HasMinInc then
  begin
    Cr := Cmp(ST.MinInc);
    if Cr = -1 then begin Msg := 'value must be >= ' + ST.MinInc; Exit; end;
  end;
  if ST.HasMaxInc then
  begin
    Cr := Cmp(ST.MaxInc);
    if Cr = 1 then begin Msg := 'value must be <= ' + ST.MaxInc; Exit; end;
  end;
  if ST.HasMinExc then
  begin
    Cr := Cmp(ST.MinExc);
    if (Cr = -1) or (Cr = 0) then begin Msg := 'value must be > ' + ST.MinExc; Exit; end;
  end;
  if ST.HasMaxExc then
  begin
    Cr := Cmp(ST.MaxExc);
    if (Cr = 0) or (Cr = 1) then begin Msg := 'value must be < ' + ST.MaxExc; Exit; end;
  end;
  Result := True;
end;

function CheckSimple(ST: TXsdSimpleType; const V: XmlString; RootB: TXsdBuiltin; Depth: Integer;
  out Msg: XmlString): Boolean;
begin
  Result := False;
  if (ST = nil) or (Depth > 64) then
  begin
    Result := True;
    Exit;
  end;
  if ST.Base <> nil then
    if not CheckSimple(ST.Base, V, RootB, Depth + 1, Msg) then Exit;
  if ST.IsBuiltin then
  begin
    if not BuiltinOk(ST.Builtin, V) then
    begin
      Msg := 'not a valid xs:' + BuiltinNames[ST.Builtin];
      Exit;
    end;
  end
  else if not CheckFacets(ST, V, RootB, Msg) then
    Exit;
  Result := True;
end;

{ ---------------- validator ---------------- }

constructor TXmlValidator.Create(ASchema: TXsdSchema);
begin
  inherited Create;
  FSchema := ASchema;
end;

procedure TXmlValidator.Clear;
begin
  FErrorCount := 0;
end;

function TXmlValidator.GetError(Index: Integer): TXmlValidationError;
begin
  Result := FErrors[Index];
end;

function TXmlValidator.PathOf(Node: TXmlNode): XmlString;
begin
  Result := '';
  while (Node <> nil) and (Node.NodeType <> ntDocument) do
  begin
    if Node.NodeType = ntAttribute then
      Result := '/@' + Node.Name + Result
    else
      Result := '/' + Node.Name + Result;
    Node := Node.ParentNode;
  end;
  if Result = '' then Result := '/';
end;

procedure TXmlValidator.AddError(Node: TXmlNode; const Msg: XmlString);
var
  L, C: Integer;
  N: TXmlNode;
begin
  if FErrorCount >= System.Length(FErrors) then SetLength(FErrors, FErrorCount * 2 + 8);
  FErrors[FErrorCount].Code := XFE_VAL_GENERIC;
  FErrors[FErrorCount].Message := Msg;
  L := 0;
  C := 0;
  N := Node;
  if (N <> nil) and (N.NodeType = ntAttribute) then N := N.ParentNode;
  if N <> nil then
  begin
    L := N.Line;
    C := N.Column;
  end;
  FErrors[FErrorCount].Line := L;
  FErrors[FErrorCount].Column := C;
  if Node <> nil then FErrors[FErrorCount].Path := PathOf(Node) else FErrors[FErrorCount].Path := '';
  Inc(FErrorCount);
end;

function TXmlValidator.ErrorsAsText: XmlString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FErrorCount - 1 do
  begin
    if I > 0 then Result := Result + #10;
    Result := Result + FErrors[I].Path + ': ' + FErrors[I].Message;
    if FErrors[I].Line > 0 then
      Result := Result + ' (line ' + IntToStr(FErrors[I].Line) + ', column ' + IntToStr(FErrors[I].Column) + ')';
  end;
end;

function TXmlValidator.ResolveDecl(D: TXsdElementDecl): TXsdElementDecl;
begin
  Result := D;
  if D.RefName = '' then Exit;
  Result := FSchema.FindGlobalElement(FSchema.TargetNamespace, D.RefName);
  if Result = nil then Result := FSchema.FindGlobalElement('', D.RefName);
end;

function TXmlValidator.ElementMatches(D: TXsdElementDecl; E: TXmlElement): Boolean;
var
  R: TXsdElementDecl;
begin
  R := ResolveDecl(D);
  Result := (R <> nil) and (R.Name = E.LocalName) and (R.Uri = E.NamespaceURI);
end;

function TXmlValidator.SimpleFor(const TypeName: XmlString; IsXsd: Boolean; InlineT: TXsdSimpleType): TXsdSimpleType;
begin
  if InlineT <> nil then
  begin
    Result := InlineT;
    if (Result.Base = nil) and (Result.BaseName <> '') then
      Result.Base := FSchema.FindSimple(Result.BaseName, Result.BaseIsXsd);
  end
  else if TypeName <> '' then
    Result := FSchema.FindSimple(TypeName, IsXsd)
  else
    Result := nil;
end;

procedure TXmlValidator.ValidateSimpleValue(Node: TXmlNode; const Value: XmlString;
  ST: TXsdSimpleType; const What: XmlString);
var
  V, Msg: XmlString;
  RB: TXsdBuiltin;
begin
  if ST = nil then Exit;
  V := ApplyWhitespace(Value, WhitespaceModeFor(ST));
  RB := RootBuiltin(ST);
  if not CheckSimple(ST, V, RB, 0, Msg) then
    AddError(Node, What + ' "' + V + '": ' + Msg);
end;

procedure TXmlValidator.NoteExpected(D: TXsdElementDecl; At: Integer);
var
  R: TXsdElementDecl;
  N: XmlString;
begin
  R := ResolveDecl(D);
  if R = nil then Exit;
  N := R.Name;
  if At > FFailPos then
  begin
    FFailPos := At;
    FExpected := '';
  end;
  if At = FFailPos then
  begin
    if FExpected = '' then
      FExpected := N
    else if System.Pos(', ' + N + ',', ', ' + FExpected + ',') = 0 then
      FExpected := FExpected + ', ' + N;
  end;
end;

function TXmlValidator.MatchOnce(P: TXsdParticle; var Pos: Integer): Boolean;
var
  I, Save, Prev: Integer;
  G: TXsdParticle;
  Used: array of Boolean;
  Matched: Boolean;
begin
  Result := False;
  case P.Kind of
    pkElement:
      if (Pos < FKidCount) and ElementMatches(P.Elem, FKids[Pos]) then
      begin
        FAssigned[Pos] := ResolveDecl(P.Elem);
        Inc(Pos);
        Result := True;
      end
      else
        NoteExpected(P.Elem, Pos);
    pkAny:
      if Pos < FKidCount then
      begin
        FAssigned[Pos] := nil;
        Inc(Pos);
        Result := True;
      end;
    pkSequence:
      begin
        for I := 0 to High(P.Children) do
          if not MatchP(P.Children[I], Pos) then Exit;
        Result := True;
      end;
    pkChoice:
      begin
        if System.Length(P.Children) = 0 then
        begin
          Result := True;
          Exit;
        end;
        for I := 0 to High(P.Children) do
        begin
          Save := Pos;
          if MatchP(P.Children[I], Pos) then
          begin
            Result := True;
            Exit;
          end;
          Pos := Save;
        end;
      end;
    pkAll:
      begin
        SetLength(Used, System.Length(P.Children));
        repeat
          Matched := False;
          if Pos < FKidCount then
            for I := 0 to High(P.Children) do
              if (not Used[I]) and (P.Children[I].Kind = pkElement) and
                 ElementMatches(P.Children[I].Elem, FKids[Pos]) then
              begin
                Used[I] := True;
                FAssigned[Pos] := ResolveDecl(P.Children[I].Elem);
                Inc(Pos);
                Matched := True;
                Break;
              end;
        until not Matched;
        Result := True;
        for I := 0 to High(P.Children) do
          if (not Used[I]) and (P.Children[I].MinOccurs > 0) then
          begin
            if P.Children[I].Kind = pkElement then NoteExpected(P.Children[I].Elem, Pos);
            Result := False;
          end;
      end;
    pkGroupRef:
      begin
        G := FSchema.FindGroup(P.GroupName);
        if G = nil then
        begin
          AddError(nil, 'Schema error: unknown group "' + P.GroupName + '"');
          Result := True;
        end
        else
        begin
          Prev := Pos;
          Result := MatchOnce(G, Pos);
          if (not Result) then Pos := Prev;
        end;
      end;
  end;
end;

function TXmlValidator.MatchP(P: TXsdParticle; var Pos: Integer): Boolean;
var
  Count, Save: Integer;
begin
  Count := 0;
  while (P.MaxOccurs < 0) or (Count < P.MaxOccurs) do
  begin
    Save := Pos;
    if not MatchOnce(P, Pos) then
    begin
      Pos := Save;
      Break;
    end;
    Inc(Count);
    if Pos = Save then
    begin
      if Count < P.MinOccurs then Count := P.MinOccurs;
      Break;
    end;
  end;
  Result := Count >= P.MinOccurs;
end;

procedure TXmlValidator.ValidateAttributes(E: TXmlElement; CT: TXsdComplexType);
var
  Decls: TList;
  AnyAttr: Boolean;
  I, J: Integer;
  A: TXmlAttribute;
  D, R: TXsdAttribute;
  Found: Boolean;
  Seen: array of Boolean;
  ST: TXsdSimpleType;
begin
  Decls := TList.Create;
  try
    AnyAttr := False;
    FSchema.GatherAttributes(CT, Decls, AnyAttr);
    SetLength(Seen, Decls.Count);
    for I := 0 to E.AttributeCount - 1 do
    begin
      A := E.Attributes[I];
      if A.IsNamespaceDeclaration or (A.NamespaceURI = XSI_NS_URI) then Continue;
      Found := False;
      for J := 0 to Decls.Count - 1 do
      begin
        D := TXsdAttribute(Decls[J]);
        R := D;
        if D.RefName <> '' then
        begin
          R := FSchema.FindGlobalAttribute(D.RefName);
          if R = nil then Continue;
        end;
        if (R.Name = A.LocalName) and (R.Uri = A.NamespaceURI) then
        begin
          Found := True;
          Seen[J] := True;
          if D.Prohibited then
            AddError(A, 'Attribute "' + A.Name + '" is prohibited')
          else
          begin
            ST := SimpleFor(R.TypeName, R.TypeIsXsd, R.InlineT);
            ValidateSimpleValue(A, A.Value, ST, 'Attribute "' + A.Name + '" value');
            if D.HasFixed and (A.Value <> D.Fixed) then
              AddError(A, 'Attribute "' + A.Name + '" must have the fixed value "' + D.Fixed + '"')
            else if R.HasFixed and (A.Value <> R.Fixed) then
              AddError(A, 'Attribute "' + A.Name + '" must have the fixed value "' + R.Fixed + '"');
          end;
          Break;
        end;
      end;
      if (not Found) and (not AnyAttr) then
        AddError(A, 'Attribute "' + A.Name + '" is not allowed on element <' + E.Name + '>');
    end;
    for J := 0 to Decls.Count - 1 do
    begin
      D := TXsdAttribute(Decls[J]);
      if D.Required and (not Seen[J]) then
        AddError(E, 'Required attribute "' + D.Name + '" is missing on element <' + E.Name + '>');
    end;
  finally
    Decls.Free;
  end;
end;

procedure TXmlValidator.ValidateComplex(E: TXmlElement; CT: TXsdComplexType);
var
  Content: TXsdParticle;
  I, Pos, N: Integer;
  C: TXmlNode;
  LKids: array of TXmlElement;
  LAssigned: array of TXsdElementDecl;
  Txt: XmlString;
  ST, Base: TXsdSimpleType;
  HasText, Ok: Boolean;
begin
  ValidateAttributes(E, CT);
  if CT.HasSimpleContent then
  begin
    for I := 0 to E.ChildCount - 1 do
      if E.Children[I].NodeType = ntElement then
      begin
        AddError(E.Children[I], 'Element <' + E.Children[I].Name + '> is not allowed: <' + E.Name + '> has simple content');
        Break;
      end;
    Base := FSchema.FindSimple(CT.SimpleBaseName, CT.SimpleBaseIsXsd);
    if CT.SimpleRestriction <> nil then
    begin
      CT.SimpleRestriction.Base := Base;
      ST := CT.SimpleRestriction;
    end
    else
      ST := Base;
    ValidateSimpleValue(E, E.TextContent, ST, 'Element <' + E.Name + '> value');
    Exit;
  end;

  Content := FSchema.FinalizeComplex(CT);
  HasText := False;
  N := 0;
  for I := 0 to E.ChildCount - 1 do
  begin
    C := E.Children[I];
    if C.NodeType = ntElement then
      Inc(N)
    else if ((C.NodeType = ntText) or (C.NodeType = ntCData)) and (not XmlIsAllWhite(C.Value)) then
      HasText := True;
  end;
  if HasText and (not CT.Mixed) then
    AddError(E, 'Text is not allowed in element <' + E.Name + '>');

  SetLength(FKids, N);
  SetLength(FAssigned, N);
  FKidCount := N;
  N := 0;
  for I := 0 to E.ChildCount - 1 do
    if E.Children[I].NodeType = ntElement then
    begin
      FKids[N] := TXmlElement(E.Children[I]);
      FAssigned[N] := nil;
      Inc(N);
    end;
  FFailPos := -1;
  FExpected := '';
  Pos := 0;
  if Content = nil then Ok := True else Ok := MatchP(Content, Pos);
  if Ok and (Pos < FKidCount) then
  begin
    AddError(FKids[Pos], 'Unexpected element <' + FKids[Pos].Name + '> in <' + E.Name + '>' +
      ' (no more elements allowed here)');
    Ok := False;
  end
  else if not Ok then
  begin
    if FFailPos < 0 then FFailPos := Pos;
    if FFailPos < FKidCount then
    begin
      Txt := 'Unexpected element <' + FKids[FFailPos].Name + '> in <' + E.Name + '>';
      if FExpected <> '' then Txt := Txt + '; expected: ' + FExpected;
      AddError(FKids[FFailPos], Txt);
    end
    else
    begin
      Txt := 'Element <' + E.Name + '> is incomplete';
      if FExpected <> '' then Txt := Txt + '; missing: ' + FExpected;
      AddError(E, Txt);
    end;
  end;
  if Ok then
  begin
    // the shared arrays are reused by recursive calls, so work on copies
    SetLength(LKids, FKidCount);
    SetLength(LAssigned, FKidCount);
    for I := 0 to FKidCount - 1 do
    begin
      LKids[I] := FKids[I];
      LAssigned[I] := FAssigned[I];
    end;
    for I := 0 to System.Length(LKids) - 1 do
      if LAssigned[I] <> nil then ValidateElement(LKids[I], LAssigned[I]);
  end;
end;

procedure TXmlValidator.ValidateElement(E: TXmlElement; Decl: TXsdElementDecl);
var
  CT: TXsdComplexType;
  ST: TXsdSimpleType;
  NilAttr: TXmlAttribute;
  I: Integer;
  HasContent: Boolean;
  Txt: XmlString;
begin
  NilAttr := E.FindAttributeNS(XSI_NS_URI, 'nil');
  if (NilAttr <> nil) and ((NilAttr.Value = 'true') or (NilAttr.Value = '1')) then
  begin
    if not Decl.Nillable then
      AddError(E, 'Element <' + E.Name + '> is not nillable')
    else
    begin
      HasContent := E.ChildCount > 0;
      if HasContent then AddError(E, 'A nil element <' + E.Name + '> must be empty');
    end;
    Exit;
  end;
  CT := nil;
  ST := nil;
  if Decl.InlineComplex <> nil then
    CT := Decl.InlineComplex
  else if Decl.InlineSimple <> nil then
    ST := SimpleFor('', False, Decl.InlineSimple)
  else if Decl.TypeName <> '' then
  begin
    if not Decl.TypeIsXsd then CT := FSchema.FindComplex(Decl.TypeName);
    if CT = nil then
    begin
      ST := FSchema.FindSimple(Decl.TypeName, Decl.TypeIsXsd);
      if ST = nil then
      begin
        AddError(E, 'Schema error: unknown type "' + Decl.TypeName + '" for element <' + E.Name + '>');
        Exit;
      end;
    end;
  end;
  if CT <> nil then
    ValidateComplex(E, CT)
  else if ST <> nil then
  begin
    if (RootBuiltin(ST) <> xbAnyType) or (not ST.IsBuiltin) then
    begin
      for I := 0 to E.ChildCount - 1 do
        if E.Children[I].NodeType = ntElement then
        begin
          AddError(E.Children[I], 'Element <' + E.Children[I].Name + '> is not allowed: <' + E.Name + '> has a simple type');
          Break;
        end;
      for I := 0 to E.AttributeCount - 1 do
        if not (E.Attributes[I].IsNamespaceDeclaration or (E.Attributes[I].NamespaceURI = XSI_NS_URI)) then
        begin
          AddError(E.Attributes[I], 'Attribute "' + E.Attributes[I].Name + '" is not allowed on element <' + E.Name + '>');
          Break;
        end;
      Txt := E.TextContent;
      ValidateSimpleValue(E, Txt, ST, 'Element <' + E.Name + '> value');
      if Decl.HasFixed and (ApplyWhitespace(Txt, WhitespaceModeFor(ST)) <> Decl.Fixed) then
        AddError(E, 'Element <' + E.Name + '> must have the fixed value "' + Decl.Fixed + '"');
    end;
  end;
end;

function TXmlValidator.Validate(Doc: TXmlDocument): Boolean;
var
  Root: TXmlElement;
  D: TXsdElementDecl;
begin
  Clear;
  Root := Doc.DocumentElement;
  if Root = nil then
    AddError(nil, 'The document has no root element')
  else
  begin
    D := FSchema.FindGlobalElement(Root.NamespaceURI, Root.LocalName);
    if D = nil then
      AddError(Root, 'No global element declaration for root element <' + Root.Name + '>')
    else
      ValidateElement(Root, D);
  end;
  Result := FErrorCount = 0;
end;

procedure TXmlValidator.ValidateOrRaise(Doc: TXmlDocument);
var
  E: EXmlValidationException;
begin
  if not Validate(Doc) then
  begin
    E := EXmlValidationException.CreateCode(XFE_VAL_GENERIC, FErrors[0].Path + ': ' + FErrors[0].Message,
      FErrors[0].Line, FErrors[0].Column);
    E.Diagnostic := ErrorsAsText;
    raise E;
  end;
end;

end.
