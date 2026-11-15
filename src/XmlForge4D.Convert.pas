{$I XmlForge4D.inc}
unit XmlForge4D.Convert;

{ XML <-> JSON conversion.

  Standard conversion  : convenient JSON (@attributes, #text, arrays for repeated
                         elements). Does not guarantee preservation of every XML node.
  Lossless conversion  : "XML Infoset JSON" (format XmlForge4D, version 1.0). Keeps node
                         order, namespaces, CDATA, comments, PIs, DOCTYPE, whitespace and
                         declaration metadata. See docs/INFOSET_JSON.md.

  Both go through the Universal Data Model (TDataNode). }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Parser, XmlForge4D.Writer,
  XmlForge4D.Dom, XmlForge4D.DataModel, XmlForge4D.Json;

const
  INFOSET_FORMAT  = 'XmlForge4D';
  INFOSET_VERSION = '1.0';

type
  TXmlConversionMode = (cmStandard, cmLossless);
  TXmlRootMode = (rmWrap, rmUnwrap);
  TXmlRepeatMode = (rpAuto, rpAlwaysArray);
  TXmlEmptyMode = (emNull, emEmptyString, emEmptyObject);
  TXmlDateTimeMode = (dmKeepString, dmNormalizeIso);
  TXmlNamespaceHandling = (nsStrict, nsStrip);
  TXmlNullHandling = (nhEmptyElement, nhNilAttribute);

  TXmlToJsonOptions = record
    AttributePrefix: XmlString;      // '@'
    TextNodeName: XmlString;         // '#text'
    CDataNodeName: XmlString;        // '#cdata'
    CommentNodeName: XmlString;      // '#comment'
    RootElementMode: TXmlRootMode;   // rmWrap: {"person":{...}}  rmUnwrap: {...}
    RepeatedElementMode: TXmlRepeatMode;
    EmptyElementMode: TXmlEmptyMode; // emNull
    PreserveWhitespace: Boolean;     // False: text is trimmed
    PreserveComments: Boolean;       // False
    PreserveCDATA: Boolean;          // False: CDATA merges into text
    PreserveNamespaces: Boolean;     // True: keep prefixes and @xmlns attributes
    ConvertNumbers: Boolean;         // True
    ConvertBooleans: Boolean;        // True
    ConvertAttributeValues: Boolean; // False: attribute values stay strings
    ConvertNullValues: Boolean;      // True: xsi:nil="true" -> null
    DateTimeMode: TXmlDateTimeMode;  // dmKeepString
    PrettyPrint: Boolean;            // True
    IndentSize: Integer;             // 2
    LosslessMode: Boolean;           // True: produce XML Infoset JSON
    class function Default: TXmlToJsonOptions; static;
  end;

  TJsonToXmlOptions = record
    RootElementName: XmlString;      // '' = derive from JSON, else 'root'
    AttributePrefix: XmlString;      // '@'
    TextNodeName: XmlString;         // '#text'
    CDataNodeName: XmlString;        // '#cdata'
    CommentNodeName: XmlString;      // '#comment'
    ChildrenNodeName: XmlString;     // '#children'
    ArrayItemName: XmlString;        // 'item'
    PreserveArrayElements: Boolean;  // True: array -> repeated sibling elements
    NullHandling: TXmlNullHandling;  // nhEmptyElement
    PrettyPrint: Boolean;            // True (used by JsonToXmlText)
    IndentSize: Integer;             // 2
    XmlVersion: XmlString;           // '1.0'
    Encoding: XmlString;             // 'UTF-8' (declaration text)
    IncludeXMLDeclaration: Boolean;  // True
    NamespaceHandling: TXmlNamespaceHandling; // nsStrict
    ValidateElementNames: Boolean;   // True: invalid names raise; False: sanitised
    LosslessMode: Boolean;           // True: input is XML Infoset JSON
    class function Default: TJsonToXmlOptions; static;
  end;

  TXmlJsonConverter = class
  public
    { ---- XML -> JSON ---- }
    class function XmlToUdm(Doc: TXmlDocument; const Options: TXmlToJsonOptions): TDataNode;
    class function XmlToJson(Doc: TXmlDocument): XmlString; overload;
    class function XmlToJson(Doc: TXmlDocument; Mode: TXmlConversionMode): XmlString; overload;
    class function XmlToJson(Doc: TXmlDocument; const Options: TXmlToJsonOptions): XmlString; overload;
    class function XmlTextToJson(const Xml: XmlString): XmlString; overload;
    class function XmlTextToJson(const Xml: XmlString; Mode: TXmlConversionMode): XmlString; overload;
    class function XmlTextToJson(const Xml: XmlString; const Options: TXmlToJsonOptions): XmlString; overload;
    { ---- JSON -> XML ---- }
    class function UdmToXml(Node: TDataNode; const Options: TJsonToXmlOptions): TXmlDocument;
    class function JsonToXml(const Json: XmlString): TXmlDocument; overload;
    class function JsonToXml(const Json: XmlString; Mode: TXmlConversionMode): TXmlDocument; overload;
    class function JsonToXml(const Json: XmlString; const Options: TJsonToXmlOptions): TXmlDocument; overload;
    class function JsonToXmlText(const Json: XmlString): XmlString; overload;
    class function JsonToXmlText(const Json: XmlString; const Options: TJsonToXmlOptions): XmlString; overload;
    { ---- XML Infoset JSON ---- }
    class function DocumentToInfoset(Doc: TXmlDocument): TDataNode;
    class function InfosetToDocument(Infoset: TDataNode): TXmlDocument;
  end;

  { Compares two documents by XML information model (not by serialized text):
    attribute order, namespace declaration order and formatting are ignored;
    child order, text/CDATA/comment/PI/DOCTYPE content are compared exactly. }
  TXmlInfosetComparer = class
  public
    class function Equal(A, B: TXmlDocument; out Difference: XmlString;
      CompareDeclaration: Boolean = True): Boolean;
  end;

