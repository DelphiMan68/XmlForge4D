{$I XmlForge4D.inc}
unit XmlForge4D.XPath;

{ XPath 1.0 for the XmlForge4D DOM.
  Supported: all axes except 'namespace' (returns an empty node-set), all node
  tests, predicates, unions, the complete core function library, variables,
  namespace-aware name tests. Node-sets are always in document order.

  Namespace rules: a prefixed name test is resolved with the prefixes registered
  through AddNamespace first, then with the in-scope declarations of the
  context node (for the document node: those of the root element). An unprefixed element name test matches elements in the
  namespace given by DefaultElementNamespace (default: no namespace), as
  required by XPath 1.0. }

interface

uses
  SysUtils, Classes, Math, XmlForge4D.Types, XmlForge4D.Dom;

type
  TXPathValueKind = (xvNodeSet, xvString, xvNumber, xvBoolean);
  TXmlNodeArray = array of TXmlNode;

  TXPathValue = record
    Kind: TXPathValueKind;
    Nodes: TXmlNodeArray;
    Str: XmlString;
    Num: Double;
    Bool: Boolean;
  end;

  TXPathExpression = class
  private
    FSource: XmlString;
    FRoot: TObject; // TXpNode (declared in the implementation section)
    FNsPrefix, FNsUri: array of XmlString;
    FNsCount: Integer;
    FVarNames: array of XmlString;
    FVarValues: array of TXPathValue;
    FVarCount: Integer;
    FDefaultNs: XmlString;
  public
    constructor Create(const Expression: XmlString);
    destructor Destroy; override;
    procedure AddNamespace(const Prefix, Uri: XmlString);
    procedure SetVariable(const Name: XmlString; const Value: TXPathValue);
    procedure SetVariableString(const Name, Value: XmlString);
    procedure SetVariableNumber(const Name: XmlString; Value: Double);
    procedure SetVariableBoolean(const Name: XmlString; Value: Boolean);
    function Evaluate(Context: TXmlNode): TXPathValue;
    { Result list must be freed by the caller. }
    function SelectNodes(Context: TXmlNode): TXmlNodeList;
    function SelectSingleNode(Context: TXmlNode): TXmlNode;
    function EvaluateString(Context: TXmlNode): XmlString;
    function EvaluateNumber(Context: TXmlNode): Double;
    function EvaluateBoolean(Context: TXmlNode): Boolean;
    { internal }
    function ResolvePrefix(const Prefix: XmlString; ContextNode: TXmlNode): XmlString;
    function GetVariable(const Name: XmlString): TXPathValue;
    property Source: XmlString read FSource;
    property DefaultElementNamespace: XmlString read FDefaultNs write FDefaultNs;
  end;

function XPathToString(const V: TXPathValue): XmlString;
function XPathToNumber(const V: TXPathValue): Double;
function XPathToBoolean(const V: TXPathValue): Boolean;

function XPathSelectNodes(Context: TXmlNode; const Expr: XmlString): TXmlNodeList;
function XPathSelectSingle(Context: TXmlNode; const Expr: XmlString): TXmlNode;
function XPathEvalString(Context: TXmlNode; const Expr: XmlString): XmlString;
function XPathEvalNumber(Context: TXmlNode; const Expr: XmlString): Double;
function XPathEvalBoolean(Context: TXmlNode; const Expr: XmlString): Boolean;

implementation

type
  TXpCtx = record
    Node: TXmlNode;
    Pos, Size: Integer;
    Expr: TXPathExpression;
  end;

  TXpNode = class
  public
    function Eval(const Ctx: TXpCtx): TXPathValue; virtual; abstract;
  end;

  TXpAxis = (axChild, axDescendant, axParent, axAncestor, axFollowingSibling, axPrecedingSibling,
    axFollowing, axPreceding, axAttribute, axNamespace, axSelf, axDescendantOrSelf, axAncestorOrSelf);

  TXpTest = (ttName, ttAnyName, ttPrefixAny, ttNode, ttText, ttComment, ttPI);

  TXpStep = class
  public
    Axis: TXpAxis;
    Test: TXpTest;
    Prefix, Local, PITarget: XmlString;
    Preds: array of TXpNode;
    destructor Destroy; override;
  end;

  TXpPath = class(TXpNode)
  public
    Base: TXpNode;
    Absolute: Boolean;
    Steps: array of TXpStep;
    destructor Destroy; override;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpFilter = class(TXpNode)
  public
    Primary: TXpNode;
    Preds: array of TXpNode;
    destructor Destroy; override;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpLiteral = class(TXpNode)
  public
    Str: XmlString;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpNumber = class(TXpNode)
  public
    Num: Double;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpVar = class(TXpNode)
  public
    Name: XmlString;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpOp = (opOr, opAnd, opEq, opNeq, opLt, opLe, opGt, opGe, opAdd, opSub, opMul, opDiv, opMod, opUnion);

  TXpBinary = class(TXpNode)
  public
    Op: TXpOp;
    L, R: TXpNode;
    destructor Destroy; override;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpNeg = class(TXpNode)
  public
    E: TXpNode;
    destructor Destroy; override;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

  TXpFunc = class(TXpNode)
  private
    procedure CheckArgs(MinArgs, MaxArgs: Integer);
    function ArgStr(Idx: Integer; const Ctx: TXpCtx): XmlString;
    function ArgNum(Idx: Integer; const Ctx: TXpCtx): Double;
    function ArgNodes(Idx: Integer; const Ctx: TXpCtx): TXmlNodeArray;
    function ArgOrContextString(const Ctx: TXpCtx): XmlString;
  public
    Name: XmlString;
    ArgList: array of TXpNode;
    destructor Destroy; override;
    function Eval(const Ctx: TXpCtx): TXPathValue; override;
  end;

procedure XPathFail(const Msg: XmlString; Pos: Integer = 0);
begin
  if Pos > 0 then
    raise EXmlXPathException.CreateCode(XFE_XPATH_SYNTAX, Msg + ' (at position ' + IntToStr(Pos) + ')')
  else
    raise EXmlXPathException.CreateCode(XFE_XPATH_EVAL, Msg);
end;

{ ---------------- value helpers ---------------- }

function MakeStr(const S: XmlString): TXPathValue;
begin
  Result.Kind := xvString;
  Result.Str := S;
  Result.Num := 0;
  Result.Bool := False;
  Result.Nodes := nil;
end;

function MakeNum(N: Double): TXPathValue;
begin
  Result.Kind := xvNumber;
  Result.Num := N;
  Result.Str := '';
  Result.Bool := False;
  Result.Nodes := nil;
end;

function MakeBool(B: Boolean): TXPathValue;
begin
  Result.Kind := xvBoolean;
  Result.Bool := B;
  Result.Str := '';
  Result.Num := 0;
  Result.Nodes := nil;
end;

function MakeNodes(const N: TXmlNodeArray): TXPathValue;
begin
  Result.Kind := xvNodeSet;
  Result.Nodes := N;
  Result.Str := '';
  Result.Num := 0;
  Result.Bool := False;
end;

function NodeStringValue(N: TXmlNode): XmlString;
begin
  Result := N.TextContent;
end;

function StringToNumber(const S: XmlString): Double;
var
  T: XmlString;
  I, Digits: Integer;
  Dots: Integer;
begin
  Result := NaN;
  T := XmlTrimWhite(S);
  if T = '' then Exit;
  I := 1;
  if T[1] = '-' then Inc(I);
  Digits := 0;
  Dots := 0;
  while I <= System.Length(T) do
  begin
    if (T[I] >= '0') and (T[I] <= '9') then Inc(Digits)
    else if T[I] = '.' then Inc(Dots)
    else Exit;
    Inc(I);
  end;
  if (Digits = 0) or (Dots > 1) then Exit;
  if not XmlTryParseFloat(T, Result) then Result := NaN;
end;

function XPathToString(const V: TXPathValue): XmlString;
begin
  case V.Kind of
    xvString: Result := V.Str;
    xvNumber: Result := XmlFloatToStr(V.Num);
    xvBoolean: if V.Bool then Result := 'true' else Result := 'false';
  else
    if System.Length(V.Nodes) > 0 then Result := NodeStringValue(V.Nodes[0]) else Result := '';
  end;
end;

function XPathToNumber(const V: TXPathValue): Double;
begin
  case V.Kind of
    xvNumber: Result := V.Num;
    xvBoolean: if V.Bool then Result := 1 else Result := 0;
  else
    Result := StringToNumber(XPathToString(V));
  end;
