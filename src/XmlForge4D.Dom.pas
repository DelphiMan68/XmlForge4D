{$I XmlForge4D.inc}
unit XmlForge4D.Dom;

{ In-memory XML document model.
  Child order is stored explicitly; text, CDATA, comments, processing
  instructions and the DOCTYPE are first-class nodes; namespace
  declarations are kept as xmlns attributes (namespace URI = XMLNS_NS_URI).

  Ownership: a node is owned by its parent. Nodes created through the
  Create* factory methods that are never inserted into a tree must be freed
  by the caller (the AddElement/AddText helpers avoid this). }

interface

uses
  SysUtils, Classes, XmlForge4D.Types, XmlForge4D.Encoding, XmlForge4D.Parser,
  XmlForge4D.Writer;

type
  TXmlNodeType = (ntDocument, ntElement, ntAttribute, ntText, ntCData, ntComment,
    ntProcessingInstruction, ntDocType);

  TXmlNode = class;
  TXmlElement = class;
  TXmlAttribute = class;
  TXmlDocument = class;

  { Non-owning list of nodes (results of queries). The list itself must be freed. }
  TXmlNodeList = class
  private
    FItems: array of TXmlNode;
    FCount: Integer;
    function GetItem(Index: Integer): TXmlNode;
  public
    procedure Add(Node: TXmlNode);
    procedure Insert(Index: Integer; Node: TXmlNode);
    procedure Delete(Index: Integer);
    function IndexOf(Node: TXmlNode): Integer;
    function Remove(Node: TXmlNode): Integer;
    procedure Clear;
    property Count: Integer read FCount;
    property Items[Index: Integer]: TXmlNode read GetItem; default;
  end;

  TXmlNode = class
  private
    FOwner: TXmlDocument;
    FParent: TXmlNode;
    FChildren: TXmlNodeList;
    FLine, FColumn, FOrder: Integer;
    function GetChildCount: Integer;
    function GetChild(Index: Integer): TXmlNode;
    function GetFirstChild: TXmlNode;
    function GetLastChild: TXmlNode;
    function GetNextSibling: TXmlNode;
    function GetPreviousSibling: TXmlNode;
    function GetTextContent: XmlString;
    procedure SetTextContent(const Value: XmlString);
  protected
    function GetNodeType: TXmlNodeType; virtual; abstract;
    function GetName: XmlString; virtual;
    function GetValue: XmlString; virtual;
    procedure SetValue(const AValue: XmlString); virtual;
    function GetNamespaceURI: XmlString; virtual;
    function GetLocalName: XmlString; virtual;
    function GetPrefix: XmlString; virtual;
    procedure Changed;
    procedure CheckInsertable(Node: TXmlNode);
    procedure AddChildInternal(Node: TXmlNode);
  public
    constructor Create(AOwner: TXmlDocument);
    destructor Destroy; override;

    property NodeType: TXmlNodeType read GetNodeType;
    property Name: XmlString read GetName;               // qualified name
    property LocalName: XmlString read GetLocalName;
    property Prefix: XmlString read GetPrefix;
    property NamespaceURI: XmlString read GetNamespaceURI;
    property Value: XmlString read GetValue write SetValue;
    property TextContent: XmlString read GetTextContent write SetTextContent;
    property ParentNode: TXmlNode read FParent;
    property OwnerDocument: TXmlDocument read FOwner;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    { Internal: document-order stamp used by XPath. }
    property OrderIndex: Integer read FOrder write FOrder;

    property ChildCount: Integer read GetChildCount;
    property Children[Index: Integer]: TXmlNode read GetChild;
    property FirstChild: TXmlNode read GetFirstChild;
    property LastChild: TXmlNode read GetLastChild;
    property NextSibling: TXmlNode read GetNextSibling;
    property PreviousSibling: TXmlNode read GetPreviousSibling;
    function HasChildNodes: Boolean;
    function IndexOfChild(Node: TXmlNode): Integer;
    function IsDescendantOf(Node: TXmlNode): Boolean;

    function AppendChild(Node: TXmlNode): TXmlNode;
    function InsertBefore(Node, RefNode: TXmlNode): TXmlNode;
    { Detaches the child (caller then owns it). }
    function RemoveChild(Node: TXmlNode): TXmlNode;
    procedure DeleteChild(Node: TXmlNode);
    function ReplaceChild(NewNode, OldNode: TXmlNode): TXmlNode;
    procedure RemoveAllChildren;

    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; virtual; abstract;
    function CloneNode(Deep: Boolean = True): TXmlNode;

    function LookupNamespaceURI(const APrefix: XmlString; out Uri: XmlString): Boolean;
    function LookupPrefix(const Uri: XmlString; out APrefix: XmlString): Boolean;

    { XPath 1.0 (unprefixed names match no-namespace nodes; prefixes resolve via
      in-scope declarations of the context node). The result list must be freed. }
    function SelectNodes(const XPath: XmlString): TXmlNodeList;
    function SelectSingleNode(const XPath: XmlString): TXmlNode;
    function SelectString(const XPath: XmlString): XmlString;
    function SelectNumber(const XPath: XmlString): Double;
    function SelectBoolean(const XPath: XmlString): Boolean;

    function ToXml(Pretty: Boolean = False): XmlString;
  end;

  TXmlAttribute = class(TXmlNode)
  private
    FName, FUri, FValue: XmlString;
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
    function GetValue: XmlString; override;
    procedure SetValue(const AValue: XmlString); override;
    function GetNamespaceURI: XmlString; override;
    function GetLocalName: XmlString; override;
    function GetPrefix: XmlString; override;
  public
    constructor Create(AOwner: TXmlDocument; const AName, AUri, AValue: XmlString); reintroduce;
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
    function IsNamespaceDeclaration: Boolean;
  end;

  TXmlElement = class(TXmlNode)
  private
    FName, FUri: XmlString;
    FAttrs: TXmlNodeList;
    function GetAttributeCount: Integer;
    function GetAttribute(Index: Integer): TXmlAttribute;
    function GetAttrByName(const QName: XmlString): XmlString;
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
    function GetNamespaceURI: XmlString; override;
    function GetLocalName: XmlString; override;
    function GetPrefix: XmlString; override;
  public
    constructor Create(AOwner: TXmlDocument; const AName, AUri: XmlString); reintroduce;
    destructor Destroy; override;
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;

    property AttributeCount: Integer read GetAttributeCount;
    property Attributes[Index: Integer]: TXmlAttribute read GetAttribute;
    property AttributeValue[const QName: XmlString]: XmlString read GetAttrByName;
    function FindAttribute(const QName: XmlString): TXmlAttribute;
    function FindAttributeNS(const Uri, Local: XmlString): TXmlAttribute;
    function HasAttribute(const QName: XmlString): Boolean;
    function TryGetAttribute(const QName: XmlString; out AValue: XmlString): Boolean;
    function GetAttributeNS(const Uri, Local: XmlString): XmlString;
    procedure SetAttribute(const QName, AValue: XmlString);
    procedure SetAttributeNS(const Uri, QName, AValue: XmlString);
    function RemoveAttribute(const QName: XmlString): Boolean;
    procedure DeclareNamespace(const APrefix, Uri: XmlString);

    { Creates and appends a child element. Prefixed names are resolved against
      in-scope declarations; unprefixed names inherit the in-scope default namespace
      unless Uri is given. }
    function AddElement(const QName: XmlString; const Uri: XmlString = ''): TXmlElement;
    function AddElementWithText(const QName, Text: XmlString): TXmlElement;
    procedure AddText(const Text: XmlString);
    procedure AddCData(const Text: XmlString);
    procedure AddComment(const Text: XmlString);
    function FindChildElement(const QName: XmlString): TXmlElement;
    function FindChildElementNS(const Uri, Local: XmlString): TXmlElement;
    { Descendant search by qualified name ('*' = all). Result list must be freed. }
    function GetElementsByTagName(const QName: XmlString): TXmlNodeList;
  end;

  TXmlCharacterData = class(TXmlNode)
  private
    FValue: XmlString;
  protected
    function GetValue: XmlString; override;
    procedure SetValue(const AValue: XmlString); override;
  public
    constructor Create(AOwner: TXmlDocument; const AValue: XmlString); reintroduce;
  end;

  TXmlText = class(TXmlCharacterData)
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
    function IsWhitespace: Boolean;
  end;

  TXmlCDataSection = class(TXmlCharacterData)
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
  end;

  TXmlComment = class(TXmlCharacterData)
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
  end;

  TXmlProcessingInstruction = class(TXmlCharacterData)
  private
    FTarget: XmlString;
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    constructor Create(AOwner: TXmlDocument; const ATarget, AData: XmlString); reintroduce;
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
    property Target: XmlString read FTarget;
  end;

  TXmlDocType = class(TXmlNode)
  private
    FName, FPublicId, FSystemId, FInternalSubset: XmlString;
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    constructor Create(AOwner: TXmlDocument; const AName, APublicId, ASystemId,
      AInternalSubset: XmlString); reintroduce;
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;
    property PublicId: XmlString read FPublicId;
    property SystemId: XmlString read FSystemId;
    property InternalSubset: XmlString read FInternalSubset;
  end;

  TXmlDocument = class(TXmlNode)
  private
    FXmlVersion, FEncoding: XmlString;
    FStandalone: TXmlStandalone;
    FHasDeclaration: Boolean;
    FMutation: Integer;
    FOrderStamp: Integer;
    function GetDocumentElement: TXmlElement;
    function GetDocType: TXmlDocType;
  protected
    function GetNodeType: TXmlNodeType; override;
    function GetName: XmlString; override;
  public
    constructor Create; reintroduce;
    function CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode; override;

    property XmlVersion: XmlString read FXmlVersion write FXmlVersion;
    { Encoding named in the source declaration (informational). }
    property Encoding: XmlString read FEncoding write FEncoding;
    property Standalone: TXmlStandalone read FStandalone write FStandalone;
    property HasDeclaration: Boolean read FHasDeclaration write FHasDeclaration;
    property DocumentElement: TXmlElement read GetDocumentElement;
    property DocType: TXmlDocType read GetDocType;
    { Internal: counters used by XPath to cache document order. }
    property MutationCount: Integer read FMutation;
    property OrderStamp: Integer read FOrderStamp write FOrderStamp;

    { ---- factories (see ownership note at the top) ---- }
    function CreateElement(const QName: XmlString): TXmlElement;
    function CreateElementNS(const Uri, QName: XmlString): TXmlElement;
    function CreateAttribute(const QName: XmlString): TXmlAttribute;
    function CreateAttributeNS(const Uri, QName: XmlString): TXmlAttribute;
    function CreateTextNode(const Text: XmlString): TXmlText;
    function CreateCDataSection(const Text: XmlString): TXmlCDataSection;
    function CreateComment(const Text: XmlString): TXmlComment;
    function CreateProcessingInstruction(const Target, Data: XmlString): TXmlProcessingInstruction;
    function CreateDocType(const AName, APublicId, ASystemId, ASubset: XmlString): TXmlDocType;
    { Creates the root element (replacing nothing: raises if one exists). }
    function AddRoot(const QName: XmlString; const Uri: XmlString = ''): TXmlElement;
    { Copies a node (possibly from another document) into this document. }
    function ImportNode(Node: TXmlNode; Deep: Boolean = True): TXmlNode;

    procedure Clear;

    { ---- loading (class functions return a new document the caller owns) ---- }
    class function LoadFromFile(const FileName: string): TXmlDocument; overload;
    class function LoadFromFile(const FileName: string; const Options: TXmlParserOptions): TXmlDocument; overload;
    class function LoadFromStream(Stream: TStream): TXmlDocument; overload;
    class function LoadFromStream(Stream: TStream; const Options: TXmlParserOptions): TXmlDocument; overload;
    class function LoadFromString(const Xml: XmlString): TXmlDocument; overload;
    class function LoadFromString(const Xml: XmlString; const Options: TXmlParserOptions): TXmlDocument; overload;

    { Replace the content of this document. }
    procedure ParseFile(const FileName: string); overload;
    procedure ParseFile(const FileName: string; const Options: TXmlParserOptions); overload;
    procedure ParseStream(Stream: TStream); overload;
    procedure ParseStream(Stream: TStream; const Options: TXmlParserOptions); overload;
    procedure ParseString(const Xml: XmlString); overload;
    procedure ParseString(const Xml: XmlString; const Options: TXmlParserOptions); overload;

    { ---- saving ---- }
    procedure SaveToFile(const FileName: string); overload;
    procedure SaveToFile(const FileName: string; const Options: TXmlWriterOptions); overload;
    procedure SaveToStream(Stream: TStream); overload;
    procedure SaveToStream(Stream: TStream; const Options: TXmlWriterOptions); overload;
    procedure WriteTo(Writer: TXmlWriter; Pretty: Boolean);
  end;

  { SAX handler that builds a DOM tree. }
  TXmlDomBuilder = class(TXmlSaxHandler)
  private
    FDoc: TXmlDocument;
    FCurrent: TXmlNode;
    FPendPrefix, FPendUri: array of XmlString;
    FPendCount: Integer;
    FLastWasText: Boolean;
  public
    constructor Create(ADoc: TXmlDocument);
    procedure StartDocument(const Version, Encoding: XmlString; Standalone: TXmlStandalone;
      HasDeclaration: Boolean); override;
    procedure DocType(const Name, PublicId, SystemId, InternalSubset: XmlString); override;
    procedure StartPrefixMapping(const Prefix, Uri: XmlString); override;
    procedure StartElement(const Uri, LocalName, QName: XmlString; Attrs: TXmlSaxAttributes;
      Line, Column: Integer); override;
    procedure EndElement(const Uri, LocalName, QName: XmlString); override;
    procedure Characters(const Text: XmlString); override;
    procedure CData(const Text: XmlString); override;
    procedure Comment(const Text: XmlString); override;
    procedure ProcessingInstruction(const Target, Data: XmlString); override;
  end;