implementation

{ ---- options ---- }

class function TXmlToJsonOptions.Default: TXmlToJsonOptions;
begin
  Result.AttributePrefix := '@';
  Result.TextNodeName := '#text';
  Result.CDataNodeName := '#cdata';
  Result.CommentNodeName := '#comment';
  Result.RootElementMode := rmWrap;
  Result.RepeatedElementMode := rpAuto;
  Result.EmptyElementMode := emNull;
  Result.PreserveWhitespace := False;
  Result.PreserveComments := False;
  Result.PreserveCDATA := False;
  Result.PreserveNamespaces := True;
  Result.ConvertNumbers := True;
  Result.ConvertBooleans := True;
  Result.ConvertAttributeValues := False;
  Result.ConvertNullValues := True;
  Result.DateTimeMode := dmKeepString;
  Result.PrettyPrint := True;
  Result.IndentSize := 2;
  Result.LosslessMode := False;
end;

class function TJsonToXmlOptions.Default: TJsonToXmlOptions;
begin
  Result.RootElementName := '';
  Result.AttributePrefix := '@';
  Result.TextNodeName := '#text';
  Result.CDataNodeName := '#cdata';
  Result.CommentNodeName := '#comment';
  Result.ChildrenNodeName := '#children';
  Result.ArrayItemName := 'item';
  Result.PreserveArrayElements := True;
  Result.NullHandling := nhEmptyElement;
  Result.PrettyPrint := True;
  Result.IndentSize := 2;
  Result.XmlVersion := '1.0';
  Result.Encoding := 'UTF-8';
  Result.IncludeXMLDeclaration := True;
  Result.NamespaceHandling := nsStrict;
  Result.ValidateElementNames := True;
  Result.LosslessMode := False;
end;

procedure ConvFail(Code: Integer; const Msg: XmlString);
begin
  raise EXmlConversionException.CreateCode(Code, Msg);
end;

{ =====================================================================
  Standard XML -> UDM
  ===================================================================== }

function LooksNumeric(const S: XmlString): Boolean;
var
  I, Digits: Integer;
begin
  Result := False;
  if not JsonNumberIsValid(S) then Exit;
  Digits := 0;
  for I := 1 to System.Length(S) do
    if (S[I] >= '0') and (S[I] <= '9') then Inc(Digits);
  Result := Digits <= 15; // longer digit strings (ids, phone numbers) stay strings
end;

function NormalizeDateTime(const S: XmlString): XmlString;
var
  I: Integer;
begin
  Result := S;
  if (System.Length(S) < 19) or (S[11] <> ' ') or (S[5] <> '-') or (S[8] <> '-') or
     (S[14] <> ':') or (S[17] <> ':') then Exit;
  for I := 1 to 19 do
    case I of
      5, 8, 11, 14, 17: ;
    else
      if (S[I] < '0') or (S[I] > '9') then Exit;
    end;
  Result[11] := 'T';
end;

function ScalarFromText(const Text: XmlString; const O: TXmlToJsonOptions): TDataNode;
begin
  if O.ConvertBooleans and ((Text = 'true') or (Text = 'false')) then
    Result := TDataNode.NewBoolean(Text = 'true')
  else if O.ConvertNumbers and LooksNumeric(Text) then
    Result := TDataNode.NewNumber(Text)
  else if O.DateTimeMode = dmNormalizeIso then
    Result := TDataNode.NewString(NormalizeDateTime(Text))
  else
    Result := TDataNode.NewString(Text);
end;

procedure AddChildMember(Obj: TDataNode; const Key: XmlString; Val: TDataNode; Mode: TXmlRepeatMode);
var
  Idx: Integer;
  Arr: TDataNode;
begin
  Idx := Obj.IndexOfMember(Key);
  if Idx < 0 then
  begin
    if Mode = rpAlwaysArray then
    begin
      Arr := TDataNode.NewArray;
      Arr.Add(Val);
      Obj.AddMember(Key, Arr);
    end
    else
      Obj.AddMember(Key, Val);
  end
  else
  begin
    if Obj[Idx].Kind <> dkArray then Obj.WrapItemInArray(Idx);
    Obj[Idx].Add(Val);
  end;
end;

function StringsToMember(const Vals: array of XmlString; Count: Integer): TDataNode;
var
  I: Integer;
begin
  if Count = 1 then
    Result := TDataNode.NewString(Vals[0])
  else
  begin
    Result := TDataNode.NewArray;
    for I := 0 to Count - 1 do Result.Add(TDataNode.NewString(Vals[I]));
  end;
end;

function ElementToUdm(E: TXmlElement; const O: TXmlToJsonOptions): TDataNode;
var
  I: Integer;
  C: TXmlNode;
  A: TXmlAttribute;
  IsNil: Boolean;
  AttrCount, ElemCount: Integer;
  TextBuf: TXmlStrBuf;
  CData, Comments: array of XmlString;
  CDataCount, CommentCount: Integer;
  Txt, Key: XmlString;

  function AttrEmitted(Attr: TXmlAttribute): Boolean;
  begin
    if IsNil and (Attr.NamespaceURI = XSI_NS_URI) and (Attr.LocalName = 'nil') then
      Result := False
    else if Attr.IsNamespaceDeclaration and (not O.PreserveNamespaces) then
      Result := False
    else
      Result := True;
  end;

