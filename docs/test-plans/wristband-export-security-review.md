# Epic 3.1 — Play Library and Export: Security Review

**Date:** 2026-06-07
**Branch:** `feat/play-library-and-export`
**Reviewer:** Security Engineer (post-implementation, Step 9)
**Prior gate:** Plan security review (Step 5.5) — PASS

---

## Scope

This is the post-implementation static code review and active verification for Epic 3.1 (Play Library and Export).
The feature adds:
- `PlayLibraryStore` — persistent JSON library of saved plays
- `WristbandPDFGenerator` and `CatalogPDFGenerator` — PDF generation via PDFKit
- `PlayLibraryView` — multi-select, swipe-delete, bulk export share sheet
- `PlayCallerView` — quick-export share sheet for the current play

Security requirements REQ-SEC-1 through REQ-SEC-5 were specified in the design/plan phase.

---

## Active Verification Scope Note

This is a local, single-user iOS application with no network surface, no authentication layer, no multi-tenant data, and no backend. The following attack classes are NOT APPLICABLE to this feature and are explicitly excluded from active verification:

- IDOR / cross-user resource access (no multi-user model)
- Auth bypass / session manipulation (no authentication)
- Forged tokens, cursors, or signed parameters (no server-side state)
- SQL injection (no database; persistence is local JSON)
- SSRF (no outbound HTTP calls)
- XSS (native UIKit/SwiftUI; no web renderer)

Active verification for this feature is code-level only: verify that each security requirement is present at the correct code location.

---

## REQ-SEC-1: PDF metadata — only `titleAttribute` set; no author/creator/subject

**Requirement:** `document.documentAttributes` must contain only `PDFDocumentAttribute.titleAttribute`. No `authorAttribute`, `creatorAttribute`, `subjectAttribute`, or other device-identifying fields.

| File | Line(s) | Evidence | Status |
|------|---------|----------|--------|
| `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` | 170 | `document.documentAttributes = [PDFDocumentAttribute.titleAttribute: titleString]` — single-key dictionary | **VERIFIED** |
| `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` | 136 | `document.documentAttributes = [PDFDocumentAttribute.titleAttribute: title]` — single-key dictionary | **VERIFIED** |

No prohibited attributes (`authorAttribute`, `creatorAttribute`, `subjectAttribute`, `keywordsAttribute`) appear anywhere in either generator file.

---

## REQ-SEC-2: PDF temp file written to `temporaryDirectory`, NOT Documents

**Requirement:** The PDF temp file must be placed under `FileManager.default.temporaryDirectory`, not under the Documents directory. `temporaryDirectory` is excluded from iCloud backup and user-visible Files app by default.

| File | Line(s) | Evidence | Status |
|------|---------|----------|--------|
| `SpartansPlaycaller/Views/PlayLibraryView.swift` | 153 | `FileManager.default.temporaryDirectory.appendingPathComponent(filename)` | **VERIFIED** |
| `SpartansPlaycaller/Views/PlayCallerView.swift` | 121 | `FileManager.default.temporaryDirectory.appendingPathComponent(filename)` | **VERIFIED** |

Neither path references `.documentDirectory`, `NSSearchPathDirectory.documentDirectory`, or any equivalent.

---

## REQ-SEC-3: PDF temp file written with `.completeFileProtection`

**Requirement:** The `Data.write(to:options:)` call must pass `.completeFileProtection`, which maps to `NSDataWritingFileProtectionComplete`. This protects the file when the device is locked.

| File | Line(s) | Evidence | Status |
|------|---------|----------|--------|
| `SpartansPlaycaller/Views/PlayLibraryView.swift` | 157 | `try data.write(to: tempURL, options: .completeFileProtection)` | **VERIFIED** |
| `SpartansPlaycaller/Views/PlayCallerView.swift` | 124 | `try pdfData.write(to: tempURL, options: .completeFileProtection)` | **VERIFIED** |