end;

function XPathToBoolean(const V: TXPathValue): Boolean;
begin
  case V.Kind of
    xvBoolean: Result := V.Bool;
    xvNumber: Result := (not IsNan(V.Num)) and (V.Num <> 0);
    xvString: Result := V.Str <> '';
  else
    Result := System.Length(V.Nodes) > 0;
  end;
end;

{ ---------------- node buffers, ordering ---------------- }

type
  TNodeBuf = record
    Items: TXmlNodeArray;
    Count: Integer;
  end;

procedure BufAdd(var B: TNodeBuf; N: TXmlNode);
begin
  if B.Count >= System.Length(B.Items) then SetLength(B.Items, B.Count * 2 + 8);
  B.Items[B.Count] := N;
  Inc(B.Count);
end;

procedure AddDescendants(N: TXmlNode; var B: TNodeBuf);
var
  I: Integer;
  C: TXmlNode;
begin
  for I := 0 to N.ChildCount - 1 do
  begin
    C := N.Children[I];
    BufAdd(B, C);
    if C.ChildCount > 0 then AddDescendants(C, B);
  end;
end;

procedure NumberTree(N: TXmlNode; var Counter: Integer);
var
  I: Integer;
begin
  N.OrderIndex := Counter;
  Inc(Counter);
  if N.NodeType = ntElement then
    for I := 0 to TXmlElement(N).AttributeCount - 1 do
    begin
      TXmlElement(N).Attributes[I].OrderIndex := Counter;
      Inc(Counter);
    end;
  for I := 0 to N.ChildCount - 1 do NumberTree(N.Children[I], Counter);
end;

procedure EnsureOrder(Context: TXmlNode);
var
  Root: TXmlNode;
  Counter: Integer;
  Doc: TXmlDocument;
begin
  Root := Context;
  while Root.ParentNode <> nil do Root := Root.ParentNode;
  Counter := 0;
  if Root is TXmlDocument then
  begin
    Doc := TXmlDocument(Root);
    if Doc.OrderStamp = Doc.MutationCount + 1 then Exit;
    NumberTree(Root, Counter);
    Doc.OrderStamp := Doc.MutationCount + 1;
  end
  else
    NumberTree(Root, Counter);
end;

procedure SortUnique(var A: TXmlNodeArray);
var
  N, I, Width, Lo, Mid, Hi, P, Q, K: Integer;
  Sorted: Boolean;
  Tmp: TXmlNodeArray;
begin
  N := System.Length(A);
  if N < 2 then Exit;
  Sorted := True;
  for I := 1 to N - 1 do
    if A[I - 1].OrderIndex >= A[I].OrderIndex then
    begin
      Sorted := False;
      Break;
    end;
  if Sorted then Exit;
  SetLength(Tmp, N);
  Width := 1;
  while Width < N do
  begin
    Lo := 0;
    while Lo < N do
    begin
      Mid := Lo + Width;
      if Mid > N then Mid := N;
      Hi := Lo + 2 * Width;
      if Hi > N then Hi := N;
      P := Lo;
      Q := Mid;
      K := Lo;
      while (P < Mid) and (Q < Hi) do
      begin
        if A[P].OrderIndex <= A[Q].OrderIndex then
        begin
          Tmp[K] := A[P];
          Inc(P);
        end
        else
        begin
          Tmp[K] := A[Q];
          Inc(Q);
        end;
        Inc(K);
      end;
      while P < Mid do
      begin
        Tmp[K] := A[P];
        Inc(P);
        Inc(K);
      end;
      while Q < Hi do
      begin
        Tmp[K] := A[Q];
        Inc(Q);
        Inc(K);
      end;
      Lo := Lo + 2 * Width;
    end;
    for I := 0 to N - 1 do A[I] := Tmp[I];
    Width := Width * 2;
  end;
  K := 1;
  for I := 1 to N - 1 do
    if A[I] <> A[K - 1] then
    begin
      A[K] := A[I];
      Inc(K);
    end;
  SetLength(A, K);
end;

{ ---------------- axes ---------------- }

procedure CollectAxis(Axis: TXpAxis; N: TXmlNode; var B: TNodeBuf);
var
  I, J, Idx: Integer;
  P, Cur, Base: TXmlNode;
  Tmp: TNodeBuf;
  E: TXmlElement;
begin
  case Axis of
    axChild:
      for I := 0 to N.ChildCount - 1 do BufAdd(B, N.Children[I]);
    axDescendant:
      AddDescendants(N, B);
    axDescendantOrSelf:
      begin
        BufAdd(B, N);
        AddDescendants(N, B);
      end;
    axSelf:
      BufAdd(B, N);
    axParent:
      if N.ParentNode <> nil then BufAdd(B, N.ParentNode);
    axAncestor, axAncestorOrSelf:
      begin
        if Axis = axAncestorOrSelf then BufAdd(B, N);
        P := N.ParentNode;
        while P <> nil do
        begin
          BufAdd(B, P);
          P := P.ParentNode;
        end;
      end;
    axFollowingSibling:
      if (N.NodeType <> ntAttribute) and (N.ParentNode <> nil) then
      begin
        P := N.ParentNode;
        Idx := P.IndexOfChild(N);
        for I := Idx + 1 to P.ChildCount - 1 do BufAdd(B, P.Children[I]);
      end;
    axPrecedingSibling:
      if (N.NodeType <> ntAttribute) and (N.ParentNode <> nil) then
      begin
        P := N.ParentNode;
        Idx := P.IndexOfChild(N);
        for I := Idx - 1 downto 0 do BufAdd(B, P.Children[I]);
      end;
    axAttribute:
      if N.NodeType = ntElement then
      begin
        E := TXmlElement(N);
        for I := 0 to E.AttributeCount - 1 do
          if not E.Attributes[I].IsNamespaceDeclaration then BufAdd(B, E.Attributes[I]);
      end;
    axFollowing:
      begin
        Base := N;
        if N.NodeType = ntAttribute then
        begin
          Base := N.ParentNode;
          if Base <> nil then AddDescendants(Base, B);
        end;
        Cur := Base;
        while Cur <> nil do
        begin
          P := Cur.ParentNode;
          if P <> nil then
          begin
            Idx := P.IndexOfChild(Cur);
            for J := Idx + 1 to P.ChildCount - 1 do
            begin
              BufAdd(B, P.Children[J]);
              AddDescendants(P.Children[J], B);
            end;
          end;
          Cur := P;
        end;
      end;
    axPreceding:
      begin
        Base := N;
        if N.NodeType = ntAttribute then Base := N.ParentNode;
        Cur := Base;
        while Cur <> nil do
        begin
          P := Cur.ParentNode;
          if P <> nil then
          begin
            Idx := P.IndexOfChild(Cur);
            for J := Idx - 1 downto 0 do
            begin
              Tmp.Count := 0;
              BufAdd(Tmp, P.Children[J]);
              AddDescendants(P.Children[J], Tmp);
              for I := Tmp.Count - 1 downto 0 do BufAdd(B, Tmp.Items[I]);
            end;
          end;
          Cur := P;
        end;
      end;
    axNamespace: ;
  end;
end;

function IsReverseAxis(Axis: TXpAxis): Boolean;
begin
  Result := Axis in [axAncestor, axAncestorOrSelf, axPrecedingSibling, axPreceding];
end;

{ ---------------- predicates and steps ---------------- }

procedure ApplyPredicates(const Preds: array of TXpNode; var Nodes: TXmlNodeArray; const Ctx: TXpCtx);
var
  P, I, K, Size: Integer;
  C: TXpCtx;
  V: TXPathValue;
  Keep: Boolean;
  Res: TXmlNodeArray;
begin
  for P := 0 to System.Length(Preds) - 1 do
  begin
    Size := System.Length(Nodes);
    SetLength(Res, Size);
    K := 0;
    C := Ctx;
    C.Size := Size;
    for I := 0 to Size - 1 do
    begin
      C.Node := Nodes[I];
      C.Pos := I + 1;
      V := Preds[P].Eval(C);
      if V.Kind = xvNumber then
        Keep := (not IsNan(V.Num)) and (V.Num = C.Pos)
      else
        Keep := XPathToBoolean(V);
      if Keep then
      begin
        Res[K] := Nodes[I];
        Inc(K);
      end;
    end;
    SetLength(Res, K);
    Nodes := Res;
    Res := nil;
  end;
end;