begin
  IsNil := False;
  if O.ConvertNullValues then
  begin
    A := E.FindAttributeNS(XSI_NS_URI, 'nil');
    if (A <> nil) and ((A.Value = 'true') or (A.Value = '1')) then IsNil := True;
  end;
  AttrCount := 0;
  for I := 0 to E.AttributeCount - 1 do
    if AttrEmitted(E.Attributes[I]) then Inc(AttrCount);

  ElemCount := 0;
  CDataCount := 0;
  CommentCount := 0;
  TextBuf := TXmlStrBuf.Create(64);
  try
    for I := 0 to E.ChildCount - 1 do
    begin
      C := E.Children[I];
      case C.NodeType of
        ntElement: Inc(ElemCount);
        ntText: TextBuf.Append(C.Value);
        ntCData:
          if O.PreserveCDATA then
          begin
            SetLength(CData, CDataCount + 1);
            CData[CDataCount] := C.Value;
            Inc(CDataCount);
          end
          else
            TextBuf.Append(C.Value);
        ntComment:
          if O.PreserveComments then
          begin
            SetLength(Comments, CommentCount + 1);
            Comments[CommentCount] := C.Value;
            Inc(CommentCount);
          end;
      end;
    end;
    Txt := TextBuf.AsString;
  finally
    TextBuf.Free;
  end;
  if not O.PreserveWhitespace then Txt := XmlTrimWhite(Txt);
  if (ElemCount > 0) and XmlIsAllWhite(Txt) then Txt := '';

  if (AttrCount = 0) and (ElemCount = 0) and (CDataCount = 0) and (CommentCount = 0) then
  begin
    if IsNil then
      Result := TDataNode.NewNull
    else if Txt = '' then
    begin
      case O.EmptyElementMode of
        emNull: Result := TDataNode.NewNull;
        emEmptyString: Result := TDataNode.NewString('');
      else
        Result := TDataNode.NewObject;
      end;
    end
    else
      Result := ScalarFromText(Txt, O);
    Exit;
  end;

  Result := TDataNode.NewObject;
  try
    for I := 0 to E.AttributeCount - 1 do
    begin
      A := E.Attributes[I];
      if not AttrEmitted(A) then Continue;
      if O.PreserveNamespaces then Key := A.Name else Key := A.LocalName;
      if O.ConvertAttributeValues then
        Result.AddMember(O.AttributePrefix + Key, ScalarFromText(A.Value, O))
      else
        Result.AddMember(O.AttributePrefix + Key, TDataNode.NewString(A.Value));
    end;
    if Txt <> '' then Result.AddMember(O.TextNodeName, ScalarFromText(Txt, O));
    if CDataCount > 0 then Result.AddMember(O.CDataNodeName, StringsToMember(CData, CDataCount));
    if CommentCount > 0 then Result.AddMember(O.CommentNodeName, StringsToMember(Comments, CommentCount));
    for I := 0 to E.ChildCount - 1 do
    begin
      C := E.Children[I];
      if C.NodeType <> ntElement then Continue;
      if O.PreserveNamespaces then Key := C.Name else Key := C.LocalName;
      AddChildMember(Result, Key, ElementToUdm(TXmlElement(C), O), O.RepeatedElementMode);
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ =====================================================================
  XML Infoset JSON (lossless)
  ===================================================================== }

function NullOrString(const S: XmlString): TDataNode;
begin
  if S = '' then Result := TDataNode.NewNull else Result := TDataNode.NewString(S);
end;

function NodeToInfoset(N: TXmlNode): TDataNode;
var
  Obj, Arr, Item, Kids: TDataNode;
  E: TXmlElement;
  A: TXmlAttribute;
  I: Integer;
  DeclPrefix: XmlString;
begin
  Obj := TDataNode.NewObject;
  try
    case N.NodeType of
      ntElement:
        begin
          E := TXmlElement(N);
          Obj.AddMember('type', TDataNode.NewString('element'));
          Obj.AddMember('name', TDataNode.NewString(E.LocalName));
          Obj.AddMember('namespaceURI', NullOrString(E.NamespaceURI));
          Obj.AddMember('prefix', NullOrString(E.Prefix));
          Arr := nil;
          for I := 0 to E.AttributeCount - 1 do
          begin
            A := E.Attributes[I];
            if not A.IsNamespaceDeclaration then Continue;
            if Arr = nil then Arr := Obj.AddMember('namespaceDeclarations', TDataNode.NewArray);
            if A.Name = 'xmlns' then DeclPrefix := '' else DeclPrefix := A.LocalName;
            Item := Arr.Add(TDataNode.NewObject);
            Item.AddMember('prefix', NullOrString(DeclPrefix));
            Item.AddMember('namespaceURI', TDataNode.NewString(A.Value));
          end;
          Arr := Obj.AddMember('attributes', TDataNode.NewArray);
          for I := 0 to E.AttributeCount - 1 do
          begin
            A := E.Attributes[I];
            if A.IsNamespaceDeclaration then Continue;
            Item := Arr.Add(TDataNode.NewObject);
            Item.AddMember('name', TDataNode.NewString(A.LocalName));
            Item.AddMember('value', TDataNode.NewString(A.Value));
            Item.AddMember('namespaceURI', NullOrString(A.NamespaceURI));
            Item.AddMember('prefix', NullOrString(A.Prefix));
          end;
          Kids := Obj.AddMember('children', TDataNode.NewArray);
          for I := 0 to E.ChildCount - 1 do Kids.Add(NodeToInfoset(E.Children[I]));
        end;
      ntText:
        begin
          Obj.AddMember('type', TDataNode.NewString('text'));
          Obj.AddMember('value', TDataNode.NewString(N.Value));
        end;
      ntCData:
        begin
          Obj.AddMember('type', TDataNode.NewString('cdata'));
          Obj.AddMember('value', TDataNode.NewString(N.Value));
        end;
      ntComment:
        begin
          Obj.AddMember('type', TDataNode.NewString('comment'));
          Obj.AddMember('value', TDataNode.NewString(N.Value));
        end;
      ntProcessingInstruction:
        begin
          Obj.AddMember('type', TDataNode.NewString('processingInstruction'));
          Obj.AddMember('target', TDataNode.NewString(N.Name));
          Obj.AddMember('value', TDataNode.NewString(N.Value));
        end;
      ntDocType:
        begin
          Obj.AddMember('type', TDataNode.NewString('doctype'));
          Obj.AddMember('name', TDataNode.NewString(N.Name));
          Obj.AddMember('publicId', NullOrString(TXmlDocType(N).PublicId));
          Obj.AddMember('systemId', NullOrString(TXmlDocType(N).SystemId));
          Obj.AddMember('internalSubset', NullOrString(TXmlDocType(N).InternalSubset));
        end;
    else
      ConvFail(XFE_CONV_UNSUPPORTED, 'Node type cannot be represented in XML Infoset JSON');
    end;
  except
    Obj.Free;
    raise;
  end;
  Result := Obj;