{ Writes a node (element, comment, ...) to an open writer. }
procedure XmlWriteNode(Writer: TXmlWriter; Node: TXmlNode; Pretty: Boolean);

implementation

uses
  XmlForge4D.XPath;

procedure DomError(const Msg: XmlString);
begin
  raise EXmlForgeException.CreateCode(XFE_DOM_INVALID, Msg);
end;

{ TXmlNodeList }

function TXmlNodeList.GetItem(Index: Integer): TXmlNode;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EXmlForgeException.CreateCode(XFE_DOM_INVALID, 'Node list index out of range: ' + IntToStr(Index));
  Result := FItems[Index];
end;

procedure TXmlNodeList.Add(Node: TXmlNode);
begin
  if FCount >= System.Length(FItems) then SetLength(FItems, FCount * 2 + 8);
  FItems[FCount] := Node;
  Inc(FCount);
end;

procedure TXmlNodeList.Insert(Index: Integer; Node: TXmlNode);
var
  I: Integer;
begin
  if (Index < 0) or (Index > FCount) then Index := FCount;
  if FCount >= System.Length(FItems) then SetLength(FItems, FCount * 2 + 8);
  for I := FCount downto Index + 1 do FItems[I] := FItems[I - 1];
  FItems[Index] := Node;
  Inc(FCount);