function MatchTest(Step: TXpStep; N: TXmlNode; Principal: TXmlNodeType; const ExpectedUri: XmlString): Boolean;
begin
  case Step.Test of
    ttNode: Result := True;
    ttText: Result := (N.NodeType = ntText) or (N.NodeType = ntCData);
    ttComment: Result := N.NodeType = ntComment;
    ttPI: Result := (N.NodeType = ntProcessingInstruction) and
      ((Step.PITarget = '') or (N.Name = Step.PITarget));
    ttAnyName: Result := N.NodeType = Principal;
    ttPrefixAny: Result := (N.NodeType = Principal) and (N.NamespaceURI = ExpectedUri);
    ttName: Result := (N.NodeType = Principal) and (N.LocalName = Step.Local) and
      (N.NamespaceURI = ExpectedUri);
  else
    Result := False;
  end;
end;

function EvalStep(Step: TXpStep; const Input: TXmlNodeArray; const Ctx: TXpCtx): TXmlNodeArray;
var
  I, J, K: Integer;
  B: TNodeBuf;
  Cand: TXmlNodeArray;
  Out_: TNodeBuf;
  Principal: TXmlNodeType;
  Uri: XmlString;
  C: TXpCtx;
begin
  Out_.Count := 0;
  if Step.Axis = axAttribute then Principal := ntAttribute else Principal := ntElement;
  C := Ctx;
  for I := 0 to System.Length(Input) - 1 do
  begin
    Uri := '';
    if Step.Test in [ttName, ttPrefixAny] then
    begin
      if Step.Prefix <> '' then
        Uri := Ctx.Expr.ResolvePrefix(Step.Prefix, Input[I])
      else if (Principal = ntElement) then
        Uri := Ctx.Expr.DefaultElementNamespace;
    end;
    B.Count := 0;
    CollectAxis(Step.Axis, Input[I], B);
    SetLength(Cand, B.Count);
    K := 0;
    for J := 0 to B.Count - 1 do
      if MatchTest(Step, B.Items[J], Principal, Uri) then
      begin
        Cand[K] := B.Items[J];
        Inc(K);
      end;
    SetLength(Cand, K);
    if System.Length(Step.Preds) > 0 then
    begin
      C.Node := Input[I];
      ApplyPredicates(Step.Preds, Cand, C);
    end;
    for J := 0 to System.Length(Cand) - 1 do BufAdd(Out_, Cand[J]);
  end;
  SetLength(Out_.Items, Out_.Count);
  Result := Out_.Items;
  if (System.Length(Input) > 1) or IsReverseAxis(Step.Axis) then SortUnique(Result);
end;

{ ---------------- AST destructors ---------------- }

destructor TXpStep.Destroy;
var
  I: Integer;
begin
  for I := 0 to System.Length(Preds) - 1 do Preds[I].Free;
  inherited Destroy;
end;

destructor TXpPath.Destroy;
var
  I: Integer;
begin
  Base.Free;
  for I := 0 to System.Length(Steps) - 1 do Steps[I].Free;
  inherited Destroy;
end;

destructor TXpFilter.Destroy;
var
  I: Integer;
begin
  Primary.Free;
  for I := 0 to System.Length(Preds) - 1 do Preds[I].Free;
  inherited Destroy;
end;

destructor TXpBinary.Destroy;
begin
  L.Free;
  R.Free;
  inherited Destroy;
end;

destructor TXpNeg.Destroy;
begin
  E.Free;
  inherited Destroy;
end;

destructor TXpFunc.Destroy;
var
  I: Integer;
begin
  for I := 0 to System.Length(ArgList) - 1 do ArgList[I].Free;
  inherited Destroy;
end;

{ ---------------- evaluation ---------------- }

function TopAncestor(N: TXmlNode): TXmlNode;
begin
  Result := N;
  while Result.ParentNode <> nil do Result := Result.ParentNode;
end;

function TXpPath.Eval(const Ctx: TXpCtx): TXPathValue;
var
  Cur, Next: TXmlNodeArray;
  V: TXPathValue;
  I: Integer;
begin
  if Base <> nil then
  begin
    V := Base.Eval(Ctx);
    if V.Kind <> xvNodeSet then XPathFail('A path step can only be applied to a node-set');
    Cur := V.Nodes;
  end
  else if Absolute then
  begin
    SetLength(Cur, 1);
    Cur[0] := TopAncestor(Ctx.Node);
  end
  else
  begin
    SetLength(Cur, 1);
    Cur[0] := Ctx.Node;
  end;
  for I := 0 to System.Length(Steps) - 1 do
  begin
    // never pass the variable that receives the result as a const array argument:
    // the callee's result initialisation would free the array it is still reading
    Next := EvalStep(Steps[I], Cur, Ctx);
    Cur := Next;
  end;
  Result := MakeNodes(Cur);
end;

function TXpFilter.Eval(const Ctx: TXpCtx): TXPathValue;
var
  V: TXPathValue;
  Nodes: TXmlNodeArray;
begin
  V := Primary.Eval(Ctx);
  if System.Length(Preds) = 0 then
  begin
    Result := V;
    Exit;
  end;
  if V.Kind <> xvNodeSet then XPathFail('Predicates can only be applied to node-sets');
  Nodes := V.Nodes;
  ApplyPredicates(Preds, Nodes, Ctx);
  Result := MakeNodes(Nodes);
end;

function TXpLiteral.Eval(const Ctx: TXpCtx): TXPathValue;
begin
  Result := MakeStr(Str);
end;

function TXpNumber.Eval(const Ctx: TXpCtx): TXPathValue;
begin
  Result := MakeNum(Num);
end;

function TXpVar.Eval(const Ctx: TXpCtx): TXPathValue;
begin
  Result := Ctx.Expr.GetVariable(Name);
end;

function TXpNeg.Eval(const Ctx: TXpCtx): TXPathValue;
begin
  Result := MakeNum(-XPathToNumber(E.Eval(Ctx)));
end;

function CmpNum(Op: TXpOp; A, B: Double): Boolean;
begin
  if IsNan(A) or IsNan(B) then
  begin
    Result := Op = opNeq;
    Exit;
  end;
  case Op of
    opEq: Result := A = B;
    opNeq: Result := A <> B;
    opLt: Result := A < B;
    opLe: Result := A <= B;
    opGt: Result := A > B;
  else
    Result := A >= B;
  end;
end;

function CmpStr(Op: TXpOp; const A, B: XmlString): Boolean;
begin
  if Op = opEq then Result := A = B else Result := A <> B;
end;

function CmpAtoms(Op: TXpOp; const SA, SB: XmlString; NumMode: Boolean): Boolean;
begin
  if (Op in [opEq, opNeq]) and (not NumMode) then
    Result := CmpStr(Op, SA, SB)
  else
    Result := CmpNum(Op, StringToNumber(SA), StringToNumber(SB));
end;

function Compare(Op: TXpOp; const A, B: TXPathValue): Boolean;
var
  I, J: Integer;
  Eq: Boolean;
  BA, BB: Boolean;
begin
  Result := False;
  Eq := Op in [opEq, opNeq];
  if (A.Kind = xvNodeSet) and (B.Kind = xvNodeSet) then
  begin
    for I := 0 to System.Length(A.Nodes) - 1 do
      for J := 0 to System.Length(B.Nodes) - 1 do
        if CmpAtoms(Op, NodeStringValue(A.Nodes[I]), NodeStringValue(B.Nodes[J]), False) then
        begin
          Result := True;
          Exit;
        end;
  end
  else if A.Kind = xvNodeSet then
  begin
    case B.Kind of
      xvBoolean:
        begin
          BA := System.Length(A.Nodes) > 0;
          if Eq then Result := (BA = B.Bool) = (Op = opEq)
          else Result := CmpNum(Op, Ord(BA), Ord(B.Bool));
        end;
      xvNumber:
        for I := 0 to System.Length(A.Nodes) - 1 do
          if CmpNum(Op, StringToNumber(NodeStringValue(A.Nodes[I])), B.Num) then
          begin
            Result := True;
            Exit;
          end;
    else
      for I := 0 to System.Length(A.Nodes) - 1 do
        if CmpAtoms(Op, NodeStringValue(A.Nodes[I]), B.Str, False) then
        begin
          Result := True;
          Exit;
        end;
    end;
  end
  else if B.Kind = xvNodeSet then
  begin
    case A.Kind of
      xvBoolean:
        begin
          BB := System.Length(B.Nodes) > 0;
          if Eq then Result := (BB = A.Bool) = (Op = opEq)
          else Result := CmpNum(Op, Ord(A.Bool), Ord(BB));
        end;
      xvNumber:
        for J := 0 to System.Length(B.Nodes) - 1 do
          if CmpNum(Op, A.Num, StringToNumber(NodeStringValue(B.Nodes[J]))) then
          begin
            Result := True;
            Exit;
          end;
    else
      for J := 0 to System.Length(B.Nodes) - 1 do
        if CmpAtoms(Op, A.Str, NodeStringValue(B.Nodes[J]), False) then
        begin
          Result := True;
          Exit;
        end;
    end;
  end
  else if Eq then
  begin
    if (A.Kind = xvBoolean) or (B.Kind = xvBoolean) then
      Result := (XPathToBoolean(A) = XPathToBoolean(B)) = (Op = opEq)
    else if (A.Kind = xvNumber) or (B.Kind = xvNumber) then
      Result := CmpNum(Op, XPathToNumber(A), XPathToNumber(B))
    else
      Result := CmpStr(Op, XPathToString(A), XPathToString(B));
  end
  else
    Result := CmpNum(Op, XPathToNumber(A), XPathToNumber(B));