end;

class function TXmlJsonConverter.DocumentToInfoset(Doc: TXmlDocument): TDataNode;
var
  Root, DocObj, Decl, Kids: TDataNode;
  I: Integer;
begin
  Root := TDataNode.NewObject;
  try
    Root.AddMember('$format', TDataNode.NewString(INFOSET_FORMAT));
    Root.AddMember('$version', TDataNode.NewString(INFOSET_VERSION));
    DocObj := Root.AddMember('$document', TDataNode.NewObject);
    if Doc.HasDeclaration then
    begin
      Decl := DocObj.AddMember('xmlDeclaration', TDataNode.NewObject);
      Decl.AddMember('version', TDataNode.NewString(Doc.XmlVersion));
      Decl.AddMember('encoding', NullOrString(Doc.Encoding));
      case Doc.Standalone of
        xsYes: Decl.AddMember('standalone', TDataNode.NewString('yes'));
        xsNo: Decl.AddMember('standalone', TDataNode.NewString('no'));
      else
        Decl.AddMember('standalone', TDataNode.NewNull);
      end;
    end;
    Kids := DocObj.AddMember('children', TDataNode.NewArray);
    for I := 0 to Doc.ChildCount - 1 do Kids.Add(NodeToInfoset(Doc.Children[I]));
  except
    Root.Free;
    raise;
  end;
  Result := Root;
end;

procedure InfosetFail(const Msg: XmlString);
begin
  ConvFail(XFE_CONV_BAD_INFOSET, 'Invalid XML Infoset JSON: ' + Msg);
end;

function InfStr(Obj: TDataNode; const Key: XmlString; Required: Boolean): XmlString;
var
  M: TDataNode;
begin
  M := Obj.FindMember(Key);
  if (M = nil) or (M.Kind = dkNull) then
  begin
    if Required then InfosetFail('missing member "' + Key + '"');
    Result := '';
    Exit;
  end;
  if M.Kind <> dkString then InfosetFail('member "' + Key + '" must be a string');
  Result := M.TextValue;
end;

function InfArr(Obj: TDataNode; const Key: XmlString): TDataNode;
begin
  Result := Obj.FindMember(Key);
  if (Result <> nil) and (Result.Kind = dkNull) then Result := nil;
  if (Result <> nil) and (Result.Kind <> dkArray) then InfosetFail('member "' + Key + '" must be an array');
end;

procedure BuildInfosetChildren(Doc: TXmlDocument; Parent: TXmlNode; Kids: TDataNode);
var
  I, J: Integer;
  Obj, Arr, It: TDataNode;
  T, Pfx, QName, Uri, AName, APfx, AUri: XmlString;
  El: TXmlElement;
begin
  if Kids = nil then Exit;
  for I := 0 to Kids.Count - 1 do
  begin
    Obj := Kids[I];
    if Obj.Kind <> dkObject then InfosetFail('child nodes must be objects');
    T := InfStr(Obj, 'type', True);
    if T = 'element' then
    begin
      AName := InfStr(Obj, 'name', True);
      Pfx := InfStr(Obj, 'prefix', False);
      Uri := InfStr(Obj, 'namespaceURI', False);
      if Pfx <> '' then QName := Pfx + ':' + AName else QName := AName;
      El := nil;
      try
        El := Doc.CreateElementNS(Uri, QName);
      except
        on E: EXmlForgeException do
        begin
          InfosetFail(E.Message);
          El := nil;
        end;
      end;
      Parent.AppendChild(El);
      Arr := InfArr(Obj, 'namespaceDeclarations');
      if Arr <> nil then
        for J := 0 to Arr.Count - 1 do
        begin
          It := Arr[J];
          if It.Kind <> dkObject then InfosetFail('namespace declarations must be objects');
          APfx := InfStr(It, 'prefix', False);
          El.DeclareNamespace(APfx, InfStr(It, 'namespaceURI', True));
        end;
      Arr := InfArr(Obj, 'attributes');
      if Arr <> nil then
        for J := 0 to Arr.Count - 1 do
        begin
          It := Arr[J];
          if It.Kind <> dkObject then InfosetFail('attributes must be objects');
          AName := InfStr(It, 'name', True);
          APfx := InfStr(It, 'prefix', False);
          AUri := InfStr(It, 'namespaceURI', False);
          if APfx <> '' then AName := APfx + ':' + AName;
          try
            if AUri <> '' then
              El.SetAttributeNS(AUri, AName, InfStr(It, 'value', True))
            else
              El.SetAttribute(AName, InfStr(It, 'value', True));
          except
            on E: EXmlForgeException do InfosetFail(E.Message);
          end;
        end;
      BuildInfosetChildren(Doc, El, InfArr(Obj, 'children'));
    end
    else if T = 'text' then
      Parent.AppendChild(Doc.CreateTextNode(InfStr(Obj, 'value', True)))
    else if T = 'cdata' then
      Parent.AppendChild(Doc.CreateCDataSection(InfStr(Obj, 'value', True)))
    else if T = 'comment' then
      Parent.AppendChild(Doc.CreateComment(InfStr(Obj, 'value', True)))
    else if T = 'processingInstruction' then
      Parent.AppendChild(Doc.CreateProcessingInstruction(InfStr(Obj, 'target', True),
        InfStr(Obj, 'value', False)))
    else if T = 'doctype' then
      Parent.AppendChild(Doc.CreateDocType(InfStr(Obj, 'name', True), InfStr(Obj, 'publicId', False),
        InfStr(Obj, 'systemId', False), InfStr(Obj, 'internalSubset', False)))
    else
      InfosetFail('unknown node type "' + T + '"');
  end;