end;

procedure TXmlNodeList.Delete(Index: Integer);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= FCount) then Exit;
  for I := Index to FCount - 2 do FItems[I] := FItems[I + 1];
  Dec(FCount);
  FItems[FCount] := nil;
end;

function TXmlNodeList.IndexOf(Node: TXmlNode): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FItems[I] = Node then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TXmlNodeList.Remove(Node: TXmlNode): Integer;
begin
  Result := IndexOf(Node);
  if Result >= 0 then Delete(Result);
end;

procedure TXmlNodeList.Clear;
begin
  FCount := 0;
end;

{ TXmlNode }

constructor TXmlNode.Create(AOwner: TXmlDocument);
begin
  inherited Create;
  FOwner := AOwner;
end;

destructor TXmlNode.Destroy;
var
  I: Integer;
begin
  if FChildren <> nil then
  begin
    for I := FChildren.Count - 1 downto 0 do
    begin
      FChildren[I].FParent := nil;
      FChildren[I].Free;
    end;
    FChildren.Free;
  end;
  inherited Destroy;
end;

procedure TXmlNode.Changed;
begin
  if FOwner <> nil then Inc(FOwner.FMutation);
end;

function TXmlNode.GetName: XmlString;
begin
  Result := '';
end;

function TXmlNode.GetValue: XmlString;
begin
  Result := '';
end;

procedure TXmlNode.SetValue(const AValue: XmlString);
begin
  DomError('The value of this node type cannot be set');
end;

function TXmlNode.GetNamespaceURI: XmlString;
begin
  Result := '';
end;

function TXmlNode.GetLocalName: XmlString;
begin
  Result := GetName;
end;

function TXmlNode.GetPrefix: XmlString;
begin
  Result := '';
end;

function TXmlNode.GetChildCount: Integer;
begin
  if FChildren = nil then Result := 0 else Result := FChildren.Count;
end;

function TXmlNode.GetChild(Index: Integer): TXmlNode;
begin
  if FChildren = nil then DomError('This node has no children');
  Result := FChildren[Index];
end;

function TXmlNode.GetFirstChild: TXmlNode;
begin
  if (FChildren <> nil) and (FChildren.Count > 0) then Result := FChildren[0] else Result := nil;
end;

function TXmlNode.GetLastChild: TXmlNode;
begin
  if (FChildren <> nil) and (FChildren.Count > 0) then
    Result := FChildren[FChildren.Count - 1]
  else
    Result := nil;
end;

function TXmlNode.GetNextSibling: TXmlNode;
var
  I: Integer;
begin
  Result := nil;
  if (FParent = nil) or (FParent.FChildren = nil) then Exit;
  I := FParent.FChildren.IndexOf(Self);
  if (I >= 0) and (I + 1 < FParent.FChildren.Count) then Result := FParent.FChildren[I + 1];
end;

function TXmlNode.GetPreviousSibling: TXmlNode;
var
  I: Integer;
begin
  Result := nil;
  if (FParent = nil) or (FParent.FChildren = nil) then Exit;
  I := FParent.FChildren.IndexOf(Self);
  if I > 0 then Result := FParent.FChildren[I - 1];
end;

function TXmlNode.HasChildNodes: Boolean;
begin
  Result := GetChildCount > 0;
end;

function TXmlNode.IndexOfChild(Node: TXmlNode): Integer;
begin
  if FChildren = nil then Result := -1 else Result := FChildren.IndexOf(Node);
end;

function TXmlNode.IsDescendantOf(Node: TXmlNode): Boolean;
var
  P: TXmlNode;
begin
  P := FParent;
  while P <> nil do
  begin
    if P = Node then
    begin
      Result := True;
      Exit;
    end;
    P := P.FParent;
  end;
  Result := False;
end;

procedure TXmlNode.AddChildInternal(Node: TXmlNode);
begin
  Node.FParent := Self;
  FChildren.Add(Node);
end;

procedure TXmlNode.CheckInsertable(Node: TXmlNode);
var
  I: Integer;
begin
  if Node = nil then DomError('Cannot insert a nil node');
  if FChildren = nil then DomError('This node type cannot have child nodes');
  if (Node.NodeType = ntAttribute) or (Node.NodeType = ntDocument) then
    DomError('Attributes and documents cannot be inserted as child nodes');
  if Node.FOwner <> FOwner then
    DomError('The node belongs to another document; use ImportNode first');
  if (Node = Self) or IsDescendantOf(Node) then
    DomError('Cannot insert a node into itself or one of its descendants');
  if NodeType = ntDocument then
  begin
    case Node.NodeType of
      ntText, ntCData: DomError('Text is not allowed directly under the document');
      ntElement:
        for I := 0 to FChildren.Count - 1 do
          if (FChildren[I].NodeType = ntElement) and (FChildren[I] <> Node) then
            DomError('A document can only have one root element');
      ntDocType:
        for I := 0 to FChildren.Count - 1 do
          if (FChildren[I].NodeType = ntDocType) and (FChildren[I] <> Node) then
            DomError('A document can only have one DOCTYPE');
    end;
  end
  else if Node.NodeType = ntDocType then
    DomError('DOCTYPE can only be a child of the document');
end;

function TXmlNode.InsertBefore(Node, RefNode: TXmlNode): TXmlNode;
var
  Idx: Integer;