end;

function DivX(A, B: Double): Double;
begin
  if B = 0 then
  begin
    if IsNan(A) or (A = 0) then Result := NaN
    else if A > 0 then Result := Infinity
    else Result := NegInfinity;
  end
  else
    Result := A / B;
end;

function ModX(A, B: Double): Double;
begin
  if IsNan(A) or IsNan(B) or IsInfinite(A) or (B = 0) then
    Result := NaN
  else if IsInfinite(B) then
    Result := A
  else
    Result := A - B * Int(A / B);
end;

function TXpBinary.Eval(const Ctx: TXpCtx): TXPathValue;
var
  VA, VB: TXPathValue;
  A, B: Double;
  Nodes: TXmlNodeArray;
  I, N: Integer;
begin
  case Op of
    opOr:
      begin
        Result := MakeBool(XPathToBoolean(L.Eval(Ctx)) or XPathToBoolean(R.Eval(Ctx)));
        Exit;
      end;
    opAnd:
      begin
        if not XPathToBoolean(L.Eval(Ctx)) then Result := MakeBool(False)
        else Result := MakeBool(XPathToBoolean(R.Eval(Ctx)));
        Exit;
      end;
  end;
  VA := L.Eval(Ctx);
  VB := R.Eval(Ctx);
  case Op of
    opEq, opNeq, opLt, opLe, opGt, opGe:
      Result := MakeBool(Compare(Op, VA, VB));
    opUnion:
      begin
        if (VA.Kind <> xvNodeSet) or (VB.Kind <> xvNodeSet) then
          XPathFail('The union operator requires node-set operands');
        N := System.Length(VA.Nodes);
        SetLength(Nodes, N + System.Length(VB.Nodes));
        for I := 0 to N - 1 do Nodes[I] := VA.Nodes[I];
        for I := 0 to System.Length(VB.Nodes) - 1 do Nodes[N + I] := VB.Nodes[I];
        SortUnique(Nodes);
        Result := MakeNodes(Nodes);
      end;
  else
    begin
      A := XPathToNumber(VA);
      B := XPathToNumber(VB);
      case Op of
        opAdd: Result := MakeNum(A + B);
        opSub: Result := MakeNum(A - B);
        opMul: Result := MakeNum(A * B);
        opDiv: Result := MakeNum(DivX(A, B));
      else
        Result := MakeNum(ModX(A, B));
      end;
    end;
  end;
end;

{ ---------------- function library ---------------- }

function FloorD(X: Double): Double;
begin
  Result := Int(X);
  if (X < 0) and (Result <> X) then Result := Result - 1;
end;

function CeilD(X: Double): Double;
begin
  Result := Int(X);
  if (X > 0) and (Result <> X) then Result := Result + 1;
end;

function RoundX(X: Double): Double;
begin
  if IsNan(X) or IsInfinite(X) then Result := X
  else Result := FloorD(X + 0.5);
end;

function NormalizeSpace(const S: XmlString): XmlString;
var
  B: TXmlStrBuf;
  I: Integer;
  InWs, Started: Boolean;
begin
  B := TXmlStrBuf.Create(System.Length(S) + 1);
  try
    InWs := False;
    Started := False;
    for I := 1 to System.Length(S) do
    begin
      if XmlIsWhite(Ord(S[I])) then
        InWs := True
      else
      begin
        if InWs and Started then B.Append(' ');
        InWs := False;
        Started := True;
        B.AppendChar(S[I]);
      end;
    end;
    Result := B.AsString;
  finally
    B.Free;
  end;
end;

function FirstNodeOrContext(F: TXpFunc; const Ctx: TXpCtx; ArgIdx: Integer): TXmlNode;
var
  V: TXPathValue;
begin
  if System.Length(F.ArgList) > ArgIdx then
  begin
    V := F.ArgList[ArgIdx].Eval(Ctx);
    if V.Kind <> xvNodeSet then XPathFail('Function ' + F.Name + '() requires a node-set argument');
    if System.Length(V.Nodes) > 0 then Result := V.Nodes[0] else Result := nil;
  end
  else
    Result := Ctx.Node;
end;

procedure TXpFunc.CheckArgs(MinArgs, MaxArgs: Integer);
var
  Cnt: Integer;
begin
  Cnt := System.Length(ArgList);
  if (Cnt < MinArgs) or ((MaxArgs >= 0) and (Cnt > MaxArgs)) then
    XPathFail('Wrong number of arguments for function ' + Name + '()');
end;

function TXpFunc.ArgStr(Idx: Integer; const Ctx: TXpCtx): XmlString;
begin
  Result := XPathToString(ArgList[Idx].Eval(Ctx));
end;

function TXpFunc.ArgNum(Idx: Integer; const Ctx: TXpCtx): Double;
begin
  Result := XPathToNumber(ArgList[Idx].Eval(Ctx));
end;

function TXpFunc.ArgNodes(Idx: Integer; const Ctx: TXpCtx): TXmlNodeArray;
var
  X: TXPathValue;
begin
  X := ArgList[Idx].Eval(Ctx);
  if X.Kind <> xvNodeSet then XPathFail('Function ' + Name + '() requires a node-set argument');
  Result := X.Nodes;
end;

function TXpFunc.ArgOrContextString(const Ctx: TXpCtx): XmlString;
begin
  if System.Length(ArgList) > 0 then
    Result := ArgStr(0, Ctx)
  else
    Result := NodeStringValue(Ctx.Node);
end;

function TXpFunc.Eval(const Ctx: TXpCtx): TXPathValue;
var
  N: Integer;
  S, S2, S3: XmlString;
  I, P, K: Integer;
  V: TXPathValue;
  A, B, Sum: Double;
  Nd: TXmlNode;
  B_: TXmlStrBuf;
  Target, Val: XmlString;
  Found: Boolean;