end;

class function TXmlJsonConverter.InfosetToDocument(Infoset: TDataNode): TXmlDocument;
var
  V, DocObj, Decl: TDataNode;
  Ver, St: XmlString;
  Doc: TXmlDocument;
begin
  if (Infoset = nil) or (Infoset.Kind <> dkObject) then InfosetFail('root must be an object');
  if InfStr(Infoset, '$format', True) <> INFOSET_FORMAT then
    InfosetFail('"$format" must be "' + INFOSET_FORMAT + '"');
  Ver := InfStr(Infoset, '$version', True);
  if Copy(Ver, 1, 2) <> '1.' then InfosetFail('unsupported "$version" ' + Ver + ' (supported: 1.x)');
  DocObj := Infoset.FindMember('$document');
  if (DocObj = nil) or (DocObj.Kind <> dkObject) then InfosetFail('"$document" object missing');
  Doc := TXmlDocument.Create;
  try
    Decl := DocObj.FindMember('xmlDeclaration');
    if (Decl <> nil) and (Decl.Kind = dkObject) then
    begin
      Doc.HasDeclaration := True;
      Doc.XmlVersion := InfStr(Decl, 'version', False);
      if Doc.XmlVersion = '' then Doc.XmlVersion := '1.0';
      Doc.Encoding := InfStr(Decl, 'encoding', False);
      St := InfStr(Decl, 'standalone', False);
      if St = 'yes' then Doc.Standalone := xsYes
      else if St = 'no' then Doc.Standalone := xsNo
      else Doc.Standalone := xsUnspecified;
    end
    else
      Doc.HasDeclaration := False;
    V := InfArr(DocObj, 'children');
    BuildInfosetChildren(Doc, Doc, V);
  except
    Doc.Free;
    raise;
  end;
  Result := Doc;
end;

{ =====================================================================
  Standard UDM -> XML
  ===================================================================== }

type
  TStdXmlBuilder = class
  private
    FOpts: TJsonToXmlOptions;
    FDoc: TXmlDocument;
    function IsAttrName(const Name: XmlString): Boolean;
    function FixName(const N: XmlString; IsAttr: Boolean): XmlString;
    function ScalarText(V: TDataNode; const Ctx: XmlString): XmlString;
    function BuildElement(Parent: TXmlNode; const QName: XmlString; V: TDataNode): TXmlElement;
    procedure FillElement(El: TXmlElement; V: TDataNode);
    procedure AddMemberContent(El: TXmlElement; const Name: XmlString; V: TDataNode);
    procedure AddOrderedChildren(El: TXmlElement; V: TDataNode);
    procedure AddTextish(El: TXmlElement; V: TDataNode; Kind: Integer);
  public
    constructor Create(const AOpts: TJsonToXmlOptions);
    function Build(Node: TDataNode): TXmlDocument;
  end;

constructor TStdXmlBuilder.Create(const AOpts: TJsonToXmlOptions);
begin
  inherited Create;
  FOpts := AOpts;
end;

function TStdXmlBuilder.IsAttrName(const Name: XmlString): Boolean;
begin
  Result := (FOpts.AttributePrefix <> '') and
    (Copy(Name, 1, System.Length(FOpts.AttributePrefix)) = FOpts.AttributePrefix);
end;

function TStdXmlBuilder.FixName(const N: XmlString; IsAttr: Boolean): XmlString;
var
  P: Integer;
  Tmp: XmlString;
begin
  Result := N;
  if FOpts.NamespaceHandling = nsStrip then
  begin
    P := Pos(':', Result);
    if P > 0 then Result := Copy(Result, P + 1, MaxInt);
  end;
  if XmlIsValidQName(Result) then Exit;
  if FOpts.ValidateElementNames then
  begin
    if IsAttr then
      ConvFail(XFE_CONV_BAD_NAME, 'Invalid XML attribute name "' + N + '"')
    else
      ConvFail(XFE_CONV_BAD_NAME, 'Invalid XML element name "' + N + '"');
  end;
  Tmp := XmlSanitizeName(Result, False);
  Result := Tmp;
end;

function TStdXmlBuilder.ScalarText(V: TDataNode; const Ctx: XmlString): XmlString;
begin
  if V.IsContainer then
    ConvFail(XFE_CONV_GENERIC, 'A scalar value is required for ' + Ctx);
  Result := V.AsString;
end;

procedure TStdXmlBuilder.AddTextish(El: TXmlElement; V: TDataNode; Kind: Integer);
var
  I: Integer;
  S: XmlString;
begin
  if V.Kind = dkNull then Exit;
  if V.Kind = dkArray then
  begin
    for I := 0 to V.Count - 1 do AddTextish(El, V[I], Kind);
    Exit;
  end;
  S := ScalarText(V, 'text, CDATA or comment content');
  case Kind of
    0: El.AddText(S);
    1: El.AddCData(S);
  else
    begin
      if (Pos('--', S) > 0) or ((S <> '') and (S[System.Length(S)] = '-')) then
        ConvFail(XFE_CONV_GENERIC, 'Invalid comment text: must not contain "--" or end with "-"');
      El.AddComment(S);
    end;
  end;
end;