begin
  CheckInsertable(Node);
  if RefNode <> nil then
  begin
    if RefNode.FParent <> Self then DomError('The reference node is not a child of this node');
    if RefNode = Node then
    begin
      Result := Node;
      Exit;
    end;
  end;
  if Node.FParent <> nil then Node.FParent.RemoveChild(Node);
  if RefNode = nil then
    Idx := FChildren.Count
  else
    Idx := FChildren.IndexOf(RefNode);
  FChildren.Insert(Idx, Node);
  Node.FParent := Self;
  Changed;
  Result := Node;
end;

function TXmlNode.AppendChild(Node: TXmlNode): TXmlNode;
begin
  Result := InsertBefore(Node, nil);
end;

function TXmlNode.RemoveChild(Node: TXmlNode): TXmlNode;
begin
  if (FChildren = nil) or (Node = nil) or (Node.FParent <> Self) then
    DomError('The node is not a child of this node');
  FChildren.Remove(Node);
  Node.FParent := nil;
  Changed;
  Result := Node;
end;

procedure TXmlNode.DeleteChild(Node: TXmlNode);
begin
  RemoveChild(Node).Free;
end;

function TXmlNode.ReplaceChild(NewNode, OldNode: TXmlNode): TXmlNode;
begin
  if (OldNode = nil) or (OldNode.FParent <> Self) then DomError('The node to replace is not a child');
  if NewNode = OldNode then
  begin
    Result := OldNode;
    Exit;
  end;
  InsertBefore(NewNode, OldNode);
  Result := RemoveChild(OldNode);
end;

procedure TXmlNode.RemoveAllChildren;
var
  I: Integer;
begin
  if FChildren = nil then Exit;
  for I := FChildren.Count - 1 downto 0 do
  begin
    FChildren[I].FParent := nil;
    FChildren[I].Free;
  end;
  FChildren.Clear;
  Changed;
end;

function TXmlNode.CloneNode(Deep: Boolean): TXmlNode;
begin
  Result := CloneInto(FOwner, Deep);
end;

procedure CollectText(N: TXmlNode; B: TXmlStrBuf);
var
  I: Integer;
begin
  case N.NodeType of
    ntText, ntCData: B.Append(N.Value);
    ntElement, ntDocument:
      for I := 0 to N.ChildCount - 1 do CollectText(N.Children[I], B);
  end;
end;

function TXmlNode.GetTextContent: XmlString;
var
  B: TXmlStrBuf;
begin
  case NodeType of
    ntText, ntCData, ntComment, ntProcessingInstruction, ntAttribute:
      Result := Value;
    ntElement, ntDocument:
      begin
        B := TXmlStrBuf.Create(64);
        try
          CollectText(Self, B);
          Result := B.AsString;
        finally
          B.Free;
        end;
      end;
  else
    Result := '';
  end;
end;

procedure TXmlNode.SetTextContent(const Value: XmlString);
begin
  case NodeType of
    ntElement:
      begin
        RemoveAllChildren;
        if Value <> '' then AddChildInternal(TXmlText.Create(FOwner, Value));
        Changed;
      end;
    ntDocument, ntDocType:
      DomError('TextContent cannot be set on this node type');
  else
    SetValue(Value);
  end;
end;

function TXmlNode.LookupNamespaceURI(const APrefix: XmlString; out Uri: XmlString): Boolean;
var
  N: TXmlNode;
  A: TXmlAttribute;
  AttrName: XmlString;
begin
  Uri := '';
  if APrefix = 'xml' then
  begin
    Uri := XML_NS_URI;
    Result := True;
    Exit;
  end;
  if APrefix = '' then AttrName := 'xmlns' else AttrName := 'xmlns:' + APrefix;
  N := Self;
  if N.NodeType = ntAttribute then N := N.FParent;
  while N <> nil do
  begin
    if N.NodeType = ntElement then
    begin
      A := TXmlElement(N).FindAttribute(AttrName);
      if A <> nil then
      begin
        Uri := A.Value;
        Result := True;
        Exit;
      end;
    end;
    N := N.FParent;
  end;
  Result := APrefix = '';
end;

function TXmlNode.LookupPrefix(const Uri: XmlString; out APrefix: XmlString): Boolean;
var
  N: TXmlNode;
  E: TXmlElement;
  I: Integer;
  A: TXmlAttribute;
  Cand, Check: XmlString;
begin
  Result := False;
  APrefix := '';
  if Uri = XML_NS_URI then
  begin
    APrefix := 'xml';
    Result := True;
    Exit;
  end;
  N := Self;
  if N.NodeType = ntAttribute then N := N.FParent;
  while N <> nil do
  begin
    if N.NodeType = ntElement then
    begin
      E := TXmlElement(N);
      for I := 0 to E.AttributeCount - 1 do
      begin
        A := E.Attributes[I];
        if A.IsNamespaceDeclaration and (A.Value = Uri) then
        begin
          if A.Name = 'xmlns' then Cand := '' else Cand := A.LocalName;
          if LookupNamespaceURI(Cand, Check) and (Check = Uri) then
          begin
            APrefix := Cand;
            Result := True;
            Exit;
          end;
        end;
      end;
    end;
    N := N.FParent;
  end;
end;

function TXmlNode.SelectNodes(const XPath: XmlString): TXmlNodeList;
begin
  Result := XPathSelectNodes(Self, XPath);
end;

function TXmlNode.SelectSingleNode(const XPath: XmlString): TXmlNode;
begin
  Result := XPathSelectSingle(Self, XPath);
end;

function TXmlNode.SelectString(const XPath: XmlString): XmlString;
begin
  Result := XPathEvalString(Self, XPath);
end;

function TXmlNode.SelectNumber(const XPath: XmlString): Double;
begin
  Result := XPathEvalNumber(Self, XPath);
end;

function TXmlNode.SelectBoolean(const XPath: XmlString): Boolean;
begin
  Result := XPathEvalBoolean(Self, XPath);
end;

function TXmlNode.ToXml(Pretty: Boolean): XmlString;
var
  Opts: TXmlWriterOptions;
  W: TXmlWriter;
begin
  Opts := TXmlWriterOptions.Default;
  Opts.Indent := Pretty;
  W := TXmlWriter.CreateToString(Opts);
  try
    if NodeType = ntDocument then
    begin
      if TXmlDocument(Self).HasDeclaration then
        W.WriteStartDocument(TXmlDocument(Self).XmlVersion, '', TXmlDocument(Self).Standalone);
      TXmlDocument(Self).WriteTo(W, Pretty);
    end
    else
      XmlWriteNode(W, Self, Pretty);
    W.EndDocument;
    Result := W.Text;
  finally
    W.Free;
  end;
end;

{ TXmlAttribute }

constructor TXmlAttribute.Create(AOwner: TXmlDocument; const AName, AUri, AValue: XmlString);
begin
  inherited Create(AOwner);
  FName := AName;
  FUri := AUri;
  FValue := AValue;
end;

function TXmlAttribute.GetNodeType: TXmlNodeType;
begin
  Result := ntAttribute;
end;

function TXmlAttribute.GetName: XmlString;
begin
  Result := FName;
end;

function TXmlAttribute.GetValue: XmlString;
begin
  Result := FValue;