begin
  N := System.Length(ArgList);
  if Name = 'last' then begin CheckArgs(0, 0); Result := MakeNum(Ctx.Size); end
  else if Name = 'position' then begin CheckArgs(0, 0); Result := MakeNum(Ctx.Pos); end
  else if Name = 'count' then begin CheckArgs(1, 1); Result := MakeNum(System.Length(ArgNodes(0, Ctx))); end
  else if Name = 'id' then
  begin
    CheckArgs(1, 1);
    ArgStr(0, Ctx);
    Result := MakeNodes(nil);
  end
  else if (Name = 'local-name') or (Name = 'name') or (Name = 'namespace-uri') then
  begin
    CheckArgs(0, 1);
    Nd := FirstNodeOrContext(Self, Ctx, 0);
    S := '';
    if Nd <> nil then
    begin
      if Name = 'namespace-uri' then
      begin
        if Nd.NodeType in [ntElement, ntAttribute] then S := Nd.NamespaceURI;
      end
      else if Nd.NodeType in [ntElement, ntAttribute] then
      begin
        if Name = 'name' then S := Nd.Name else S := Nd.LocalName;
      end
      else if Nd.NodeType = ntProcessingInstruction then
        S := Nd.Name;
    end;
    Result := MakeStr(S);
  end
  else if Name = 'string' then
  begin
    CheckArgs(0, 1);
    if N = 0 then Result := MakeStr(NodeStringValue(Ctx.Node)) else Result := MakeStr(ArgStr(0, Ctx));
  end
  else if Name = 'concat' then
  begin
    CheckArgs(2, -1);
    B_ := TXmlStrBuf.Create(64);
    try
      for I := 0 to N - 1 do B_.Append(ArgStr(I, Ctx));
      Result := MakeStr(B_.AsString);
    finally
      B_.Free;
    end;
  end
  else if Name = 'starts-with' then
  begin
    CheckArgs(2, 2);
    S := ArgStr(0, Ctx);
    S2 := ArgStr(1, Ctx);
    Result := MakeBool(Copy(S, 1, System.Length(S2)) = S2);
  end
  else if Name = 'contains' then
  begin
    CheckArgs(2, 2);
    S := ArgStr(0, Ctx);
    S2 := ArgStr(1, Ctx);
    Result := MakeBool((S2 = '') or (Pos(S2, S) > 0));
  end
  else if Name = 'substring-before' then
  begin
    CheckArgs(2, 2);
    S := ArgStr(0, Ctx);
    S2 := ArgStr(1, Ctx);
    P := Pos(S2, S);
    if (S2 = '') or (P = 0) then Result := MakeStr('') else Result := MakeStr(Copy(S, 1, P - 1));
  end
  else if Name = 'substring-after' then
  begin
    CheckArgs(2, 2);
    S := ArgStr(0, Ctx);
    S2 := ArgStr(1, Ctx);
    if S2 = '' then Result := MakeStr(S)
    else
    begin
      P := Pos(S2, S);
      if P = 0 then Result := MakeStr('') else Result := MakeStr(Copy(S, P + System.Length(S2), MaxInt));
    end;
  end
  else if Name = 'substring' then
  begin
    CheckArgs(2, 3);
    S := ArgStr(0, Ctx);
    A := RoundX(ArgNum(1, Ctx));
    if N = 3 then B := A + RoundX(ArgNum(2, Ctx)) else B := Infinity;
    S2 := '';
    if not (IsNan(A) or IsNan(B)) then
      for I := 1 to System.Length(S) do
        if (I >= A) and (I < B) then S2 := S2 + S[I];
    Result := MakeStr(S2);
  end
  else if Name = 'string-length' then
  begin
    CheckArgs(0, 1);
    Result := MakeNum(System.Length(ArgOrContextString(Ctx)));
  end
  else if Name = 'normalize-space' then
  begin
    CheckArgs(0, 1);
    Result := MakeStr(NormalizeSpace(ArgOrContextString(Ctx)));
  end
  else if Name = 'translate' then
  begin
    CheckArgs(3, 3);
    S := ArgStr(0, Ctx);
    S2 := ArgStr(1, Ctx);
    S3 := ArgStr(2, Ctx);
    B_ := TXmlStrBuf.Create(System.Length(S) + 1);
    try
      for I := 1 to System.Length(S) do
      begin
        P := 0;
        for K := 1 to System.Length(S2) do
          if S2[K] = S[I] then
          begin
            P := K;
            Break;
          end;
        if P = 0 then B_.AppendChar(S[I])
        else if P <= System.Length(S3) then B_.AppendChar(S3[P]);
      end;
      Result := MakeStr(B_.AsString);
    finally
      B_.Free;
    end;
  end
  else if Name = 'boolean' then begin CheckArgs(1, 1); Result := MakeBool(XPathToBoolean(ArgList[0].Eval(Ctx))); end
  else if Name = 'not' then begin CheckArgs(1, 1); Result := MakeBool(not XPathToBoolean(ArgList[0].Eval(Ctx))); end
  else if Name = 'true' then begin CheckArgs(0, 0); Result := MakeBool(True); end
  else if Name = 'false' then begin CheckArgs(0, 0); Result := MakeBool(False); end
  else if Name = 'lang' then
  begin
    CheckArgs(1, 1);
    Target := LowerCase(ArgStr(0, Ctx));
    Found := False;
    Nd := Ctx.Node;
    while Nd <> nil do
    begin
      if (Nd.NodeType = ntElement) and TXmlElement(Nd).TryGetAttribute('xml:lang', Val) then
      begin
        Val := LowerCase(Val);
        Found := (Val = Target) or (Copy(Val, 1, System.Length(Target) + 1) = Target + '-');
        Break;
      end;
      Nd := Nd.ParentNode;
    end;
    Result := MakeBool(Found);
  end
  else if Name = 'number' then
  begin
    CheckArgs(0, 1);
    if N = 0 then Result := MakeNum(StringToNumber(NodeStringValue(Ctx.Node)))
    else Result := MakeNum(XPathToNumber(ArgList[0].Eval(Ctx)));
  end
  else if Name = 'sum' then
  begin
    CheckArgs(1, 1);
    Sum := 0;
    V := ArgList[0].Eval(Ctx);
    if V.Kind <> xvNodeSet then XPathFail('sum() requires a node-set argument');
    for I := 0 to System.Length(V.Nodes) - 1 do Sum := Sum + StringToNumber(NodeStringValue(V.Nodes[I]));
    Result := MakeNum(Sum);
  end
  else if Name = 'floor' then
  begin
    CheckArgs(1, 1);
    A := ArgNum(0, Ctx);
    if IsNan(A) or IsInfinite(A) then Result := MakeNum(A) else Result := MakeNum(FloorD(A));
  end
  else if Name = 'ceiling' then
  begin
    CheckArgs(1, 1);
    A := ArgNum(0, Ctx);
    if IsNan(A) or IsInfinite(A) then Result := MakeNum(A) else Result := MakeNum(CeilD(A));
  end
  else if Name = 'round' then
  begin
    CheckArgs(1, 1);
    Result := MakeNum(RoundX(ArgNum(0, Ctx)));
  end
  else
  begin
    XPathFail('Unknown function ' + Name + '()');
    Result := MakeBool(False);
  end;
end;

{ ---------------- lexer ---------------- }

type
  TTokKind = (tkEOF, tkLParen, tkRParen, tkLBracket, tkRBracket, tkDot, tkDotDot, tkAt, tkComma,
    tkColonColon, tkSlash, tkDSlash, tkPipe, tkPlus, tkMinus, tkEq, tkNeq, tkLt, tkLe, tkGt, tkGe,
    tkStar, tkMultiply, tkName, tkAnd, tkOr, tkMod, tkDiv, tkLiteral, tkNumber, tkVar);

  TToken = record
    Kind: TTokKind;
    Text: XmlString;
    Num: Double;
    Pos: Integer;
  end;

  TXPathParser = class
  private
    FSrc: XmlString;
    FToks: array of TToken;
    FCount, FIdx: Integer;
    FDepth: Integer;
    procedure Lex;
    procedure AddTok(K: TTokKind; const T: XmlString; N: Double; P: Integer);
    function PrevAllowsOperator: Boolean;
    function Cur: TToken;
    function PeekKind(Offset: Integer): TTokKind;
    procedure Advance;
    procedure Expect(K: TTokKind; const What: XmlString);
    function ParseOr: TXpNode;
    function ParseAnd: TXpNode;
    function ParseEquality: TXpNode;
    function ParseRelational: TXpNode;
    function ParseAdditive: TXpNode;
    function ParseMultiplicative: TXpNode;
    function ParseUnary: TXpNode;
    function ParseUnion: TXpNode;
    function ParsePathExpr: TXpNode;
    function ParsePrimary: TXpNode;
    function ParseStep: TXpStep;
    procedure ParseRelativeSteps(P: TXpPath);
    procedure AddStep(P: TXpPath; S: TXpStep);
    function NewDescOrSelf: TXpStep;
    function StartsStep: Boolean;
    function IsFunctionCall: Boolean;
  public
    constructor Create(const Src: XmlString);
    function Parse: TXpNode;
  end;

constructor TXPathParser.Create(const Src: XmlString);
begin
  inherited Create;
  FSrc := Src;
  Lex;
end;

procedure TXPathParser.AddTok(K: TTokKind; const T: XmlString; N: Double; P: Integer);
begin
  if FCount >= System.Length(FToks) then SetLength(FToks, FCount * 2 + 16);
  FToks[FCount].Kind := K;
  FToks[FCount].Text := T;
  FToks[FCount].Num := N;
  FToks[FCount].Pos := P;
  Inc(FCount);
end;

function TXPathParser.PrevAllowsOperator: Boolean;
begin
  if FCount = 0 then
    Result := False
  else
    Result := not (FToks[FCount - 1].Kind in [tkAt, tkColonColon, tkLParen, tkLBracket, tkComma,
      tkSlash, tkDSlash, tkPipe, tkPlus, tkMinus, tkEq, tkNeq, tkLt, tkLe, tkGt, tkGe, tkStar,
      tkMultiply, tkAnd, tkOr, tkMod, tkDiv]);
