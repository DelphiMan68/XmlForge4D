# AGENTS.md — XmlForge4D

Guidance for AI coding agents (and humans) working in this repository.

## What this project is

XmlForge4D is a portable Object Pascal library for **Delphi** and **Free Pascal**: secure streaming
XML parser (SAX), DOM, streaming writer, XPath 1.0, XSD validation (documented subset), and
XML ⇄ JSON conversion in two modes — *Standard* and *Lossless* ("XML Infoset JSON", format
`XmlForge4D`, version `1.0`) — built on a Universal Data Model (UDM).

## Current status (read first)

The code was written **without access to a Pascal compiler**. It has **never been compiled or run**.
Your first job in any session is to build and run the tests, and fix what the compiler reports:

```
./build_fpc.sh test        # Linux/macOS, Free Pascal
build_fpc.bat              # Windows, Free Pascal
build_delphi.bat           # Windows, Delphi (RAD Studio command prompt)
```

Do not claim something works unless the test suite ran green. When you fix a compile error, keep the
fix portable (it must still compile on **both** compilers). Record verified compilers/OSes in
`docs/COMPATIBILITY.md`.

## Repository layout

```
src/         library units (the product)
  XmlForge4D.inc         compiler config, included first in every unit
  XmlForge4D.Types       exceptions + XFE_* error codes, name rules, TXmlStrBuf, number helpers
  XmlForge4D.Encoding    UTF-8/16, Latin-1, ASCII codecs, BOM/declaration detection
  XmlForge4D.Parser      TXmlInputReader, TXmlSaxHandler, TXmlParser (streaming, limits, namespaces)
  XmlForge4D.Writer      TXmlWriter (streaming, pretty print, validation)
  XmlForge4D.Dom         TXmlNode hierarchy, TXmlDocument, TXmlDomBuilder, serialization
  XmlForge4D.XPath       lexer/parser/evaluator for XPath 1.0
  XmlForge4D.Schema      XSD loader + TXmlValidator
  XmlForge4D.DataModel   TDataNode (UDM)
  XmlForge4D.Json        TJsonParser / TJsonWriter
  XmlForge4D.Convert     XML<->JSON (standard + lossless), options, TXmlInfosetComparer
tests/       XmlForge4D.TestSuite.pas (+ .dpr / .lpr runners)
benchmarks/  XmlForge4D.Bench.pas (+ .dpr / .lpr)
examples/    Delphi/*.dpr and FreePascal/*.lpr — complete, self-contained programs (keep them in sync; do not move code into .inc files)
packages/    XmlForge4D.dpk (Delphi), XmlForge4D.lpk (Lazarus)
docs/        API.md, INFOSET_JSON.md, CONVERSION_RULES.md, SECURITY.md, COMPATIBILITY.md
```

Unit dependency order (no circular *interface* dependencies):
`Types → Encoding → Parser → Writer → Dom ⇄(impl only) XPath → DataModel → Json → Convert`,
`Schema` uses `Dom`.

## Portability rules (must follow)

These keep the code compiling on Delphi 2009+ (target 12) **and** FPC 3.0+ (target 3.2.x) on
Windows, Linux and macOS.

1. Every unit starts with `{$I XmlForge4D.inc}` (tests/benchmarks use `{$I ../src/XmlForge4D.inc}`).
   It selects `{$MODE DELPHIUNICODE}` on FPC. Do not add other mode switches.
2. Use `XmlString` (= `UnicodeString`) for all text and `WideChar` for characters. Never use
   `AnsiString`, `PChar`/`PAnsiChar` for text, `TEncoding`, or the OS code page.
3. Strings are 1-based. Character logic works on **UTF-16 code units**; handle surrogate pairs
   explicitly where code points matter.
4. Only RTL units: `SysUtils`, `Classes`, `Math` (and `DateUtils` in benchmarks). No
   `System.Generics.*`, `TStringBuilder`, `TDictionary`, anonymous methods, inline `var`,
   `for..in` over custom types, attributes/RTTI, or other post-2009 syntax.
5. Use plain unit names (`SysUtils`, not `System.SysUtils`).
6. Avoid `Exit(value)`; write `Result := …; Exit;`.
7. Record "static" helpers use `class function Default: T; static;`. Records cannot have default
   field values, so every options record is initialised by its `Default` function.
8. `TXmlStrBuf.Append(string)` and `AppendChar(WideChar)` are deliberately **different names** to
   avoid overload ambiguity for single-character literals. Keep it that way.
9. Do not use sets with `Integer` variables (`C in [9,10,13]`); compare explicitly.
10. Do not use a loop variable that is also captured by a nested routine, and do not modify loop
    variables.
11. Conditional compilation is allowed only where unavoidable (currently: FPU exception-mask type
    in `XmlForge4D.XPath`, heap statistics in the benchmark). Public interfaces must stay identical.
12. No locale-dependent conversions (`FloatToStr`, `StrToFloat`, `FormatFloat` in library code).
    Use `XmlFloatToStr` / `XmlTryParseFloat`. (Tests use `XmlFloatToStr` for the same reason.)
