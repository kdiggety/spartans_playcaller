# PDF Card Labels — Security Involvement Assessment

**Date:** 2026-06-07
**Feature:** PDF export card header restructure + receiver letter labels in diagram dots
**Assessor:** Security Engineer
**Prior baseline:** Epic 3.1 security review (PASS) — REQ-SEC-1 through REQ-SEC-5 all verified

---

## Change Summary

Two rendering-only changes to existing PDF generation code:

1. **Card header restructure** (`WristbandPDFGenerator.swift`, `CatalogPDFGenerator.swift`) — Reorganises text draw calls inside `drawCard()`. Removes 3 individual draw calls and replaces with 1 combined call. No new data, no new inputs, no new file I/O. Data source is the same `ExportCard` struct already reviewed.

2. **Receiver letter labels** (`DiagramRenderer+CGContext.swift`) — Draws X/Y/Z/A/H letter strings inside receiver dots. Data source is the `Receiver` Swift enum — a closed, compiler-enforced type with five fixed cases. Not user input. Not injectable.

---

## Security Involvement Assessment

**Risk surface:** These changes are pure rendering mutations inside already-audited CGContext draw pipelines. No new data sources, no new file paths, no new network surface, no new permissions, no new inter-process boundaries. The `Receiver` enum is a typed Swift enum — its string representation (`rawValue`) is a fixed set of single characters defined at compile time. The five hardcoded strings `["X", "Y", "Z", "A", "H"]` in `drawCard()` are string literals, not derived from any user-controlled or external input.

| Phase | Engagement level | Rationale |
|-------|-----------------|-----------|
| Design | Light | No new trust boundaries, data flows, or permission requests. Rendering-layer only. |
| Plan review | Light | No new credential handling, no new file I/O pattern, no new authz surface. The existing security requirements are untouched. Standard plan review checklist is sufficient — verify no new data path introduced. |
| Implementation support | On-demand (unlikely) | No foreseeable ambiguity. The only security-adjacent call site is the existing `drawText()` helper, which accepts a `String` and renders it to a fixed CGRect — no dynamic sizing that could overflow or disclose adjacent memory. |
| Active verification | Light | No new attack surface to probe. Verification is a single confirmation that the five existing REQ-SEC requirements remain intact after the diff lands (not a re-run of active probes). |

**Escalation triggers:** The following would upgrade any phase from Light to Full:
- If `formationName` or `routeDigits` are embedded in a filename or metadata attribute (path traversal risk)
- If a new `String` input is accepted from user-facing UI and passed directly into a draw call without validation
- If a new file path or write location is introduced (e.g., saving the labelled diagram as a separate asset)
- If PDFKit document attributes are modified (metadata disclosure risk — REQ-SEC-1)

None of these conditions exist in the described changes.

---

## Specific Risks Introduced

**Finding: None.**

Detailed analysis by change:

**Change 1 — Card header restructure:**
The data rendered (`card.formationName`, `card.routeDigits`, `card.playNumber`) is identical to what was already audited in Epic 3.1. Consolidating draw calls does not change the data origin or the rendering path. The `drawText()` helper that receives this data renders to a bounded `CGRect` and calls `NSString.draw(in:withAttributes:)` — a UIKit call with no memory safety exposure surface at the application layer. No injection vector exists: the data is coach-authored plain text, not parsed from an external format or network response.

**Change 2 — Receiver letter labels in diagram dots:**
The `Receiver` enum is defined as `enum Receiver: String, CaseIterable, Identifiable` with five fixed cases. The `receiverCGColor(for:)` switch in `DiagramRenderer+CGContext.swift` already exhausts all cases. Drawing the `rawValue` of a compiler-enumerated type is equivalent to drawing a compile-time constant — the set of possible strings is `{"X", "Y", "Z", "A", "H"}`, fully determined at build time. The `["X", "Y", "Z", "A", "H"].prefix(labelCount)` pattern in `drawCard()` additionally gates the count by `card.routeDigits.count`, which is the length of an already-persisted string — no out-of-bounds indexing risk.

---

## Post-Implementation Review Requirement

**Yes, a lightweight confirmation is required** (consistent with CLAUDE.md's unconditional security-engineer involvement at Step 9/10), but the scope is minimal:

1. Verify REQ-SEC-1 is still satisfied: confirm `document.documentAttributes` in both generators still sets only `titleAttribute` and that no labelling change caused a new metadata write.
2. Confirm no new `String` interpolation from user-controlled fields was introduced in the `drawCard()` restructure beyond what already existed.
3. Confirm `Receiver.rawValue` (or the hardcoded literal array) is the only data source for the new label draw calls — not a user-editable field.

These checks are grep-level verifications against the final diff, not a re-execution of active attack probes. The five REQ-SEC requirements and the filename sanitization finding from Epic 3.1 do not need re-verification unless the diff touches those specific code paths.

**Expected outcome:** PASS with no new findings. If the implementation matches the description above, no security issues are anticipated.

---

## Residual Risk

None introduced by this change. Residual risks carried forward from Epic 3.1 remain:
- Device-without-passcode renders `.completeFileProtection` a no-op — platform constraint, not a code defect.
- Force-kill between PDF write and share sheet dismissal leaves temp file in `temporaryDirectory` — unavoidable `UIActivityViewController` lifecycle limitation.

Both were accepted and documented in `wristband-export-security-review.md`.
