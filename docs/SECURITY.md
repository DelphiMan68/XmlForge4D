# Security guide

| Threat | Protection | Option |
|---|---|---|
| XXE / SSRF | External entities (`SYSTEM`/`PUBLIC`) are **never** read from files or networks. A reference raises `EXmlSecurityException` (`XFE_SEC_EXTERNAL_ENTITY`). | `IgnoreExternalEntities = True` expands them to nothing instead |
| External DTD subsets | Not loaded. Parameter entities are skipped. | `DtdMode = dtdProhibit` rejects every DOCTYPE |
| Billion laughs / quadratic blow-up | Total expanded characters limited; nesting depth of entities limited; recursion detected | `MaxEntityExpansion` (1,000,000), `MaxEntityDepth` (16) |
| Deep nesting | Element depth limited (stack-safe parser loop; DOM recursion bounded by this limit) | `MaxDepth` (256) |
| Huge inputs | Bytes read are counted | `MaxDocumentSize` (0 = unlimited — set it for untrusted input) |
| Attribute flooding | Per-element limit | `MaxAttributes` (1024) |
| Invalid characters / encodings | Strict character checks, strict UTF-8/UTF-16 decoding (`EXmlEncodingException`) | – |
| JSON bombs | JSON nesting limited (`TJsonParser`, default 512) | `MaxDepth` parameter |
| Schema loading | The XSD loader never follows `import`/`include`/`redefine` | pass documents to `AddSchemaDocument` yourself |

Recommended settings for untrusted input:

```pascal
Opt := TXmlParserOptions.Default;
Opt.DtdMode := dtdProhibit;
Opt.MaxDocumentSize := 20 * 1024 * 1024;
Opt.MaxDepth := 64;
Doc := TXmlDocument.LoadFromStream(Stream, Opt);
```

Output side: the writer validates names and characters and escapes `& < >`, quotes and control
whitespace in attributes, so values cannot break out of their context. Comments containing `--`, PIs
containing `?>` and invalid names are rejected, `]]>` inside CDATA is split safely.

DOM and conversion code is not thread-safe per instance; use one parser/document per thread.