end;

procedure TXmlAttribute.SetValue(const AValue: XmlString);
begin
  FValue := AValue;
  Changed;
end;

function TXmlAttribute.GetNamespaceURI: XmlString;
begin
  Result := FUri;
end;

function TXmlAttribute.GetLocalName: XmlString;
var
  P: Integer;
begin
  P := Pos(':', FName);
  if P > 0 then Result := Copy(FName, P + 1, MaxInt) else Result := FName;
end;

function TXmlAttribute.GetPrefix: XmlString;
var
  P: Integer;
begin
  P := Pos(':', FName);
  if P > 0 then Result := Copy(FName, 1, P - 1) else Result := '';
end;

function TXmlAttribute.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlAttribute.Create(ADoc, FName, FUri, FValue);
end;

function TXmlAttribute.IsNamespaceDeclaration: Boolean;
begin
  Result := (FName = 'xmlns') or (Copy(FName, 1, 6) = 'xmlns:');
end;

{ TXmlElement }

constructor TXmlElement.Create(AOwner: TXmlDocument; const AName, AUri: XmlString);
begin
  inherited Create(AOwner);
  FName := AName;
  FUri := AUri;
  FChildren := TXmlNodeList.Create;
  FAttrs := TXmlNodeList.Create;
end;

destructor TXmlElement.Destroy;
var
  I: Integer;
begin
  for I := FAttrs.Count - 1 downto 0 do FAttrs[I].Free;
  FAttrs.Free;
  inherited Destroy;
end;

function TXmlElement.GetNodeType: TXmlNodeType;
begin
  Result := ntElement;
end;

function TXmlElement.GetName: XmlString;
begin
  Result := FName;
end;

function TXmlElement.GetNamespaceURI: XmlString;
begin
  Result := FUri;
end;

function TXmlElement.GetLocalName: XmlString;
var
  P: Integer;
begin
  P := Pos(':', FName);
  if P > 0 then Result := Copy(FName, P + 1, MaxInt) else Result := FName;
end;

function TXmlElement.GetPrefix: XmlString;
var
  P: Integer;
begin
  P := Pos(':', FName);
  if P > 0 then Result := Copy(FName, 1, P - 1) else Result := '';
end;

function TXmlElement.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
var
  E: TXmlElement;
  A: TXmlAttribute;
  I: Integer;
begin
  E := TXmlElement.Create(ADoc, FName, FUri);
  E.FLine := FLine;
  E.FColumn := FColumn;
  for I := 0 to FAttrs.Count - 1 do
  begin
    A := TXmlAttribute(FAttrs[I].CloneInto(ADoc, False));
    A.FParent := E;
    E.FAttrs.Add(A);
  end;
  if Deep then
    for I := 0 to FChildren.Count - 1 do
      E.AddChildInternal(FChildren[I].CloneInto(ADoc, True));
  Result := E;
end;

function TXmlElement.GetAttributeCount: Integer;
begin
  Result := FAttrs.Count;
end;

function TXmlElement.GetAttribute(Index: Integer): TXmlAttribute;
begin
  Result := TXmlAttribute(FAttrs[Index]);
end;

function TXmlElement.GetAttrByName(const QName: XmlString): XmlString;
var
  A: TXmlAttribute;
begin
  A := FindAttribute(QName);
  if A <> nil then Result := A.Value else Result := '';
end;

function TXmlElement.FindAttribute(const QName: XmlString): TXmlAttribute;
var
  I: Integer;
begin
  for I := 0 to FAttrs.Count - 1 do
    if TXmlAttribute(FAttrs[I]).FName = QName then
    begin
      Result := TXmlAttribute(FAttrs[I]);
      Exit;
    end;
  Result := nil;
end;

function TXmlElement.FindAttributeNS(const Uri, Local: XmlString): TXmlAttribute;
var
  I: Integer;
  A: TXmlAttribute;
begin
  for I := 0 to FAttrs.Count - 1 do
  begin
    A := TXmlAttribute(FAttrs[I]);
    if (A.FUri = Uri) and (A.LocalName = Local) then
    begin
      Result := A;
      Exit;
    end;
  end;
  Result := nil;
end;

function TXmlElement.HasAttribute(const QName: XmlString): Boolean;
begin
  Result := FindAttribute(QName) <> nil;
end;

function TXmlElement.TryGetAttribute(const QName: XmlString; out AValue: XmlString): Boolean;
var
  A: TXmlAttribute;
begin
  A := FindAttribute(QName);
  Result := A <> nil;
  if Result then AValue := A.Value else AValue := '';
end;

function TXmlElement.GetAttributeNS(const Uri, Local: XmlString): XmlString;
var
  A: TXmlAttribute;
begin
  A := FindAttributeNS(Uri, Local);
  if A <> nil then Result := A.Value else Result := '';
end;

procedure TXmlElement.SetAttribute(const QName, AValue: XmlString);
var
  A: TXmlAttribute;
  Pfx, Loc, Uri: XmlString;
begin
  A := FindAttribute(QName);
  if A <> nil then
  begin
    A.Value := AValue;
    Exit;
  end;
  if not XmlIsValidName(QName) then DomError('Invalid attribute name "' + QName + '"');
  Uri := '';
  if (QName = 'xmlns') or (Copy(QName, 1, 6) = 'xmlns:') then
    Uri := XMLNS_NS_URI
  else if XmlSplitQName(QName, Pfx, Loc) and (Pfx <> '') then
  begin
    if not LookupNamespaceURI(Pfx, Uri) then
      raise EXmlNamespaceException.CreateCode(XFE_NS_UNBOUND_PREFIX,
        'Unbound namespace prefix "' + Pfx + '" for attribute "' + QName + '"');
  end;
  A := TXmlAttribute.Create(FOwner, QName, Uri, AValue);
  A.FParent := Self;
  FAttrs.Add(A);
  Changed;
end;

procedure TXmlElement.SetAttributeNS(const Uri, QName, AValue: XmlString);
var
  A: TXmlAttribute;
  Pfx, Loc: XmlString;
begin
  if not XmlSplitQName(QName, Pfx, Loc) then DomError('Invalid qualified name "' + QName + '"');
  if (Uri <> '') and (Pfx = '') then
    raise EXmlNamespaceException.CreateCode(XFE_NS_INVALID,
      'A namespaced attribute requires a prefix (attributes do not use the default namespace)');
  if (Uri = '') and (Pfx <> '') then
    raise EXmlNamespaceException.CreateCode(XFE_NS_INVALID, 'A prefixed attribute requires a namespace URI');
  A := FindAttributeNS(Uri, Loc);
  if A <> nil then
  begin
    A.Value := AValue;
    Exit;
  end;
  A := TXmlAttribute.Create(FOwner, QName, Uri, AValue);
  A.FParent := Self;
  FAttrs.Add(A);
  Changed;
end;

function TXmlElement.RemoveAttribute(const QName: XmlString): Boolean;
var
  A: TXmlAttribute;