procedure TStdXmlBuilder.AddMemberContent(El: TXmlElement; const Name: XmlString; V: TDataNode);
var
  I: Integer;
begin
  if Name = FOpts.TextNodeName then
    AddTextish(El, V, 0)
  else if Name = FOpts.CDataNodeName then
    AddTextish(El, V, 1)
  else if Name = FOpts.CommentNodeName then
    AddTextish(El, V, 2)
  else if Name = FOpts.ChildrenNodeName then
    AddOrderedChildren(El, V)
  else if (V.Kind = dkArray) and FOpts.PreserveArrayElements then
  begin
    for I := 0 to V.Count - 1 do BuildElement(El, Name, V[I]);
  end
  else
    BuildElement(El, Name, V);
end;

procedure TStdXmlBuilder.AddOrderedChildren(El: TXmlElement; V: TDataNode);
var
  I, J: Integer;
  It: TDataNode;
begin
  if V.Kind <> dkArray then
    ConvFail(XFE_CONV_GENERIC, '"' + FOpts.ChildrenNodeName + '" must be an array');
  for I := 0 to V.Count - 1 do
  begin
    It := V[I];
    case It.Kind of
      dkNull: ;
      dkObject:
        for J := 0 to It.Count - 1 do
          if not IsAttrName(It.Names[J]) then AddMemberContent(El, It.Names[J], It[J]);
      dkArray:
        ConvFail(XFE_CONV_GENERIC, 'Nested arrays are not allowed inside "' + FOpts.ChildrenNodeName + '"');
    else
      El.AddText(It.AsString);
    end;
  end;
end;

procedure TStdXmlBuilder.FillElement(El: TXmlElement; V: TDataNode);
var
  I: Integer;
  Nm, Pfx, Loc, Uri: XmlString;
begin
  case V.Kind of
    dkNull:
      if FOpts.NullHandling = nhNilAttribute then
      begin
        if not El.LookupNamespaceURI('xsi', Uri) or (Uri <> XSI_NS_URI) then
          El.DeclareNamespace('xsi', XSI_NS_URI);
        El.SetAttributeNS(XSI_NS_URI, 'xsi:nil', 'true');
      end;
    dkBoolean, dkNumber, dkString:
      El.AddText(V.AsString);
    dkArray:
      for I := 0 to V.Count - 1 do BuildElement(El, FOpts.ArrayItemName, V[I]);
    dkObject:
      begin
        for I := 0 to V.Count - 1 do
        begin
          if not IsAttrName(V.Names[I]) then Continue;
          Nm := Copy(V.Names[I], System.Length(FOpts.AttributePrefix) + 1, MaxInt);
          if (Nm = 'xmlns') or (Copy(Nm, 1, 6) = 'xmlns:') then Continue; // handled in BuildElement
          Nm := FixName(Copy(Nm, 1, MaxInt), True);
          if FOpts.NamespaceHandling = nsStrip then
            El.SetAttribute(Nm, ScalarText(V[I], 'attribute "' + Nm + '"'))
          else
          begin
            if XmlSplitQName(Nm, Pfx, Loc) and (Pfx <> '') and (Pfx <> 'xml') then
            begin
              if not El.LookupNamespaceURI(Pfx, Uri) then
                raise EXmlNamespaceException.CreateCode(XFE_NS_UNBOUND_PREFIX,
                  'Unbound namespace prefix "' + Pfx + '" on attribute "' + Nm + '"');
            end;
            El.SetAttribute(Nm, ScalarText(V[I], 'attribute "' + Nm + '"'));
          end;
        end;
        for I := 0 to V.Count - 1 do
          if not IsAttrName(V.Names[I]) then AddMemberContent(El, V.Names[I], V[I]);
      end;
  end;
end;

function TStdXmlBuilder.BuildElement(Parent: TXmlNode; const QName: XmlString;
  V: TDataNode): TXmlElement;
var
  Name, Pfx, Loc, Uri, Nm, DeclUri: XmlString;
  I: Integer;
  DeclPrefixes, DeclUris: array of XmlString;
  DeclCount: Integer;
  Found: Boolean;
begin
  Name := FixName(QName, False);
  DeclCount := 0;
  if (V.Kind = dkObject) and (FOpts.NamespaceHandling = nsStrict) then
    for I := 0 to V.Count - 1 do
    begin
      if not IsAttrName(V.Names[I]) then Continue;
      Nm := Copy(V.Names[I], System.Length(FOpts.AttributePrefix) + 1, MaxInt);
      if (Nm = 'xmlns') or (Copy(Nm, 1, 6) = 'xmlns:') then
      begin
        SetLength(DeclPrefixes, DeclCount + 1);
        SetLength(DeclUris, DeclCount + 1);
        if Nm = 'xmlns' then DeclPrefixes[DeclCount] := '' else DeclPrefixes[DeclCount] := Copy(Nm, 7, MaxInt);
        DeclUris[DeclCount] := ScalarText(V[I], 'namespace declaration');
        Inc(DeclCount);
      end;
    end;
  XmlSplitQName(Name, Pfx, Loc);
  Found := False;
  Uri := '';
  for I := 0 to DeclCount - 1 do
    if DeclPrefixes[I] = Pfx then
    begin
      Uri := DeclUris[I];
      Found := True;
    end;
  if not Found then
  begin
    if (Pfx = 'xml') then
      Uri := XML_NS_URI
    else if not Parent.LookupNamespaceURI(Pfx, DeclUri) then
      raise EXmlNamespaceException.CreateCode(XFE_NS_UNBOUND_PREFIX,
        'Unbound namespace prefix "' + Pfx + '" on element "' + Name + '"')
    else
      Uri := DeclUri;
  end;
  Result := FDoc.CreateElementNS(Uri, Name);
  Parent.AppendChild(Result);
  for I := 0 to DeclCount - 1 do Result.DeclareNamespace(DeclPrefixes[I], DeclUris[I]);
  FillElement(Result, V);
