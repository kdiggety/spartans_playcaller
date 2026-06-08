# Security Consultation: Epic 3.1 — Wristband Export

**Date:** 2026-06-07
**Author:** Security Engineer
**Phase:** 1 — Design Consultation
**Feature:** Wristband PDF Export via PDFKit + UIActivityViewController
**Spec reference:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`

---

## Executive Summary

This is a low-risk feature with a narrow, well-understood security surface. PDFKit runs entirely on-device with no network component, no credentials, no user accounts, and no persistent storage in V1. The primary security-relevant decisions are operational in nature — what metadata PDFKit embeds in the PDF, how any temporary file is handled on disk, and whether coaches need to be aware of what happens when they share through the system share sheet. None of these constitute a significant threat to confidentiality, integrity, or availability in a coaching iOS app context. Required controls are small, concrete, and implementable in a single pass.

---

## 1. Threat Surface

### What this feature actually exposes

The export flow is: in-memory `PlayCall` object -> PDFKit rendering -> `Data` blob (or temporary file) -> `UIActivityViewController` -> coach's chosen destination (printer, Files, email, AirDrop).

There is no backend. There is no network call this code makes. There are no credentials to handle. There is no authentication boundary being crossed. The app has one class of user (the coach who installed it).

### Genuine attack surface

**1a. PDF metadata disclosure (low, operational risk only)**
PDFKit embeds document metadata by default: creation date, modification date, and the producing application name. On macOS and iOS, the producer string typically resolves to something like `"PDFKit, Apple Inc."` or the bundle ID. The creation timestamp is current date/time. This is not a privacy violation in the traditional sense, but for coaches who share PDFs digitally before printing (coaching staff AirDrop coordination), the timestamp provides a rough indication of when the PDF was generated. This is unlikely to matter to any adversary in a high school / college football context, but it is worth controlling because controlling it costs nothing.

PDFKit does NOT embed the coach's name, Apple ID, or device identifier in PDF metadata by default. The author field is empty unless explicitly set.

**1b. Temporary file exposure (low, theoretical)**
If the implementation writes the PDF `Data` to a file on disk before handing it to `UIActivityViewController` (which is one valid pattern), that file exists in the app's sandbox for some window of time. On a non-jailbroken iOS device, only this app can read that file. This is not an exploitable attack in practice — no other process on iOS can reach the app's container without a privilege escalation exploit. The correct control is hygienic cleanup, not a security gate.

**1c. Share sheet data routing (low, by design)**
When `UIActivityViewController` is invoked, iOS offers the PDF to all registered share extensions the user has installed — including third-party mail apps, cloud storage services, and messaging apps. A coach who taps "Upload to Dropbox" is intentionally choosing that destination. The play data reaching Dropbox is not a security failure; it is the feature working. The risk is coach awareness that the share sheet presents any installed extension, not just the ones listed in the spec. This is standard iOS behavior and is not a code-level concern.

**1d. Clipboard (non-issue for this feature)**
UIActivityViewController does not write to the system clipboard; it presents the PDF to extensions. No clipboard risk.

**1e. Playbook data sensitivity (context, not a code threat)**
Play calls are proprietary coaching strategy. In a competitive context, a coach might reasonably not want opponent staff to see their wristband cards before a game. This is an operational security concern for coaches (keep your phone locked, be careful who you AirDrop to), not a control the app can or should enforce. PDF password protection was explicitly rejected in the spec (reasonable: adds friction, no compliance requirement). This is documented here so the decision is on record; it is not a finding.

### What is NOT in scope (confirmed non-surface)

- Network interception: no network calls.
- Server-side injection: no server.
- Authentication bypass: no auth.
- Session manipulation: no sessions.
- IDOR / cross-user access: single user, no accounts.
- SQL injection: no database.
- Credential storage: no credentials exist.
- Third-party dependency risk: PDFKit is a first-party Apple framework.

---

## 2. PDF Metadata Risk

### What PDFKit embeds by default

When creating a `PDFDocument` programmatically in iOS, the following metadata attributes are populated unless explicitly cleared:

- `PDFDocumentAttribute.creationDateAttribute` — current timestamp (auto-set)
- `PDFDocumentAttribute.modificationDateAttribute` — current timestamp (auto-set)
- `PDFDocumentAttribute.producerAttribute` — PDFKit library string (auto-set by framework)
- `PDFDocumentAttribute.creatorAttribute` — empty unless set
- `PDFDocumentAttribute.authorAttribute` — empty unless set
- `PDFDocumentAttribute.titleAttribute` — empty unless set
- `PDFDocumentAttribute.subjectAttribute` — empty unless set

The automatic timestamps and producer string are the only non-empty defaults that carry any information. The author field is NOT populated automatically from the device owner's name or Apple ID — that concern is not present here.

### Actual risk assessment

**Timestamps:** The creation timestamp tells a recipient when the PDF was made. For wristband cards shared among coaching staff, this is harmless. For a PDF that gets forwarded outside the expected audience, the timestamp might reveal when a play was finalized before a game. This is an operational detail, not a privacy violation. Stripping it costs nothing.

**Producer string:** Reveals the app used to generate the PDF. In a game-scouting context, an opponent learning the coaching staff uses Spartans Playcaller is negligible intelligence. Not worth engineering effort beyond what is already recommended for timestamps.

**Recommendation:** Strip or explicitly set metadata at PDF creation time. This is one call per attribute. Set title to the formation+digits string (useful for Files app display), leave author/subject/creator empty, and either set a fixed creation date far in the past (unusual) or simply clear the date attributes by setting them to nil. The practical approach: set title to a meaningful value; clear author, subject, and keyword attributes; accept that timestamps will be present (they are essentially harmless here but can be omitted if desired).

If the implementation uses `PDFDocument.documentAttributes` as a dictionary, the software-engineer should set only the attributes that serve the user (title) and leave everything else absent.

---

## 3. Temporary File Handling

### Implementation paths and their file implications

The spec requires `WristbandPDFGenerator.generate(playCall:)` to return `Data`. The two realistic implementation patterns:

**Pattern A (preferred): In-memory only**
Generate the PDF entirely in memory using `PDFDocument` / `PDFPage` with a `CGContext` backed by `NSMutableData`. Call `PDFDocument.dataRepresentation()` and return the `Data`. No file ever touches disk. `UIActivityViewController` can be initialized with `Data` directly, though the idiomatic approach is to pass a file URL (which would require Pattern B).

**Pattern B: Write temp file, share URL**
`UIActivityViewController` initialized with a file URL is the more common pattern for documents because it allows the system to name the file correctly in Save-to-Files scenarios. In this pattern, the implementation writes the `Data` to a temporary file, passes the URL to `UIActivityViewController`, and must clean up afterward.

For V1, the spec already specifies a default filename of `"[FormationName]-[Digits]-wristband.pdf"` in Story 3.1.4. This strongly implies the share sheet receives a named file, which favors Pattern B with a URL. The implementation should assume Pattern B and handle cleanup.

### Correct temp file location

Use `FileManager.default.temporaryDirectory` (which resolves to `NSTemporaryDirectory()`). Do NOT write to:
- The Documents directory (iCloud-backed, user-visible, persists across launches)
- The Caches directory (persists until system evicts it; unnecessary persistence)
- A custom path outside the app's sandbox container (not possible on iOS without entitlements)

`temporaryDirectory` is appropriate: files there are outside the user-visible Files hierarchy and iOS clears the directory on its own schedule.

### File protection attribute

For the temporary PDF file, apply `.completeUntilFirstUserAuthentication` at minimum. Since this file is created at share-action time (when the device is unlocked and the user is actively using the app), `.complete` is also feasible and more restrictive. The practical guidance:

When writing the temp file, use `Data.write(to:options:)` with `Data.WritingOptions.completeFileProtection`. On iOS, this sets the file's data protection class to `NSFileProtectionComplete`, meaning the file is encrypted and inaccessible when the device is locked. Since the file's entire lifecycle is during an active user session, this attribute will never be the binding constraint — but applying it is correct practice and costs nothing.

### Cleanup after share sheet dismissal

The share sheet completion handler (`UIActivityViewController.completionWithItemsHandler`) fires when the user dismisses the share sheet, regardless of whether they completed a share action. The temp file must be deleted in this handler.

```swift
activityVC.completionWithItemsHandler = { _, _, _, _ in
    try? FileManager.default.removeItem(at: tempURL)
}
```

The `try?` suppression is acceptable here — if the file is already gone (OS cleaned it), that is not an error worth surfacing. If the deletion fails for another reason, the file is still bounded to the app's tmp directory with correct file protection applied.

### Edge case: share sheet not presented

If PDF generation fails and the share sheet is never presented, the temp file should still be deleted in the error-handling path. Implement a `defer` block or explicit cleanup in the error branch.

---

## 4. Share Sheet and Data Leakage

### The core question

When `UIActivityViewController` receives the PDF, every share extension the user has installed can read it (subject to UTType matching). This includes third-party mail clients, cloud storage apps, AirDrop, Messages, and anything else the coach has installed.

### Assessment

This is the intended behavior of the feature. The spec is explicit: "AirPrint, Files, email, AirDrop" are the target destinations. The coach who taps "Upload to Google Drive" is making a deliberate choice. The coach who accidentally taps the wrong extension is operating their device, not the app making an error.

The only mitigation available at the code level would be to restrict the share sheet to a specific set of activity types using `UIActivityViewController.excludedActivityTypes`. The spec does not call for this, and restricting activities would reduce functionality without a meaningful security benefit — a coach who wants to send the PDF somewhere "wrong" can do so through Files app regardless of what the share sheet excludes.

**Conclusion:** No code-level control is warranted here. The operational guidance for coaches (be intentional about where you share wristband cards before a game) belongs in app documentation or onboarding UI, not in a technical restriction.

### AirDrop note

AirDrop respects the receiving device's AirDrop settings ("Contacts Only" vs "Everyone"). The app has no control over the receiving device's settings. This is correct — it is the recipient's responsibility, not the app's.

---

## 5. Security Involvement Assessment

**Risk surface:** On-device PDF generation with no network, no credentials, no persistence, and no auth. The security-relevant decisions are metadata hygiene and temporary file handling — both small and concrete. No adversarial attack class applies to this feature's core implementation.

| Phase | Engagement level | Rationale |
|-------|-----------------|-----------|
| Design consultation (this document) | Lightweight | Feature has no auth, no network, no credentials. Threat surface is bounded and enumerated above. Full engagement is not warranted. |
| Plan review (Step 5.5) | Lightweight | Verify the implementation plan includes: metadata attribute clearing, temp file in `temporaryDirectory`, `.completeFileProtection` write option, and cleanup in the completion handler. These are a checklist of four items, not a design review. |
| Implementation support | On-demand | Unlikely to be needed. The requirements in Section 6 below are complete and unambiguous. The software-engineer should not need security consultation during implementation. |
| Post-implementation verification | Lightweight | Static review: confirm the four requirements from Section 6 are present in `WristbandPDFGenerator.swift` and the `UIActivityViewController` wiring code. Active verification: open a generated PDF in a hex editor or `exiftool` equivalent and confirm metadata is stripped to the expected fields; confirm temp file does not persist after share sheet dismissal. No attack scenarios (IDOR, injection, auth bypass) are applicable. |

**Escalation triggers (would change Light to Full):**

- V2 adds play persistence to a database or cloud — triggers full review of data model, sync, and access controls.
- V2 adds a custom file format with a parser — triggers injection/deserialization review.
- Any network call is introduced in the export path (telemetry, upload, QR code generation) — triggers full network security review.
- Team branding / user profile data is embedded in PDF metadata — triggers PII review.
- PDF password protection is added — triggers review of key management (where is the password stored/displayed?).

---

## 6. Specific Implementation Requirements

These are the concrete security requirements the software-engineer must follow. Each has a verification step.

### REQ-SEC-1: Strip PDF document metadata

**Requirement:** When constructing the `PDFDocument`, set `documentAttributes` explicitly. Include only `PDFDocumentAttribute.titleAttribute` (set to the formation + digits display name for usability in Files app). Do not set `authorAttribute`, `subjectAttribute`, `creatorAttribute`, or `keywordsAttribute`. Do not explicitly set date attributes — if the PDFKit version in use ignores a `nil` date, test whether dates appear in the output and suppress them if possible.

**Verification:** Open the generated PDF in Preview or run `mdls` / `exiftool` on the file. Confirm Author field is empty and Creator/Subject fields are absent or empty. Title should match the play's display name.

**Implementation pattern:**
```swift
pdfDocument.documentAttributes = [
    PDFDocumentAttribute.titleAttribute: "\(formation) \(digits)"
    // No author, creator, subject, or keywords
]
```

### REQ-SEC-2: Write temp file to temporaryDirectory

**Requirement:** If a temporary file is written to disk (Pattern B), use `FileManager.default.temporaryDirectory` as the base path. Generate a unique filename per export (e.g., using `UUID().uuidString` as a prefix) to avoid collisions if two exports run concurrently (unlikely but correct).

**Verification:** Log or assert the temp file path during development; confirm it begins with the expected tmp path.

### REQ-SEC-3: Apply file protection to the temp file write

**Requirement:** Use `Data.write(to: tempURL, options: .completeFileProtection)` when writing the temp file. Do not use `.atomic` without file protection, and do not use a bare `write(to:)` call that takes no options.

**Verification:** Use `FileManager.default.attributesOfItem(atPath:)` in a debug build and log the `FileAttributeKey.protectionKey` value; confirm it is `FileProtectionType.complete`.

### REQ-SEC-4: Delete temp file in share sheet completion handler

**Requirement:** Register `completionWithItemsHandler` on the `UIActivityViewController` before presenting it. In the handler, call `FileManager.default.removeItem(at: tempURL)` (using `try?` or a logged catch). This cleanup must fire whether the user completed a share action or cancelled.

**Requirement (error path):** If PDF generation fails before the share sheet is presented, delete the temp file in the error branch (or use a `defer` block keyed on whether the share sheet was presented).

**Verification:** Set a breakpoint or log in the completion handler during testing; confirm the file no longer exists at `tempURL` after the share sheet dismisses.

### REQ-SEC-5 (advisory, not blocking): Document the share sheet behavior for coaches

**Recommendation:** In the action sheet that precedes the share sheet (the "Export as PDF" / "Cancel" sheet), the message already displays the current play name — which is good UX. No additional security warning is needed. Coaches understand the iOS share sheet. This is noted here to confirm the decision was considered, not to require additional UI.

---

## Residual Risk After Controls

After implementing REQ-SEC-1 through REQ-SEC-4:

- **PDF metadata:** Title contains formation + digits (non-sensitive coaching info). No author or device identity embedded. Timestamps may appear depending on PDFKit version behavior; this is low operational risk.
- **Temp file:** Lives only for the duration of the share sheet session, encrypted at rest, cleaned up on completion. Residual: if the app crashes while the share sheet is open, the temp file survives until iOS clears the tmp directory. This is acceptable — the file is encrypted and sandboxed.
- **Share sheet routing:** Fully intentional by design. No residual concern at the code level.

**Overall residual risk after controls: LOW.** This feature has no structural security debt and no meaningful attack surface in its V1 form.