begin
  A := FindAttribute(QName);
  Result := A <> nil;
  if Result then
  begin
    FAttrs.Remove(A);
    A.Free;
    Changed;
  end;
end;

procedure TXmlElement.DeclareNamespace(const APrefix, Uri: XmlString);
begin
  if APrefix = '' then SetAttribute('xmlns', Uri) else SetAttribute('xmlns:' + APrefix, Uri);
end;

function TXmlElement.AddElement(const QName: XmlString; const Uri: XmlString): TXmlElement;
var
  Pfx, Loc, U, Cur: XmlString;
  NeedDecl: Boolean;
begin
  if not XmlSplitQName(QName, Pfx, Loc) then DomError('Invalid element name "' + QName + '"');
  U := Uri;
  NeedDecl := False;
  if U = '' then
  begin
    if not LookupNamespaceURI(Pfx, U) then
      raise EXmlNamespaceException.CreateCode(XFE_NS_UNBOUND_PREFIX,
        'Unbound namespace prefix "' + Pfx + '" for element "' + QName + '"');
  end
  else if not (LookupNamespaceURI(Pfx, Cur) and (Cur = U)) then
    NeedDecl := True;
  Result := FOwner.CreateElementNS(U, QName);
  AddChildInternal(Result);
  if NeedDecl then Result.DeclareNamespace(Pfx, U);
  Changed;
end;

function TXmlElement.AddElementWithText(const QName, Text: XmlString): TXmlElement;
begin
  Result := AddElement(QName);
  Result.AddText(Text);
end;

procedure TXmlElement.AddText(const Text: XmlString);
begin
  if Text = '' then Exit;
  AddChildInternal(TXmlText.Create(FOwner, Text));
  Changed;
end;

procedure TXmlElement.AddCData(const Text: XmlString);
begin
  AddChildInternal(TXmlCDataSection.Create(FOwner, Text));
  Changed;
end;

procedure TXmlElement.AddComment(const Text: XmlString);
begin
  AddChildInternal(TXmlComment.Create(FOwner, Text));
  Changed;
end;

function TXmlElement.FindChildElement(const QName: XmlString): TXmlElement;
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do
    if (FChildren[I].NodeType = ntElement) and (TXmlElement(FChildren[I]).FName = QName) then
    begin
      Result := TXmlElement(FChildren[I]);
      Exit;
    end;
  Result := nil;
end;

function TXmlElement.FindChildElementNS(const Uri, Local: XmlString): TXmlElement;
var
  I: Integer;
  E: TXmlElement;
begin
  for I := 0 to FChildren.Count - 1 do
    if FChildren[I].NodeType = ntElement then
    begin
      E := TXmlElement(FChildren[I]);
      if (E.FUri = Uri) and (E.LocalName = Local) then
      begin
        Result := E;
        Exit;
      end;
    end;
  Result := nil;
end;

procedure CollectByTag(E: TXmlElement; const QName: XmlString; L: TXmlNodeList);
var
  I: Integer;
  C: TXmlNode;
begin
  for I := 0 to E.ChildCount - 1 do
  begin
    C := E.Children[I];
    if C.NodeType = ntElement then
    begin
      if (QName = '*') or (C.Name = QName) then L.Add(C);
      CollectByTag(TXmlElement(C), QName, L);
    end;
  end;
end;

function TXmlElement.GetElementsByTagName(const QName: XmlString): TXmlNodeList;
begin
  Result := TXmlNodeList.Create;
  CollectByTag(Self, QName, Result);
end;

{ TXmlCharacterData and subclasses }

constructor TXmlCharacterData.Create(AOwner: TXmlDocument; const AValue: XmlString);
begin
  inherited Create(AOwner);
  FValue := AValue;
end;

function TXmlCharacterData.GetValue: XmlString;
begin
  Result := FValue;
end;

procedure TXmlCharacterData.SetValue(const AValue: XmlString);
begin
  FValue := AValue;
  Changed;
end;

function TXmlText.GetNodeType: TXmlNodeType;
begin
  Result := ntText;
end;

function TXmlText.GetName: XmlString;
begin
  Result := '#text';
end;

function TXmlText.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlText.Create(ADoc, FValue);
end;

function TXmlText.IsWhitespace: Boolean;
begin
  Result := XmlIsAllWhite(FValue);
end;

function TXmlCDataSection.GetNodeType: TXmlNodeType;
begin
  Result := ntCData;
end;

function TXmlCDataSection.GetName: XmlString;
begin
  Result := '#cdata-section';
end;

function TXmlCDataSection.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlCDataSection.Create(ADoc, FValue);
end;

function TXmlComment.GetNodeType: TXmlNodeType;
begin
  Result := ntComment;
end;

function TXmlComment.GetName: XmlString;
begin
  Result := '#comment';
end;

function TXmlComment.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlComment.Create(ADoc, FValue);
end;

constructor TXmlProcessingInstruction.Create(AOwner: TXmlDocument; const ATarget, AData: XmlString);
begin
  inherited Create(AOwner, AData);
  FTarget := ATarget;
end;

function TXmlProcessingInstruction.GetNodeType: TXmlNodeType;
begin
  Result := ntProcessingInstruction;
end;

function TXmlProcessingInstruction.GetName: XmlString;
begin
  Result := FTarget;
end;

function TXmlProcessingInstruction.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlProcessingInstruction.Create(ADoc, FTarget, FValue);
end;

constructor TXmlDocType.Create(AOwner: TXmlDocument; const AName, APublicId, ASystemId,
  AInternalSubset: XmlString);
begin
  inherited Create(AOwner);
  FName := AName;
  FPublicId := APublicId;
  FSystemId := ASystemId;
  FInternalSubset := AInternalSubset;
end;

function TXmlDocType.GetNodeType: TXmlNodeType;
begin
  Result := ntDocType;
end;

function TXmlDocType.GetName: XmlString;
begin
  Result := FName;
end;

function TXmlDocType.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
begin
  Result := TXmlDocType.Create(ADoc, FName, FPublicId, FSystemId, FInternalSubset);
end;

{ TXmlDocument }

constructor TXmlDocument.Create;
begin
  inherited Create(nil);
  FOwner := Self;
  FChildren := TXmlNodeList.Create;
  FXmlVersion := '1.0';
  FEncoding := '';
  FHasDeclaration := True;
end;

function TXmlDocument.GetNodeType: TXmlNodeType;
begin
  Result := ntDocument;
end;

function TXmlDocument.GetName: XmlString;
begin
  Result := '#document';
end;

function TXmlDocument.GetDocumentElement: TXmlElement;
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do
    if FChildren[I].NodeType = ntElement then
    begin
      Result := TXmlElement(FChildren[I]);
      Exit;
    end;
  Result := nil;
end;

function TXmlDocument.GetDocType: TXmlDocType;
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do
    if FChildren[I].NodeType = ntDocType then
    begin
      Result := TXmlDocType(FChildren[I]);
      Exit;
    end;
  Result := nil;
end;