end;

function TStdXmlBuilder.Build(Node: TDataNode): TXmlDocument;
var
  RootName, Key: XmlString;
  Special: Boolean;
begin
  FDoc := TXmlDocument.Create;
  try
    FDoc.XmlVersion := FOpts.XmlVersion;
    FDoc.Encoding := FOpts.Encoding;
    FDoc.HasDeclaration := FOpts.IncludeXMLDeclaration;
    RootName := FOpts.RootElementName;
    if (Node.Kind = dkObject) and (Node.Count = 1) and (Node[0].Kind <> dkArray) then
    begin
      Key := Node.Names[0];
      Special := IsAttrName(Key) or (Key = FOpts.TextNodeName) or (Key = FOpts.CDataNodeName) or
        (Key = FOpts.CommentNodeName) or (Key = FOpts.ChildrenNodeName);
      if (not Special) and ((RootName = '') or (RootName = Key)) then
      begin
        BuildElement(FDoc, Key, Node[0]);
        Result := FDoc;
        Exit;
      end;
    end;
    if RootName = '' then RootName := 'root';
    BuildElement(FDoc, RootName, Node);
  except
    FDoc.Free;
    raise;
  end;
  Result := FDoc;
end;

{ =====================================================================
  Facade
  ===================================================================== }

class function TXmlJsonConverter.XmlToUdm(Doc: TXmlDocument; const Options: TXmlToJsonOptions): TDataNode;
var
  Root: TXmlElement;
  Val: TDataNode;
  Key: XmlString;
begin
  if Options.LosslessMode then
  begin
    Result := DocumentToInfoset(Doc);
    Exit;
  end;
  Root := Doc.DocumentElement;
  if Root = nil then ConvFail(XFE_CONV_GENERIC, 'The document has no root element');
  Val := ElementToUdm(Root, Options);
  if Options.RootElementMode = rmUnwrap then
  begin
    Result := Val;
    Exit;
  end;
  Result := TDataNode.NewObject;
  try
    if Options.PreserveNamespaces then Key := Root.Name else Key := Root.LocalName;
    Result.AddMember(Key, Val);
  except
    Val.Free;
    Result.Free;
    raise;
  end;
end;

class function TXmlJsonConverter.XmlToJson(Doc: TXmlDocument; const Options: TXmlToJsonOptions): XmlString;
var
  N: TDataNode;
begin
  N := XmlToUdm(Doc, Options);
  try
    Result := TJsonWriter.Write(N, Options.PrettyPrint, Options.IndentSize);
  finally
    N.Free;
  end;
end;

class function TXmlJsonConverter.XmlToJson(Doc: TXmlDocument): XmlString;
begin
  Result := XmlToJson(Doc, TXmlToJsonOptions.Default);
end;

class function TXmlJsonConverter.XmlToJson(Doc: TXmlDocument; Mode: TXmlConversionMode): XmlString;
var
  O: TXmlToJsonOptions;
begin
  O := TXmlToJsonOptions.Default;
  O.LosslessMode := Mode = cmLossless;
  Result := XmlToJson(Doc, O);
end;

class function TXmlJsonConverter.XmlTextToJson(const Xml: XmlString; const Options: TXmlToJsonOptions): XmlString;
var
  Doc: TXmlDocument;
begin
  Doc := TXmlDocument.LoadFromString(Xml);
  try
    Result := XmlToJson(Doc, Options);
  finally
    Doc.Free;
  end;
end;

class function TXmlJsonConverter.XmlTextToJson(const Xml: XmlString): XmlString;
begin
  Result := XmlTextToJson(Xml, TXmlToJsonOptions.Default);
end;

class function TXmlJsonConverter.XmlTextToJson(const Xml: XmlString; Mode: TXmlConversionMode): XmlString;
var
  O: TXmlToJsonOptions;
begin
  O := TXmlToJsonOptions.Default;
  O.LosslessMode := Mode = cmLossless;
  Result := XmlTextToJson(Xml, O);
end;

class function TXmlJsonConverter.UdmToXml(Node: TDataNode; const Options: TJsonToXmlOptions): TXmlDocument;
var
  B: TStdXmlBuilder;
begin
  if Options.LosslessMode then
  begin
    Result := InfosetToDocument(Node);
    Exit;
  end;
  B := TStdXmlBuilder.Create(Options);
  try
    Result := B.Build(Node);
  finally
    B.Free;
  end;
end;

class function TXmlJsonConverter.JsonToXml(const Json: XmlString; const Options: TJsonToXmlOptions): TXmlDocument;
var
  N: TDataNode;
begin
  N := TJsonParser.ParseText(Json);
  try
    Result := UdmToXml(N, Options);
  finally
    N.Free;
  end;
end;

class function TXmlJsonConverter.JsonToXml(const Json: XmlString): TXmlDocument;
begin
  Result := JsonToXml(Json, TJsonToXmlOptions.Default);
end;

class function TXmlJsonConverter.JsonToXml(const Json: XmlString; Mode: TXmlConversionMode): TXmlDocument;
var
  O: TJsonToXmlOptions;
begin
  O := TJsonToXmlOptions.Default;
  O.LosslessMode := Mode = cmLossless;
  Result := JsonToXml(Json, O);
end;

class function TXmlJsonConverter.JsonToXmlText(const Json: XmlString; const Options: TJsonToXmlOptions): XmlString;
var
  Doc: TXmlDocument;
  W: TXmlWriter;
  WO: TXmlWriterOptions;
  EncName: XmlString;
