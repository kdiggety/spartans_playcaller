# PDF Card Playcall Labels — Security Review

**Feature:** pdf-card-playcall-labels
**Branch:** feat/pdf-card-playcall-labels
**Date:** 2026-06-08
**Reviewer:** Security Engineer
**Engagement level:** Light (per involvement assessment dated 2026-06-07)
**Baseline:** Epic 3.1 security review (PASS) — REQ-SEC-1 through REQ-SEC-5 all verified

---

## Overall Result: PASS

No new security findings. All three post-implementation checks passed. REQ-SEC-2 and REQ-SEC-5 spot-checks confirmed intact. No escalation triggers from the involvement assessment were tripped.

---

## Post-Implementation Checks

### Check 1 — REQ-SEC-1: Document metadata unchanged

**Requirement:** `document.documentAttributes` in both PDF generators sets only `titleAttribute`. No author, subject, creator, or other PII-bearing metadata keys.

**Command run:**
```
grep -n "documentAttributes" \
  SpartansPlaycaller/Services/WristbandPDFGenerator.swift \
  SpartansPlaycaller/Services/CatalogPDFGenerator.swift
```

**Output:**
```
SpartansPlaycaller/Services/CatalogPDFGenerator.swift:124:        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: title]
SpartansPlaycaller/Services/WristbandPDFGenerator.swift:158:        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: titleString]
```

**Result: PASS.** Exactly two matches. Each sets only `titleAttribute`. No `authorAttribute`, `subjectAttribute`, `creatorAttribute`, or any other key present. The header consolidation change did not introduce any new metadata write.

---

### Check 2 — combinedHeaderString confined to CGContext draw calls

**Requirement:** `combinedHeaderString` is defined once in `ExportCard.swift` and consumed only inside `drawCard()` in each generator. It must not appear in filenames, metadata, URL construction, or any other context.

**Command run:**
```
grep -rn "combinedHeaderString" SpartansPlaycaller/
```

**Output:**
```
SpartansPlaycaller/Models/ExportCard.swift:15:    var combinedHeaderString: String {
SpartansPlaycaller/Services/CatalogPDFGenerator.swift:44:        drawTextLeft(card.combinedHeaderString,
SpartansPlaycaller/Services/WristbandPDFGenerator.swift:48:        drawTextLeft(card.combinedHeaderString,
```

**Result: PASS.** Three matches: one definition (ExportCard.swift), one use in CatalogPDFGenerator inside `drawCard()`, one use in WristbandPDFGenerator inside `drawCard()`. Not used in any filename construction, URL assembly, HTTP parameter, or metadata attribute. No path traversal or injection vector exists.

**Supporting observation:** `combinedHeaderString` is composed of `playNumber` (Int), `formationName` (Formation.rawValue — enum), and `routeDigits` (String derived from route enum digit map). None of these fields are free-form user text input paths — they are coach-authored structured data. The risk profile is unchanged from the Epic 3.1 baseline.

---

### Check 3 — Receiver.rawValue is the sole label source in drawReceiversCG

**Requirement:** The draw call in `drawReceiversCG` uses `assignment.receiver.rawValue` (a Swift enum rawValue, compile-time fixed set {"X","Y","Z","A","H"}) and not any user-editable string.

**Command run:**
```
grep -n "\.draw(" SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift
```

**Output:**
```
198:            (assignment.receiver.rawValue as NSString).draw(
```

**Result: PASS.** Single match. The draw call sources exclusively from `assignment.receiver.rawValue`. The `Receiver` type is a Swift enum with five fixed cases; its rawValue is a compile-time constant string. No user-controlled or externally-sourced string reaches this draw call. No injection vector introduced.

---

## Baseline Requirements Spot-Check

### REQ-SEC-2: Temp file in temporaryDirectory

**Command run:**
```
grep -rn "temporaryDirectory" SpartansPlaycaller/Views/PlayCallerView.swift \
  SpartansPlaycaller/Views/PlayLibraryView.swift
```

**Output:**
```
SpartansPlaycaller/Views/PlayCallerView.swift:121:        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
SpartansPlaycaller/Views/PlayLibraryView.swift:150:        // REQ-SEC-2: temp file in temporaryDirectory
SpartansPlaycaller/Views/PlayLibraryView.swift:153:        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
```

**Result: PASS.** Both export paths write to `FileManager.default.temporaryDirectory`. No new file write location was introduced by this feature. PlayLibraryView.swift retains the REQ-SEC-2 annotation comment. Unchanged from Epic 3.1 baseline.

---

### REQ-SEC-5: .completeFileProtection on library JSON write

**Command run:**
```
grep -n "completeFileProtection" SpartansPlaycaller/Services/PlayLibraryStore.swift
```

**Output:**
```
49:            try data.write(to: fileURL, options: .completeFileProtection)
```

**Result: PASS.** `PlayLibraryStore` still writes with `.completeFileProtection`. This path was not touched by the pdf-card-playcall-labels feature and remains intact.

---

## Escalation Triggers Assessment

The involvement assessment listed four conditions that would upgrade engagement from Light to Full. Checking each against the implemented diff:

| Trigger | Status |
|---------|--------|
| `formationName` or `routeDigits` embedded in filename or metadata attribute | Not tripped. Both fields are used only in `combinedHeaderString`, which is used only in `drawCard()` draw calls. |
| New `String` input from user-facing UI passed directly to a draw call without validation | Not tripped. No new UI input path was introduced. |
| New file path or write location introduced | Not tripped. No new file I/O. |
| PDFKit document attributes modified | Not tripped. Check 1 confirms only `titleAttribute` is set, unchanged from baseline. |

No escalation triggered. Light engagement level confirmed appropriate for this feature.

---

## Active Verification

Per the involvement assessment, active attack probes (IDOR, forged inputs, auth bypass, injection) are not in scope for this feature. The change surface is rendering-only, with no new trust boundaries, no new data inputs, and no new inter-process surface. Grep-level verification against the final implementation is the documented scope for this engagement level.

---

## Residual Risk

No new residual risk introduced. The two residual risks carried forward from Epic 3.1 remain:

1. **Device without passcode:** `.completeFileProtection` (REQ-SEC-5) is a no-op on a device with no passcode set — platform constraint, not a code defect. Accepted.
2. **Force-kill during share sheet:** A force-kill between PDF write and share sheet dismissal leaves the temp file in `temporaryDirectory` until iOS clears it — `UIActivityViewController` lifecycle limitation. Accepted.

Both were documented and accepted in `wristband-export-security-review.md`.

---

## Summary

All three required post-implementation checks PASS. Both baseline requirement spot-checks (REQ-SEC-2, REQ-SEC-5) PASS. No escalation triggers were tripped. No new security findings. The pdf-card-playcall-labels feature is cleared from a security standpoint.