function TXmlDocument.CloneInto(ADoc: TXmlDocument; Deep: Boolean): TXmlNode;
var
  D: TXmlDocument;
  I: Integer;
begin
  D := TXmlDocument.Create;
  D.FXmlVersion := FXmlVersion;
  D.FEncoding := FEncoding;
  D.FStandalone := FStandalone;
  D.FHasDeclaration := FHasDeclaration;
  if Deep then
    for I := 0 to FChildren.Count - 1 do
      D.AddChildInternal(FChildren[I].CloneInto(D, True));
  Result := D;
end;

function TXmlDocument.CreateElement(const QName: XmlString): TXmlElement;
begin
  Result := CreateElementNS('', QName);
end;

function TXmlDocument.CreateElementNS(const Uri, QName: XmlString): TXmlElement;
var
  Pfx, Loc: XmlString;
begin
  if not XmlSplitQName(QName, Pfx, Loc) then DomError('Invalid element name "' + QName + '"');
  if Pfx <> '' then
  begin
    if (not XmlIsValidNCName(Pfx)) or (not XmlIsValidNCName(Loc)) then
      DomError('Invalid element name "' + QName + '"');
    if Uri = '' then
      raise EXmlNamespaceException.CreateCode(XFE_NS_INVALID,
        'The prefixed element "' + QName + '" requires a namespace URI');
  end
  else if not XmlIsValidName(QName) then
    DomError('Invalid element name "' + QName + '"');
  Result := TXmlElement.Create(Self, QName, Uri);
end;

function TXmlDocument.CreateAttribute(const QName: XmlString): TXmlAttribute;
begin
  if not XmlIsValidName(QName) then DomError('Invalid attribute name "' + QName + '"');
  Result := TXmlAttribute.Create(Self, QName, '', '');
end;

function TXmlDocument.CreateAttributeNS(const Uri, QName: XmlString): TXmlAttribute;
begin
  if not XmlIsValidName(QName) then DomError('Invalid attribute name "' + QName + '"');
  Result := TXmlAttribute.Create(Self, QName, Uri, '');
end;

function TXmlDocument.CreateTextNode(const Text: XmlString): TXmlText;
begin
  Result := TXmlText.Create(Self, Text);
end;

function TXmlDocument.CreateCDataSection(const Text: XmlString): TXmlCDataSection;
begin
  Result := TXmlCDataSection.Create(Self, Text);
end;

function TXmlDocument.CreateComment(const Text: XmlString): TXmlComment;
begin
  Result := TXmlComment.Create(Self, Text);
end;

function TXmlDocument.CreateProcessingInstruction(const Target, Data: XmlString): TXmlProcessingInstruction;
begin
  if not XmlIsValidName(Target) then DomError('Invalid processing instruction target "' + Target + '"');
  Result := TXmlProcessingInstruction.Create(Self, Target, Data);
end;

function TXmlDocument.CreateDocType(const AName, APublicId, ASystemId, ASubset: XmlString): TXmlDocType;
begin
  Result := TXmlDocType.Create(Self, AName, APublicId, ASystemId, ASubset);
end;

function TXmlDocument.AddRoot(const QName: XmlString; const Uri: XmlString): TXmlElement;
var
  Pfx, Loc: XmlString;
begin
  if GetDocumentElement <> nil then DomError('The document already has a root element');
  Result := CreateElementNS(Uri, QName);
  AddChildInternal(Result);
  if Uri <> '' then
  begin
    XmlSplitQName(QName, Pfx, Loc);
    Result.DeclareNamespace(Pfx, Uri);
  end;
  Changed;
end;

function TXmlDocument.ImportNode(Node: TXmlNode; Deep: Boolean): TXmlNode;
begin
  if Node = nil then DomError('Cannot import a nil node');
  if Node.NodeType = ntDocument then DomError('Documents cannot be imported');
  Result := Node.CloneInto(Self, Deep);
end;

procedure TXmlDocument.Clear;
begin
  RemoveAllChildren;
  FXmlVersion := '1.0';
  FEncoding := '';
  FStandalone := xsUnspecified;
  FHasDeclaration := True;
end;

{ ---- loading ---- }

procedure TXmlDocument.ParseStream(Stream: TStream; const Options: TXmlParserOptions);
var
  P: TXmlParser;
  B: TXmlDomBuilder;
begin
  Clear;
  P := TXmlParser.Create(Options);
  B := TXmlDomBuilder.Create(Self);
  try
    try
      P.ParseStream(Stream, B);
    except
      Clear;
      raise;
    end;
  finally
    B.Free;
    P.Free;
  end;
end;

procedure TXmlDocument.ParseStream(Stream: TStream);
begin
  ParseStream(Stream, TXmlParserOptions.Default);
end;

procedure TXmlDocument.ParseFile(const FileName: string; const Options: TXmlParserOptions);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    ParseStream(FS, Options);
  finally
    FS.Free;
  end;
end;

procedure TXmlDocument.ParseFile(const FileName: string);
begin
  ParseFile(FileName, TXmlParserOptions.Default);
end;

procedure TXmlDocument.ParseString(const Xml: XmlString; const Options: TXmlParserOptions);
var
  P: TXmlParser;
  B: TXmlDomBuilder;
begin
  Clear;
  P := TXmlParser.Create(Options);
  B := TXmlDomBuilder.Create(Self);
  try
    try
      P.ParseString(Xml, B);
    except
      Clear;
      raise;
    end;
  finally
    B.Free;
    P.Free;
  end;
end;

procedure TXmlDocument.ParseString(const Xml: XmlString);
begin
  ParseString(Xml, TXmlParserOptions.Default);
end;

class function TXmlDocument.LoadFromFile(const FileName: string; const Options: TXmlParserOptions): TXmlDocument;
begin
  Result := TXmlDocument.Create;
  try
    Result.ParseFile(FileName, Options);
  except
    Result.Free;
    raise;
  end;
end;

class function TXmlDocument.LoadFromFile(const FileName: string): TXmlDocument;
begin
  Result := LoadFromFile(FileName, TXmlParserOptions.Default);
end;

class function TXmlDocument.LoadFromStream(Stream: TStream; const Options: TXmlParserOptions): TXmlDocument;
begin
  Result := TXmlDocument.Create;
  try
    Result.ParseStream(Stream, Options);
  except
    Result.Free;
    raise;
  end;
end;

class function TXmlDocument.LoadFromStream(Stream: TStream): TXmlDocument;
begin
  Result := LoadFromStream(Stream, TXmlParserOptions.Default);
end;

class function TXmlDocument.LoadFromString(const Xml: XmlString; const Options: TXmlParserOptions): TXmlDocument;
begin
  Result := TXmlDocument.Create;
  try
    Result.ParseString(Xml, Options);
  except
    Result.Free;
    raise;
  end;
end;

class function TXmlDocument.LoadFromString(const Xml: XmlString): TXmlDocument;
begin
  Result := LoadFromString(Xml, TXmlParserOptions.Default);
end;

{ ---- saving ---- }