end;

procedure TXPathParser.Lex;
var
  I, N, Start, Q: Integer;
  C: WideChar;
  Txt: XmlString;
  V: Double;
begin
  N := System.Length(FSrc);
  I := 1;
  while I <= N do
  begin
    C := FSrc[I];
    if XmlIsWhite(Ord(C)) then begin Inc(I); Continue; end;
    Start := I;
    case C of
      '(': begin AddTok(tkLParen, '(', 0, I); Inc(I); end;
      ')': begin AddTok(tkRParen, ')', 0, I); Inc(I); end;
      '[': begin AddTok(tkLBracket, '[', 0, I); Inc(I); end;
      ']': begin AddTok(tkRBracket, ']', 0, I); Inc(I); end;
      '@': begin AddTok(tkAt, '@', 0, I); Inc(I); end;
      ',': begin AddTok(tkComma, ',', 0, I); Inc(I); end;
      '|': begin AddTok(tkPipe, '|', 0, I); Inc(I); end;
      '+': begin AddTok(tkPlus, '+', 0, I); Inc(I); end;
      '-': begin AddTok(tkMinus, '-', 0, I); Inc(I); end;
      '=': begin AddTok(tkEq, '=', 0, I); Inc(I); end;
      '!':
        begin
          if (I < N) and (FSrc[I + 1] = '=') then
          begin
            AddTok(tkNeq, '!=', 0, I);
            Inc(I, 2);
          end
          else
            XPathFail('Unexpected character "!"', I);
        end;
      '<':
        if (I < N) and (FSrc[I + 1] = '=') then begin AddTok(tkLe, '<=', 0, I); Inc(I, 2); end
        else begin AddTok(tkLt, '<', 0, I); Inc(I); end;
      '>':
        if (I < N) and (FSrc[I + 1] = '=') then begin AddTok(tkGe, '>=', 0, I); Inc(I, 2); end
        else begin AddTok(tkGt, '>', 0, I); Inc(I); end;
      '/':
        if (I < N) and (FSrc[I + 1] = '/') then begin AddTok(tkDSlash, '//', 0, I); Inc(I, 2); end
        else begin AddTok(tkSlash, '/', 0, I); Inc(I); end;
      '*':
        begin
          if PrevAllowsOperator then AddTok(tkMultiply, '*', 0, I) else AddTok(tkStar, '*', 0, I);
          Inc(I);
        end;
      '"', '''':
        begin
          Q := I + 1;
          while (Q <= N) and (FSrc[Q] <> C) do Inc(Q);
          if Q > N then XPathFail('Unterminated string literal', I);
          AddTok(tkLiteral, Copy(FSrc, I + 1, Q - I - 1), 0, I);
          I := Q + 1;
        end;
      '$':
        begin
          Inc(I);
          Q := I;
          while (Q <= N) and (XmlIsNameChar(Ord(FSrc[Q]))) do Inc(Q);
          if Q = I then XPathFail('Variable name expected after "$"', I);
          AddTok(tkVar, Copy(FSrc, I, Q - I), 0, Start);
          I := Q;
        end;
      '.':
        begin
          if (I < N) and (FSrc[I + 1] = '.') then
          begin
            AddTok(tkDotDot, '..', 0, I);
            Inc(I, 2);
          end
          else if (I < N) and (FSrc[I + 1] >= '0') and (FSrc[I + 1] <= '9') then
          begin
            Q := I + 1;
            while (Q <= N) and (FSrc[Q] >= '0') and (FSrc[Q] <= '9') do Inc(Q);
            Txt := Copy(FSrc, I, Q - I);
            if not XmlTryParseFloat(Txt, V) then XPathFail('Invalid number', I);
            AddTok(tkNumber, Txt, V, I);
            I := Q;
          end
          else
          begin
            AddTok(tkDot, '.', 0, I);
            Inc(I);
          end;
        end;
      '0'..'9':
        begin
          Q := I;
          while (Q <= N) and (FSrc[Q] >= '0') and (FSrc[Q] <= '9') do Inc(Q);
          if (Q <= N) and (FSrc[Q] = '.') then
          begin
            Inc(Q);
            while (Q <= N) and (FSrc[Q] >= '0') and (FSrc[Q] <= '9') do Inc(Q);
          end;
          Txt := Copy(FSrc, I, Q - I);
          if not XmlTryParseFloat(Txt, V) then XPathFail('Invalid number', I);
          AddTok(tkNumber, Txt, V, I);
          I := Q;
        end;
    else
      begin
        if not XmlIsNCNameStartChar(Ord(C)) then XPathFail('Unexpected character "' + C + '"', I);
        Q := I;
        while (Q <= N) and XmlIsNCNameChar(Ord(FSrc[Q])) do Inc(Q);
        // optional prefix:local or prefix:*
        if (Q < N) and (FSrc[Q] = ':') and (FSrc[Q + 1] <> ':') then
        begin
          if FSrc[Q + 1] = '*' then
            Q := Q + 2
          else if XmlIsNCNameStartChar(Ord(FSrc[Q + 1])) then
          begin
            Inc(Q);
            while (Q <= N) and XmlIsNCNameChar(Ord(FSrc[Q])) do Inc(Q);
          end;
        end;
        Txt := Copy(FSrc, I, Q - I);
        if PrevAllowsOperator and (Txt = 'and') then AddTok(tkAnd, Txt, 0, I)
        else if PrevAllowsOperator and (Txt = 'or') then AddTok(tkOr, Txt, 0, I)
        else if PrevAllowsOperator and (Txt = 'mod') then AddTok(tkMod, Txt, 0, I)
        else if PrevAllowsOperator and (Txt = 'div') then AddTok(tkDiv, Txt, 0, I)
        else AddTok(tkName, Txt, 0, I);
        I := Q;
      end;
    end;
    // '::' handled here because ':' alone is not otherwise valid
    if (I <= N) and (FSrc[I] = ':') then
    begin
      if (I < N) and (FSrc[I + 1] = ':') then
      begin
        AddTok(tkColonColon, '::', 0, I);
        Inc(I, 2);
      end
      else
        XPathFail('Unexpected character ":"', I);
    end;
  end;
  AddTok(tkEOF, '', 0, N + 1);
end;

function TXPathParser.Cur: TToken;
begin
  Result := FToks[FIdx];
end;

function TXPathParser.PeekKind(Offset: Integer): TTokKind;
begin
  if FIdx + Offset < FCount then Result := FToks[FIdx + Offset].Kind else Result := tkEOF;
end;

procedure TXPathParser.Advance;
begin
  if FIdx < FCount - 1 then Inc(FIdx);
end;

procedure TXPathParser.Expect(K: TTokKind; const What: XmlString);
begin
  if Cur.Kind <> K then XPathFail('Expected ' + What, Cur.Pos);
  Advance;
end;

function TXPathParser.Parse: TXpNode;
begin
  FIdx := 0;
  Result := ParseOr;
  if Cur.Kind <> tkEOF then
  begin
    Result.Free;
    XPathFail('Unexpected token "' + Cur.Text + '"', Cur.Pos);
  end;
end;

function TXPathParser.ParseOr: TXpNode;
var
  B: TXpBinary;
begin
  Inc(FDepth);
  try
    if FDepth > 200 then XPathFail('The expression is nested too deeply', Cur.Pos);
    Result := ParseAnd;
    while Cur.Kind = tkOr do
    begin
      Advance;
      B := TXpBinary.Create;
      B.Op := opOr;
      B.L := Result;
      Result := B;
      B.R := ParseAnd;
    end;
  finally
    Dec(FDepth);
  end;
end;

function TXPathParser.ParseAnd: TXpNode;
var
  B: TXpBinary;
begin
  Result := ParseEquality;
  while Cur.Kind = tkAnd do
  begin
    Advance;
    B := TXpBinary.Create;
    B.Op := opAnd;
    B.L := Result;
    Result := B;
    B.R := ParseEquality;
  end;
end;

function TXPathParser.ParseEquality: TXpNode;
var
  B: TXpBinary;
  O: TXpOp;
begin
  Result := ParseRelational;
  while Cur.Kind in [tkEq, tkNeq] do
  begin
    if Cur.Kind = tkEq then O := opEq else O := opNeq;
    Advance;
    B := TXpBinary.Create;
    B.Op := O;
    B.L := Result;
    Result := B;
    B.R := ParseRelational;
  end;
end;

function TXPathParser.ParseRelational: TXpNode;
var
  B: TXpBinary;
  O: TXpOp;
begin
  Result := ParseAdditive;
  while Cur.Kind in [tkLt, tkLe, tkGt, tkGe] do
  begin
    case Cur.Kind of
      tkLt: O := opLt;
      tkLe: O := opLe;
      tkGt: O := opGt;
    else
      O := opGe;
    end;
    Advance;
    B := TXpBinary.Create;
    B.Op := O;
    B.L := Result;
    Result := B;
    B.R := ParseAdditive;
  end;
end;

function TXPathParser.ParseAdditive: TXpNode;
var
  B: TXpBinary;
  O: TXpOp;
begin
  Result := ParseMultiplicative;
  while Cur.Kind in [tkPlus, tkMinus] do
  begin
    if Cur.Kind = tkPlus then O := opAdd else O := opSub;
    Advance;
    B := TXpBinary.Create;
    B.Op := O;
    B.L := Result;
    Result := B;
    B.R := ParseMultiplicative;
  end;
end;

function TXPathParser.ParseMultiplicative: TXpNode;
var
  B: TXpBinary;
  O: TXpOp;
begin
  Result := ParseUnary;
  while Cur.Kind in [tkMultiply, tkDiv, tkMod] do
  begin
    case Cur.Kind of
      tkMultiply: O := opMul;
      tkDiv: O := opDiv;
    else
      O := opMod;
    end;
    Advance;
    B := TXpBinary.Create;
    B.Op := O;
    B.L := Result;
    Result := B;
    B.R := ParseUnary;
  end;
end;

function TXPathParser.ParseUnary: TXpNode;
var
  N: TXpNeg;
begin
  if Cur.Kind = tkMinus then
  begin
    Advance;
    N := TXpNeg.Create;
    Result := N;
    N.E := ParseUnary;
  end
  else
    Result := ParseUnion;
end;

function TXPathParser.ParseUnion: TXpNode;
var
  B: TXpBinary;
begin
  Result := ParsePathExpr;
  while Cur.Kind = tkPipe do
  begin
    Advance;
    B := TXpBinary.Create;
    B.Op := opUnion;
    B.L := Result;
    Result := B;
    B.R := ParsePathExpr;
  end;
end;

function TXPathParser.IsFunctionCall: Boolean;
var
  T: XmlString;
begin
  Result := False;
  if (Cur.Kind = tkName) and (PeekKind(1) = tkLParen) then
  begin
    T := Cur.Text;
    Result := not ((T = 'node') or (T = 'text') or (T = 'comment') or (T = 'processing-instruction'));
  end;
end;

function TXPathParser.StartsStep: Boolean;
begin
  Result := Cur.Kind in [tkName, tkStar, tkAt, tkDot, tkDotDot];
end;

function TXPathParser.NewDescOrSelf: TXpStep;
begin
  Result := TXpStep.Create;
  Result.Axis := axDescendantOrSelf;
  Result.Test := ttNode;
end;

procedure TXPathParser.AddStep(P: TXpPath; S: TXpStep);
begin
  SetLength(P.Steps, System.Length(P.Steps) + 1);
  P.Steps[System.Length(P.Steps) - 1] := S;
end;

procedure TXPathParser.ParseRelativeSteps(P: TXpPath);
begin
  AddStep(P, ParseStep);
  while Cur.Kind in [tkSlash, tkDSlash] do
  begin
    if Cur.Kind = tkDSlash then AddStep(P, NewDescOrSelf);
    Advance;
    AddStep(P, ParseStep);
  end;
end;

function TXPathParser.ParseStep: TXpStep;
var
  AxisName: XmlString;
  T: XmlString;
  P: Integer;
  Pred: TXpNode;
begin
  Result := TXpStep.Create;
  try
    if Cur.Kind = tkDot then
    begin
      Result.Axis := axSelf;
      Result.Test := ttNode;
      Advance;
      Exit;
    end;
    if Cur.Kind = tkDotDot then
    begin
      Result.Axis := axParent;
      Result.Test := ttNode;
      Advance;
      Exit;
    end;
    Result.Axis := axChild;
    if Cur.Kind = tkAt then
    begin
      Result.Axis := axAttribute;
      Advance;
    end
    else if (Cur.Kind = tkName) and (PeekKind(1) = tkColonColon) then
    begin
      AxisName := Cur.Text;
      if AxisName = 'child' then Result.Axis := axChild
      else if AxisName = 'descendant' then Result.Axis := axDescendant
      else if AxisName = 'parent' then Result.Axis := axParent
      else if AxisName = 'ancestor' then Result.Axis := axAncestor
      else if AxisName = 'following-sibling' then Result.Axis := axFollowingSibling
      else if AxisName = 'preceding-sibling' then Result.Axis := axPrecedingSibling
      else if AxisName = 'following' then Result.Axis := axFollowing
      else if AxisName = 'preceding' then Result.Axis := axPreceding
      else if AxisName = 'attribute' then Result.Axis := axAttribute
      else if AxisName = 'namespace' then Result.Axis := axNamespace
      else if AxisName = 'self' then Result.Axis := axSelf
      else if AxisName = 'descendant-or-self' then Result.Axis := axDescendantOrSelf
      else if AxisName = 'ancestor-or-self' then Result.Axis := axAncestorOrSelf
      else XPathFail('Unknown axis "' + AxisName + '"', Cur.Pos);
      Advance;
      Advance;
    end;
    if Cur.Kind = tkStar then
    begin
      Result.Test := ttAnyName;
      Advance;
    end
    else if Cur.Kind = tkName then
    begin
      T := Cur.Text;
      if PeekKind(1) = tkLParen then
      begin
        if T = 'node' then Result.Test := ttNode
        else if T = 'text' then Result.Test := ttText
        else if T = 'comment' then Result.Test := ttComment
        else if T = 'processing-instruction' then Result.Test := ttPI
        else XPathFail('"' + T + '" is not a node type test', Cur.Pos);
        Advance;
        Advance; // '('
        if (Result.Test = ttPI) and (Cur.Kind = tkLiteral) then
        begin
          Result.PITarget := Cur.Text;
          Advance;
        end;
        Expect(tkRParen, '")"');
      end
      else
      begin
        P := Pos(':', T);
        if P > 0 then
        begin
          Result.Prefix := Copy(T, 1, P - 1);
          T := Copy(T, P + 1, MaxInt);
        end;
        if T = '*' then
          Result.Test := ttPrefixAny
        else
        begin
          Result.Test := ttName;
          Result.Local := T;
        end;
        Advance;
      end;
    end
    else
      XPathFail('Node test expected', Cur.Pos);

    while Cur.Kind = tkLBracket do
    begin
      Advance;
      Pred := ParseOr;
      SetLength(Result.Preds, System.Length(Result.Preds) + 1);
      Result.Preds[System.Length(Result.Preds) - 1] := Pred;
      Expect(tkRBracket, '"]"');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TXPathParser.ParsePrimary: TXpNode;
var
  Lit: TXpLiteral;
  Num: TXpNumber;
  V: TXpVar;
  F: TXpFunc;
begin
  case Cur.Kind of
    tkLiteral:
      begin
        Lit := TXpLiteral.Create;
        Lit.Str := Cur.Text;
        Advance;
        Result := Lit;
      end;
    tkNumber:
      begin
        Num := TXpNumber.Create;
        Num.Num := Cur.Num;
        Advance;
        Result := Num;
      end;
    tkVar:
      begin
        V := TXpVar.Create;
        V.Name := Cur.Text;
        Advance;
        Result := V;
      end;
    tkLParen:
      begin
        Advance;
        Result := ParseOr;
        try
          Expect(tkRParen, '")"');
        except
          Result.Free;
          raise;
        end;
      end;
  else
    begin
      // function call
      F := TXpFunc.Create;
      Result := F;
      try
        F.Name := Cur.Text;
        Advance;
        Advance; // '('
        if Cur.Kind <> tkRParen then
          while True do
          begin
            SetLength(F.ArgList, System.Length(F.ArgList) + 1);
            F.ArgList[System.Length(F.ArgList) - 1] := ParseOr;
            if Cur.Kind = tkComma then Advance else Break;
          end;
        Expect(tkRParen, '")"');
      except
        Result.Free;
        raise;
      end;
    end;
  end;
end;

function TXPathParser.ParsePathExpr: TXpNode;
var
  P: TXpPath;
  Flt: TXpFilter;
  Prim: TXpNode;
begin
  if Cur.Kind in [tkSlash, tkDSlash] then
  begin
    P := TXpPath.Create;
    Result := P;
    try
      P.Absolute := True;
      if Cur.Kind = tkDSlash then
      begin
        Advance;
        AddStep(P, NewDescOrSelf);
        ParseRelativeSteps(P);
      end
      else
      begin
        Advance;
        if StartsStep then ParseRelativeSteps(P);
      end;
    except
      Result.Free;
      raise;
    end;
    Exit;
  end;
  if (Cur.Kind in [tkLiteral, tkNumber, tkVar, tkLParen]) or IsFunctionCall then
  begin
    Prim := ParsePrimary;
    Result := Prim;
    try
      if Cur.Kind = tkLBracket then
      begin
        Flt := TXpFilter.Create;
        Flt.Primary := Prim;
        Result := Flt;
        while Cur.Kind = tkLBracket do
        begin
          Advance;
          SetLength(Flt.Preds, System.Length(Flt.Preds) + 1);
          Flt.Preds[System.Length(Flt.Preds) - 1] := ParseOr;
          Expect(tkRBracket, '"]"');
        end;
      end;
      if Cur.Kind in [tkSlash, tkDSlash] then
      begin
        P := TXpPath.Create;
        P.Base := Result;
        Result := P;
        while Cur.Kind in [tkSlash, tkDSlash] do
        begin
          if Cur.Kind = tkDSlash then AddStep(P, NewDescOrSelf);
          Advance;
          AddStep(P, ParseStep);
        end;
      end;
    except
      Result.Free;
      raise;
    end;
    Exit;
  end;
  P := TXpPath.Create;
  Result := P;
  try
    ParseRelativeSteps(P);
  except
    Result.Free;
    raise;
  end;
end;

{ ---------------- TXPathExpression ---------------- }

constructor TXPathExpression.Create(const Expression: XmlString);
var
  P: TXPathParser;
begin
  inherited Create;
  FSource := Expression;
  P := TXPathParser.Create(Expression);
  try
    FRoot := P.Parse;
  finally
    P.Free;
  end;
end;

destructor TXPathExpression.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

procedure TXPathExpression.AddNamespace(const Prefix, Uri: XmlString);
var
  I: Integer;
begin
  for I := 0 to FNsCount - 1 do
    if FNsPrefix[I] = Prefix then
    begin
      FNsUri[I] := Uri;
      Exit;
    end;
  SetLength(FNsPrefix, FNsCount + 1);
  SetLength(FNsUri, FNsCount + 1);
  FNsPrefix[FNsCount] := Prefix;
  FNsUri[FNsCount] := Uri;
  Inc(FNsCount);
end;

function TXPathExpression.ResolvePrefix(const Prefix: XmlString; ContextNode: TXmlNode): XmlString;
var
  I: Integer;
  Doc: TXmlDocument;
begin
  for I := 0 to FNsCount - 1 do
    if FNsPrefix[I] = Prefix then
    begin
      Result := FNsUri[I];
      Exit;
    end;
  if (ContextNode <> nil) and ContextNode.LookupNamespaceURI(Prefix, Result) then Exit;
  // the document node has no declarations of its own: fall back to the root element
  if ContextNode <> nil then
  begin
    Doc := ContextNode.OwnerDocument;
    if (Doc <> nil) and (Doc.DocumentElement <> nil) and
       Doc.DocumentElement.LookupNamespaceURI(Prefix, Result) then Exit;
  end;
  raise EXmlXPathException.CreateCode(XFE_XPATH_EVAL, 'Unbound namespace prefix "' + Prefix + '" in XPath expression');
end;

procedure TXPathExpression.SetVariable(const Name: XmlString; const Value: TXPathValue);
var
  I: Integer;
begin
  for I := 0 to FVarCount - 1 do
    if FVarNames[I] = Name then
    begin
      FVarValues[I] := Value;
      Exit;
    end;
  SetLength(FVarNames, FVarCount + 1);
  SetLength(FVarValues, FVarCount + 1);
  FVarNames[FVarCount] := Name;
  FVarValues[FVarCount] := Value;
  Inc(FVarCount);
end;

procedure TXPathExpression.SetVariableString(const Name, Value: XmlString);
begin
  SetVariable(Name, MakeStr(Value));
end;

procedure TXPathExpression.SetVariableNumber(const Name: XmlString; Value: Double);
begin
  SetVariable(Name, MakeNum(Value));
end;

procedure TXPathExpression.SetVariableBoolean(const Name: XmlString; Value: Boolean);
begin
  SetVariable(Name, MakeBool(Value));
end;

function TXPathExpression.GetVariable(const Name: XmlString): TXPathValue;
var
  I: Integer;
begin
  for I := 0 to FVarCount - 1 do
    if FVarNames[I] = Name then
    begin
      Result := FVarValues[I];
      Exit;
    end;
  raise EXmlXPathException.CreateCode(XFE_XPATH_EVAL, 'Undefined XPath variable $' + Name);
end;

function TXPathExpression.Evaluate(Context: TXmlNode): TXPathValue;
var
  Ctx: TXpCtx;
  {$IFDEF FPC}
  OldMask: TFPUExceptionMask;
  {$ELSE}
  OldMask: TArithmeticExceptionMask;
  {$ENDIF}
begin
  if Context = nil then XPathFail('A context node is required');
  EnsureOrder(Context);
  Ctx.Node := Context;
  Ctx.Pos := 1;
  Ctx.Size := 1;
  Ctx.Expr := Self;
  // XPath arithmetic is IEEE-754 (NaN/Infinity instead of exceptions)
  OldMask := SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    Result := TXpNode(FRoot).Eval(Ctx);
  finally
    SetExceptionMask(OldMask);
  end;
end;

function TXPathExpression.SelectNodes(Context: TXmlNode): TXmlNodeList;
var
  V: TXPathValue;
  I: Integer;
begin
  V := Evaluate(Context);
  if V.Kind <> xvNodeSet then XPathFail('The expression "' + FSource + '" does not return a node-set');
  Result := TXmlNodeList.Create;
  for I := 0 to System.Length(V.Nodes) - 1 do Result.Add(V.Nodes[I]);
end;

function TXPathExpression.SelectSingleNode(Context: TXmlNode): TXmlNode;
var
  V: TXPathValue;
begin
  V := Evaluate(Context);
  if V.Kind <> xvNodeSet then XPathFail('The expression "' + FSource + '" does not return a node-set');
  if System.Length(V.Nodes) > 0 then Result := V.Nodes[0] else Result := nil;
end;

function TXPathExpression.EvaluateString(Context: TXmlNode): XmlString;
begin
  Result := XPathToString(Evaluate(Context));
end;

function TXPathExpression.EvaluateNumber(Context: TXmlNode): Double;
begin
  Result := XPathToNumber(Evaluate(Context));
end;

function TXPathExpression.EvaluateBoolean(Context: TXmlNode): Boolean;
begin
  Result := XPathToBoolean(Evaluate(Context));
end;

{ ---------------- convenience functions ---------------- }

function XPathSelectNodes(Context: TXmlNode; const Expr: XmlString): TXmlNodeList;
var
  X: TXPathExpression;
begin
  X := TXPathExpression.Create(Expr);
  try
    Result := X.SelectNodes(Context);
  finally
    X.Free;
  end;
end;

function XPathSelectSingle(Context: TXmlNode; const Expr: XmlString): TXmlNode;
var
  X: TXPathExpression;
begin
  X := TXPathExpression.Create(Expr);
  try
    Result := X.SelectSingleNode(Context);
  finally
    X.Free;
  end;
end;

function XPathEvalString(Context: TXmlNode; const Expr: XmlString): XmlString;
var
  X: TXPathExpression;
begin
  X := TXPathExpression.Create(Expr);
  try
    Result := X.EvaluateString(Context);
  finally
    X.Free;
  end;
end;

function XPathEvalNumber(Context: TXmlNode; const Expr: XmlString): Double;
var
  X: TXPathExpression;
begin
  X := TXPathExpression.Create(Expr);
  try
    Result := X.EvaluateNumber(Context);
  finally
    X.Free;
  end;
end;

function XPathEvalBoolean(Context: TXmlNode; const Expr: XmlString): Boolean;
var
  X: TXPathExpression;
begin
  X := TXPathExpression.Create(Expr);
  try
    Result := X.EvaluateBoolean(Context);
  finally
    X.Free;
  end;
end;

end.