13. No platform-specific code, no network or file access except explicit `LoadFromFile`/`SaveToFile`
    style APIs taking a path from the caller.

## Design principles (do not violate)

1. XML is a structured document, not a key/value bag. Child **order is always explicit**.
2. *Standard* and *Lossless* conversion stay separate concepts; never "improve" Standard by making
   it silently lossy-or-lossless.
3. Namespaces are preserved correctly: element/attribute URIs are authoritative, `xmlns`
   declarations are stored as attributes whose namespace is `XMLNS_NS_URI`.
4. XML and JSON serializers are independent of the DOM/UDM; new formats (YAML, TOML) are added as
   new parser/serializer units mapping to/from `TDataNode` or the Infoset schema.
5. Large documents must be processable without loading everything: keep the SAX path O(depth).
6. Security by default (see below).
7. Round-trip correctness is the primary quality metric; compare the **information model**
   (`TXmlInfosetComparer`), never serialized strings.
8. Every limitation must be documented (README "Roadmap / known limitations", the header comment
   of the relevant unit, and `docs/`).

## Security rules

* External entities are never resolved. Never add code that opens a file or URL because of
  document content (entity, DOCTYPE system id, schema import/include, XInclude, …).
* Keep entity-expansion, entity-depth, nesting-depth, attribute-count and document-size limits
  enforced in `XmlForge4D.Parser`; defaults live in `TXmlParserOptions.Default`.
* Security failures raise `EXmlSecurityException` with an `XFE_SEC_*` code.
* Writer output must stay valid: validate names/characters, escape text and attributes, split `]]>`.
* Add a test for every new security-relevant behaviour.

## Error handling conventions

* Library errors derive from `EXmlForgeException` (fields `ErrorCode`, `Line`, `Column`,
  `SourceName`, `Diagnostic`). Use the specific subclass (`EXmlParseException`,
  `EXmlNamespaceException`, `EXmlConversionException`, …) and an `XFE_*` code from
  `XmlForge4D.Types`; add new codes there.
* Parse errors must carry line and column. Free partially built objects before re-raising
  (`try … except Obj.Free; raise; end`).

## Memory / ownership conventions

* A DOM node is owned by its parent; `TXmlDocument` owns the tree. `TXmlDocument.LoadFromXxx`
  returns a new document that **the caller frees**.
* `Doc.CreateXxx` nodes that are never inserted must be freed by the caller; the `AddXxx` helpers
  never leave orphans.
* `TXmlNodeList` (query results) is non-owning; the caller frees the list only.
* `TDataNode` containers own their children. Functions returning `TDataNode`/`TXmlDocument` transfer
  ownership to the caller.
* `TXsdSchema` owns all schema objects through its internal object list.

## Testing

* Add or extend tests in `tests/XmlForge4D.TestSuite.pas` for **every** behaviour change; the suite
  must stay framework-free (it uses `Check` / `CheckEq`).
* New conversion features need: a Standard test, a Lossless round trip (`RoundTrip(...)`), and an
  error-path test.
* Keep tests locale independent and deterministic. `RunAllTests` returns the failure count and the
  runners use it as the process exit code (CI relies on this).
* Performance-sensitive changes: run `./build_fpc.sh bench` before and after and mention the
  numbers in the change description.

## Style

* 2-space indentation, `begin`/`end` on their own lines, keywords lowercase, Pascal-style
  `Name`/`FField`/`AParam` naming (types `T…`, exceptions `E…`, interfaces `I…`).
* Keep public API stable and simple; document new public items in `docs/API.md` and the README if
  user-visible.
* Comments explain *why*; keep unit header comments current (they document supported subsets and
  limits, e.g. `XmlForge4D.Schema`).

## Known gaps / good first tasks

1. **Get it compiling and the suite green on FPC 3.2.x and Delphi 12**, then update
   `docs/COMPATIBILITY.md` and the README status block.
2. Verify the numbers and behaviour asserted in `tests/` by running them; fix real defects in the
   library rather than weakening tests.
3. XSD: `pattern` facet, list/union types, `xsi:type`, identity constraints, ID/IDREF checks.
4. XPath: `namespace::` axis and `id()`.
5. DTD: default attributes (ATTLIST), entity-reference preservation option.
6. Additional encodings (Windows-125x, ISO-8859-x) in `XmlForge4D.Encoding`.
7. YAML/TOML serializers on top of UDM.
8. DOM performance: sibling lookups (`NextSibling`) are O(n); XPath uses index-based iteration —
   keep it that way for hot paths.

## Do / Don't summary

* DO build and run tests before and after every change.
* DO keep Delphi and FPC compatibility in every edit.
* DO document limitations instead of silently ignoring XML features.
* DON'T introduce network/file access driven by document content.
* DON'T compare serialized XML strings to prove round-trip correctness.
* DON'T add dependencies beyond the Pascal RTL.