begin
  Doc := JsonToXml(Json, Options);
  try
    WO := TXmlWriterOptions.Default;
    WO.Indent := Options.PrettyPrint;
    if Options.IndentSize >= 0 then WO.IndentSize := Options.IndentSize;
    W := TXmlWriter.CreateToString(WO);
    try
      if Doc.HasDeclaration then
      begin
        if Options.LosslessMode then EncName := Doc.Encoding else EncName := Options.Encoding;
        W.WriteStartDocument(Doc.XmlVersion, EncName, Doc.Standalone);
      end;
      Doc.WriteTo(W, WO.Indent);
      W.EndDocument;
      Result := W.Text;
    finally
      W.Free;
    end;
  finally
    Doc.Free;
  end;
end;

class function TXmlJsonConverter.JsonToXmlText(const Json: XmlString): XmlString;
begin
  Result := JsonToXmlText(Json, TJsonToXmlOptions.Default);
end;

{ =====================================================================
  Information-model comparer
  ===================================================================== }

function NsDeclsEqual(A, B: TXmlElement): Boolean;
var
  I, CntA, CntB: Integer;
  X: TXmlAttribute;
  Y: TXmlAttribute;
begin
  CntA := 0;
  CntB := 0;
  Result := False;
  for I := 0 to A.AttributeCount - 1 do
  begin
    X := A.Attributes[I];
    if not X.IsNamespaceDeclaration then Continue;
    Inc(CntA);
    Y := B.FindAttribute(X.Name);
    if (Y = nil) or (Y.Value <> X.Value) then Exit;
  end;
  for I := 0 to B.AttributeCount - 1 do
    if B.Attributes[I].IsNamespaceDeclaration then Inc(CntB);
  Result := CntA = CntB;
end;

function AttrsEqual(A, B: TXmlElement; out Diff: XmlString): Boolean;
var
  I, CntA, CntB: Integer;
  X, Y: TXmlAttribute;
begin
  CntA := 0;
  CntB := 0;
  Result := False;
  for I := 0 to A.AttributeCount - 1 do
  begin
    X := A.Attributes[I];
    if X.IsNamespaceDeclaration then Continue;
    Inc(CntA);
    Y := B.FindAttributeNS(X.NamespaceURI, X.LocalName);
    if Y = nil then
    begin
      Diff := 'attribute "' + X.Name + '" missing';
      Exit;
    end;
    if Y.Value <> X.Value then
    begin
      Diff := 'attribute "' + X.Name + '" value differs';
      Exit;
    end;
    if Y.Prefix <> X.Prefix then
    begin
      Diff := 'attribute "' + X.Name + '" prefix differs';
      Exit;
    end;
  end;
  for I := 0 to B.AttributeCount - 1 do
    if not B.Attributes[I].IsNamespaceDeclaration then Inc(CntB);
  if CntA <> CntB then
  begin
    Diff := 'attribute count differs';
    Exit;
  end;
  Result := True;
end;

function CompareNodes(A, B: TXmlNode; const Path: XmlString; out Diff: XmlString): Boolean;
var
  I: Integer;
  EA, EB: TXmlElement;
  P: XmlString;
begin
  Result := False;
  if A.NodeType <> B.NodeType then
  begin
    Diff := Path + ': node type differs';
    Exit;
  end;
  case A.NodeType of
    ntElement:
      begin
        EA := TXmlElement(A);
        EB := TXmlElement(B);
        if (EA.LocalName <> EB.LocalName) or (EA.NamespaceURI <> EB.NamespaceURI) or
           (EA.Prefix <> EB.Prefix) then
        begin
          Diff := Path + ': element name/namespace/prefix differs ("' + EA.Name + '" vs "' + EB.Name + '")';
          Exit;
        end;
        if not NsDeclsEqual(EA, EB) then
        begin
          Diff := Path + ': namespace declarations differ';
          Exit;
        end;
        if not AttrsEqual(EA, EB, Diff) then
        begin
          Diff := Path + ': ' + Diff;
          Exit;
        end;
      end;
    ntText, ntCData, ntComment:
      if A.Value <> B.Value then
      begin
        Diff := Path + ': value differs';
        Exit;
      end;
    ntProcessingInstruction:
      if (A.Name <> B.Name) or (A.Value <> B.Value) then
      begin
        Diff := Path + ': processing instruction differs';
        Exit;
      end;
    ntDocType:
      if (A.Name <> B.Name) or (TXmlDocType(A).PublicId <> TXmlDocType(B).PublicId) or
         (TXmlDocType(A).SystemId <> TXmlDocType(B).SystemId) or
         (TXmlDocType(A).InternalSubset <> TXmlDocType(B).InternalSubset) then
      begin
        Diff := Path + ': DOCTYPE differs';
        Exit;
      end;
  end;
  if A.ChildCount <> B.ChildCount then
  begin
    Diff := Path + ': child count differs (' + IntToStr(A.ChildCount) + ' vs ' + IntToStr(B.ChildCount) + ')';
    Exit;
  end;
  for I := 0 to A.ChildCount - 1 do
  begin
    P := Path + '/' + A.Children[I].Name + '[' + IntToStr(I + 1) + ']';
    if not CompareNodes(A.Children[I], B.Children[I], P, Diff) then Exit;
  end;
  Result := True;
end;

class function TXmlInfosetComparer.Equal(A, B: TXmlDocument; out Difference: XmlString;
  CompareDeclaration: Boolean): Boolean;
begin
  Difference := '';
  Result := False;
  if CompareDeclaration then
  begin
    if A.HasDeclaration <> B.HasDeclaration then
    begin
      Difference := 'XML declaration presence differs';
      Exit;
    end;
    if A.HasDeclaration and ((A.XmlVersion <> B.XmlVersion) or (A.Encoding <> B.Encoding) or
       (A.Standalone <> B.Standalone)) then
    begin
      Difference := 'XML declaration differs';
      Exit;
    end;
  end;
  Result := CompareNodes(A, B, '', Difference);
end;

end.