procedure XmlWriteNode(Writer: TXmlWriter; Node: TXmlNode; Pretty: Boolean);
var
  I: Integer;
  E: TXmlElement;
  C: TXmlNode;
  Mixed: Boolean;
begin
  case Node.NodeType of
    ntElement:
      begin
        E := TXmlElement(Node);
        Writer.WriteStartElement(E.Name);
        for I := 0 to E.AttributeCount - 1 do
          Writer.WriteAttribute(E.Attributes[I].Name, E.Attributes[I].Value);
        Mixed := False;
        if Pretty then
          for I := 0 to E.ChildCount - 1 do
          begin
            C := E.Children[I];
            if (C.NodeType = ntCData) or
               ((C.NodeType = ntText) and (not XmlIsAllWhite(C.Value))) then
            begin
              Mixed := True;
              Break;
            end;
          end;
        for I := 0 to E.ChildCount - 1 do
        begin
          C := E.Children[I];
          if Pretty and (not Mixed) and (C.NodeType = ntText) then Continue;
          XmlWriteNode(Writer, C, Pretty);
        end;
        Writer.WriteEndElement;
      end;
    ntText: Writer.WriteText(Node.Value);
    ntCData: Writer.WriteCData(Node.Value);
    ntComment: Writer.WriteComment(Node.Value);
    ntProcessingInstruction: Writer.WriteProcessingInstruction(Node.Name, Node.Value);
    ntDocType:
      Writer.WriteDocType(Node.Name, TXmlDocType(Node).PublicId, TXmlDocType(Node).SystemId,
        TXmlDocType(Node).InternalSubset);
    ntAttribute:
      DomError('Attributes cannot be serialized on their own');
    ntDocument:
      TXmlDocument(Node).WriteTo(Writer, Pretty);
  end;
end;

procedure TXmlDocument.WriteTo(Writer: TXmlWriter; Pretty: Boolean);
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do
    XmlWriteNode(Writer, FChildren[I], Pretty);
end;

procedure TXmlDocument.SaveToStream(Stream: TStream; const Options: TXmlWriterOptions);
var
  W: TXmlWriter;
  Decl: Boolean;
begin
  W := TXmlWriter.Create(Stream, Options);
  try
    case Options.DeclarationMode of
      xdAlways: Decl := True;
      xdNever: Decl := False;
    else
      // Latin-1 / ASCII output can only be read back if the encoding is declared
      Decl := FHasDeclaration or (Options.Encoding = xeLatin1) or (Options.Encoding = xeAscii);
    end;
    if Decl then
      W.WriteStartDocument(FXmlVersion, XmlEncodingName(Options.Encoding), FStandalone);
    WriteTo(W, Options.Indent);
    W.EndDocument;
  finally
    W.Free;
  end;
end;

procedure TXmlDocument.SaveToStream(Stream: TStream);
begin
  SaveToStream(Stream, TXmlWriterOptions.Default);
end;

procedure TXmlDocument.SaveToFile(const FileName: string; const Options: TXmlWriterOptions);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(FS, Options);
  finally
    FS.Free;
  end;
end;

procedure TXmlDocument.SaveToFile(const FileName: string);
begin
  SaveToFile(FileName, TXmlWriterOptions.Default);
end;

{ TXmlDomBuilder }

constructor TXmlDomBuilder.Create(ADoc: TXmlDocument);
begin
  inherited Create;
  FDoc := ADoc;
  FCurrent := ADoc;
end;

procedure TXmlDomBuilder.StartDocument(const Version, Encoding: XmlString;
  Standalone: TXmlStandalone; HasDeclaration: Boolean);
begin
  FDoc.FXmlVersion := Version;
  FDoc.FEncoding := Encoding;
  FDoc.FStandalone := Standalone;
  FDoc.FHasDeclaration := HasDeclaration;
  FCurrent := FDoc;
end;

procedure TXmlDomBuilder.DocType(const Name, PublicId, SystemId, InternalSubset: XmlString);
begin
  FCurrent.AddChildInternal(TXmlDocType.Create(FDoc, Name, PublicId, SystemId, InternalSubset));
  FLastWasText := False;
end;

procedure TXmlDomBuilder.StartPrefixMapping(const Prefix, Uri: XmlString);
begin
  if FPendCount >= System.Length(FPendPrefix) then
  begin
    SetLength(FPendPrefix, FPendCount * 2 + 4);
    SetLength(FPendUri, FPendCount * 2 + 4);
  end;
  FPendPrefix[FPendCount] := Prefix;
  FPendUri[FPendCount] := Uri;
  Inc(FPendCount);
end;

procedure TXmlDomBuilder.StartElement(const Uri, LocalName, QName: XmlString;
  Attrs: TXmlSaxAttributes; Line, Column: Integer);
var
  E: TXmlElement;
  A: TXmlAttribute;
  I: Integer;
  AName: XmlString;
begin
  E := TXmlElement.Create(FDoc, QName, Uri);
  E.FLine := Line;
  E.FColumn := Column;
  for I := 0 to FPendCount - 1 do
  begin
    if FPendPrefix[I] = '' then AName := 'xmlns' else AName := 'xmlns:' + FPendPrefix[I];
    A := TXmlAttribute.Create(FDoc, AName, XMLNS_NS_URI, FPendUri[I]);
    A.FParent := E;
    E.FAttrs.Add(A);
  end;
  FPendCount := 0;
  for I := 0 to Attrs.Count - 1 do
  begin
    A := TXmlAttribute.Create(FDoc, Attrs.QName[I], Attrs.NamespaceURI[I], Attrs.Value[I]);
    A.FParent := E;
    E.FAttrs.Add(A);
  end;
  FCurrent.AddChildInternal(E);
  FCurrent := E;
  FLastWasText := False;
end;

procedure TXmlDomBuilder.EndElement(const Uri, LocalName, QName: XmlString);
begin
  FCurrent := FCurrent.FParent;
  FLastWasText := False;
end;

procedure TXmlDomBuilder.Characters(const Text: XmlString);
var
  T: TXmlNode;
begin
  if FLastWasText then
  begin
    T := FCurrent.GetLastChild;
    TXmlText(T).FValue := TXmlText(T).FValue + Text;
  end
  else
  begin
    FCurrent.AddChildInternal(TXmlText.Create(FDoc, Text));
    FLastWasText := True;
  end;
end;

procedure TXmlDomBuilder.CData(const Text: XmlString);
begin
  FCurrent.AddChildInternal(TXmlCDataSection.Create(FDoc, Text));
  FLastWasText := False;
end;

procedure TXmlDomBuilder.Comment(const Text: XmlString);
begin
  FCurrent.AddChildInternal(TXmlComment.Create(FDoc, Text));
  FLastWasText := False;
end;

procedure TXmlDomBuilder.ProcessingInstruction(const Target, Data: XmlString);
begin
  FCurrent.AddChildInternal(TXmlProcessingInstruction.Create(FDoc, Target, Data));
  FLastWasText := False;
end;

end.
