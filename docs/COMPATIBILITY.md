# Compatibility matrix

| Compiler | Windows | Linux | macOS | Status |
|---|---|---|---|---|
| Free Pascal 3.2.x (design target) | ✔ designed | ✔ designed | ✔ designed | **not yet verified** — run `build_fpc.sh` / CI |
| Free Pascal 3.0.x | ✔ designed | ✔ designed | ✔ designed | not verified (uses `{$mode delphiunicode}`, needs ≥ 3.0) |
| Delphi 12 (design target) | ✔ designed | n/a | n/a | **not yet verified** — run `build_delphi.bat` |
| Delphi 2009 – 11 | ✔ designed | | | not verified; Unicode strings required |
| Delphi 10.4+ for Linux/macOS/mobile | possible | | | not verified |

"designed" = no known obstacle; "verified" must come from a green CI / local run. The code base
was produced without a compiler available, so **verification is the first task**.

## Portability decisions

* One string type: `XmlString = UnicodeString` everywhere; all character logic works on UTF-16 code
  units. FPC compiles with `{$mode delphiunicode}` (chosen in `XmlForge4D.inc`).
* No generics, anonymous methods, inline variables or other newer syntax; no `TStringBuilder`,
  `TEncoding`, `TDictionary` or `System.Generics.*`.
* Own UTF-8/UTF-16/Latin-1/ASCII codecs, so results do not depend on the OS code page or RTL version.
* Own number parsing/formatting (locale independent: no `FormatSettings` surprises).
* Streams: `TStream`, `TFileStream`, `TMemoryStream` only. File names are plain `string`.
* The only conditional compilation outside `XmlForge4D.inc`:
  `XmlForge4D.XPath` (type name of the FPU exception mask in `Math`) and the memory counter in the
  benchmark. Public interfaces are identical on both compilers.
* Units reference each other without circular *interface* dependencies (`Dom` ↔ `XPath` is
  implementation-level only).

## Likely first-build issues

If a compiler complains, typical suspects are: record `class function … static` syntax on very old
FPC; `SetExceptionMask` set-element names on exotic FPC targets; `Str(Value:0:15, S)` overloads;
anything listed in the compiler's first error. Fix, rebuild, run the suite.

## Verified-by-CI table (fill in when CI runs)

| Date | Compiler | OS | Result |
|---|---|---|---|
| | | | |