Note on runtime behavior: `.completeFileProtection` is a code-level claim. The actual OS enforcement of the protection class requires the device to have a passcode set. On a device without a passcode, the file is written but the protection class has no blocking effect — this is standard iOS behavior and is outside the application's control. No additional code mitigation is warranted.

---

## REQ-SEC-4: Completion handler cleans up temp file after share sheet dismisses

**Requirement:** `UIActivityViewController.completionWithItemsHandler` must call `FileManager.default.removeItem(at:)` to delete the temp file regardless of share outcome (completed, cancelled, or errored).

| File | Line(s) | Evidence | Status |
|------|---------|----------|--------|
| `SpartansPlaycaller/Views/PlayLibraryView.swift` | 165–167 | `activityVC.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: tempURL) }` — all four parameters wildcarded; fires on every dismissal path | **VERIFIED** |
| `SpartansPlaycaller/Views/PlayCallerView.swift` | 131–133 | `activityVC.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: tempURL) }` — same pattern | **VERIFIED** |

The `tempURL` is captured by the closure from the enclosing scope. The wildcard on all four parameters (`activityType`, `completed`, `returnedItems`, `error`) ensures cleanup fires on cancel as well as successful share. The `try?` suppresses errors from a file that was already removed or never written; this is acceptable for a best-effort cleanup.

Edge case noted but not blocking: if the application is force-killed between file write and share sheet dismissal, the temp file will persist in `temporaryDirectory` until the OS clears it (typically on next boot or OS storage pressure). This is an unavoidable limitation of `UIActivityViewController`'s lifecycle and does not warrant a code change.

---

## REQ-SEC-5: Library JSON written with `.completeFileProtection`

**Requirement:** `PlayLibraryStore.persist()` must write the JSON file with `.completeFileProtection`.

| File | Line(s) | Evidence | Status |
|------|---------|----------|--------|
| `SpartansPlaycaller/Services/PlayLibraryStore.swift` | 49 | `try data.write(to: fileURL, options: .completeFileProtection)` | **VERIFIED** |

The protection is applied on every write (initial save and every subsequent persist). The `load()` call at init reads without re-asserting the protection class, which is correct — the OS retains the protection class from write time.

---

## Plan Review Advisory — Filename Sanitization (Finding 1)

The Step 5.5 plan review flagged an advisory: verify that user-controlled data (formation name, route digits) does not appear in the temp filename in the quick-export path, where it could introduce path traversal or unexpected filesystem behavior.

**Resolution status: RESOLVED**

Verified in `PlayCallerView.swift` lines 119–120:

```swift
let modeSuffix = mode == .catalog ? "catalog" : "wristband"
let filename = "\(UUID().uuidString)-1-play-\(modeSuffix).pdf"
```

The filename consists entirely of:
1. A `UUID().uuidString` — random, no user input
2. The hardcoded string `"-1-play-"`
3. `modeSuffix` — one of two hardcoded string literals, determined by the `ExportMode` enum value, not by any user-provided string

Formation name, route digits, concept name, and motion label do NOT appear in the filename in either `PlayLibraryView.swift` (lines 151–153) or `PlayCallerView.swift` (lines 119–121). The advisory is fully addressed.

---

## Summary

| Requirement | Status |
|-------------|--------|
| REQ-SEC-1: PDF metadata stripped (title only) | VERIFIED — both generators |
| REQ-SEC-2: Temp file in `temporaryDirectory` | VERIFIED — both export paths |
| REQ-SEC-3: Temp file with `.completeFileProtection` | VERIFIED — both export paths |
| REQ-SEC-4: Completion handler cleans up temp file | VERIFIED — both export paths |
| REQ-SEC-5: Library JSON with `.completeFileProtection` | VERIFIED |
| Finding 1 advisory: filename sanitization | RESOLVED |

**Overall verdict: PASS**

No security issues found. All five requirements are implemented correctly and consistently across both export paths. The one advisory from plan review is resolved in the implementation. Residual risk items (device-without-passcode file protection, force-kill temp file survival) are platform constraints, not code defects.
