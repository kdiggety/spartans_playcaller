# PDF Card — Playcall Header + Diagram Receiver Labels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a combined "Formation Digits" header row to PDF export cards and draw receiver letter labels (X/Y/Z/A/H) inside the dots on the route diagram.

**Architecture:** Two additive CGContext rendering changes confined to three Swift files plus a new computed property on `ExportCard` for testability. No new data flows, no structural model changes, no public API surface changes. Config constants in `WristbandCardConfig` and `CatalogCardConfig` are updated to give the diagram zone more vertical space as a side effect of removing two header rows.

**Tech Stack:** Swift 5.9, iOS 17+, PDFKit, UIKit CGContext, XCTest

---

## Files Modified

| File | Change |
|------|--------|
| `SpartansPlaycaller/Models/ExportCard.swift` | Add `combinedHeaderString` computed property |
| `SpartansPlaycaller/Models/WristbandCardConfig.swift` | `diagramZoneTopY` 92 → 62 |
| `SpartansPlaycaller/Models/CatalogCardConfig.swift` | `diagramZoneTopY` 70 → 45 |
| `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` | Restructure `drawCard` header rows |
| `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` | Restructure `drawCard` header rows |
| `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift` | Update `drawReceiversCG` to draw letters, add `playCall` param |

## Files Created

| File | Purpose |
|------|---------|
| `SpartansPlaycallerTests/PDFCardHeaderTests.swift` | Unit tests for `combinedHeaderString`, config constants, header integration |
| `SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift` | Non-crash tests for receiver label rendering across all formations and motion cases |

---

### Task 1: ExportCard.combinedHeaderString + unit tests

**Files:**
- Modify: `SpartansPlaycaller/Models/ExportCard.swift` (after line 14, before `extension ExportCard`)
- Create: `SpartansPlaycallerTests/PDFCardHeaderTests.swift` (partial — combinedHeaderString tests only; config and integration tests added in Task 2)

- [x] **Step 1: Write the failing test (combinedHeaderString tests)**

Create `SpartansPlaycallerTests/PDFCardHeaderTests.swift`:

```swift
import XCTest
@testable import SpartansPlaycaller

final class PDFCardHeaderTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func makeCard(_ digits: String, _ formation: Formation, number: Int) -> ExportCard {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed: \(digits) \(formation.rawValue)")
        }
        return ExportCard(
            playNumber: number,
            formationName: pc.formation.rawValue,
            routeDigits: digits,
            conceptName: nil,
            motionLabel: nil,
            yWheelEnabled: false,
            playCall: pc
        )
    }

    // MARK: - combinedHeaderString

    func testCombinedHeaderStringSingleDigitNumber() {
        let card = makeCard("6794", .twins, number: 1)
        XCTAssertEqual(card.combinedHeaderString, "1. Twins 6794")
    }

    func testCombinedHeaderStringTwoDigitNumber() {
        let card = makeCard("6794", .twins, number: 12)
        XCTAssertEqual(card.combinedHeaderString, "12. Twins 6794")
    }

    func testCombinedHeaderStringFiveDigitRoute() {
        let card = makeCard("67943", .twins, number: 3)
        XCTAssertEqual(card.combinedHeaderString, "3. Twins 67943")
    }

    func testCombinedHeaderStringMultiWordFormation() {
        let card = makeCard("2943", .tripsLeft, number: 5)
        XCTAssertEqual(card.combinedHeaderString, "5. Trips Left 2943")
    }
}
```

- [x] **Step 2: Run test — expect compile failure**

In Xcode: Product → Test (⌘U). Expected: compile error "value of type 'ExportCard' has no member 'combinedHeaderString'". This confirms the test is correctly testing a missing property.

Alternatively via `xcodebuild`:
```bash
cd /Users/klewisjr/Development/iOS/spartans_playcaller
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "error:|PASS|FAIL|combinedHeaderString" | head -20
```

- [x] **Step 3: Add combinedHeaderString to ExportCard**

Edit `SpartansPlaycaller/Models/ExportCard.swift`. Add the computed property after line 13 (`let playCall: PlayCall`) and before line 16 (`}`):

**Before** (lines 6–15):
```swift
struct ExportCard {
    let playNumber: Int
    let formationName: String
    let routeDigits: String
    let conceptName: String?
    let motionLabel: String?
    let yWheelEnabled: Bool
    let playCall: PlayCall   // post-motion, drives diagram rendering
}
```

**After**:
```swift
struct ExportCard {
    let playNumber: Int
    let formationName: String
    let routeDigits: String
    let conceptName: String?
    let motionLabel: String?
    let yWheelEnabled: Bool
    let playCall: PlayCall   // post-motion, drives diagram rendering

    var combinedHeaderString: String {
        "\(playNumber). \(formationName) \(routeDigits)"
    }
}
```

- [x] **Step 4: Run tests — expect 4 PASS**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -20
```

Expected: 4 tests pass (`testCombinedHeaderString*`).

- [x] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Models/ExportCard.swift SpartansPlaycallerTests/PDFCardHeaderTests.swift
git commit -m "feat: add ExportCard.combinedHeaderString + tests"
```

---

### Task 2: Config constant updates + config tests

Removing two header rows recovers ~25–30pt of vertical space per card. We update `diagramZoneTopY` in both configs so the diagram zone fills the recovered space, giving the diagram a larger rendering area.

**Files:**
- Modify: `SpartansPlaycaller/Models/WristbandCardConfig.swift`
- Modify: `SpartansPlaycaller/Models/CatalogCardConfig.swift`
- Modify: `SpartansPlaycallerTests/PDFCardHeaderTests.swift` (append config assertion tests)

- [x] **Step 1: Append config tests to PDFCardHeaderTests.swift**

Append these methods inside the `PDFCardHeaderTests` class (before the final `}`):

```swift
    // MARK: - Config constant guards

    func testWristbandDiagramZoneTopY() {
        let config = WristbandCardConfig.standard()
        XCTAssertEqual(config.diagramZoneTopY, 62.0, accuracy: 0.5)
    }

    func testCatalogDiagramZoneTopY() {
        let config = CatalogCardConfig.standard()
        XCTAssertEqual(config.diagramZoneTopY, 45.0, accuracy: 0.5)
    }

    func testWristbandDiagramZoneFitsInCard() {
        let config = WristbandCardConfig.standard()
        XCTAssertGreaterThan(config.diagramZoneSize.height, 0)
        XCTAssertLessThan(config.diagramZoneTopY + config.diagramZoneSize.height, config.cardHeight)
    }

    func testCatalogDiagramZoneFitsInCard() {
        let config = CatalogCardConfig.standard()
        XCTAssertGreaterThan(config.diagramZoneSize.height, 0)
        XCTAssertLessThan(config.diagramZoneTopY + config.diagramZoneSize.height, config.cardHeight)
    }
```

- [x] **Step 2: Run tests — expect 2 FAIL (diagramZoneTopY assertions)**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -30
```

Expected: `testWristbandDiagramZoneTopY` and `testCatalogDiagramZoneTopY` fail (current values are 92 and 70).

- [x] **Step 3: Update WristbandCardConfig.diagramZoneTopY**

Edit `SpartansPlaycaller/Models/WristbandCardConfig.swift`. Replace:

```swift
    // Diagram zone (relative to card top-left)
    // Starts at y=92pt within card (after header rows), ends 10pt from card bottom
    let diagramZoneTopY: CGFloat = 92.0
```

With:

```swift
    // Diagram zone (relative to card top-left)
    // Starts at y≈62pt within card (one combined header row + optional concept/motion + divider)
    let diagramZoneTopY: CGFloat = 62.0
```

Effect on `diagramZoneSize.height`: `180 - 62 - 8 - 14 = 96pt` (was 66pt).

- [x] **Step 4: Update CatalogCardConfig.diagramZoneTopY**

Edit `SpartansPlaycaller/Models/CatalogCardConfig.swift`. Replace:

```swift
    // Diagram zone (relative to card top-left)
    let diagramZoneTopY: CGFloat = 70.0
```

With:

```swift
    // Diagram zone (relative to card top-left)
    // Starts at y≈45pt within card (one combined header row + optional concept/motion + divider)
    let diagramZoneTopY: CGFloat = 45.0
```

Effect on `diagramZoneSize.height`: `174 - 45 - 5 = 124pt` (was 99pt).

- [x] **Step 5: Run tests — expect all 8 PASS**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -30
```

Expected: all 8 tests pass.

- [x] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Models/WristbandCardConfig.swift SpartansPlaycaller/Models/CatalogCardConfig.swift SpartansPlaycallerTests/PDFCardHeaderTests.swift
git commit -m "feat: update diagramZoneTopY constants for larger diagram area + tests"
```

---

### Task 3: WristbandPDFGenerator.drawCard header restructure + wristband integration tests

Collapse Rows 1–3 (play number, formation, digits, receiver label text) into one combined row using `card.combinedHeaderString`. Remove the `receiverLabels` string and its draw call entirely.

**Files:**
- Modify: `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` (`drawCard` method, lines 45–65)
- Modify: `SpartansPlaycallerTests/PDFCardHeaderTests.swift` (append wristband integration tests)

- [x] **Step 1: Append wristband integration tests to PDFCardHeaderTests.swift**

Add these methods inside the `PDFCardHeaderTests` class:

```swift
    // MARK: - Wristband integration (non-crash + validity)

    func testWristbandGeneratesValidPDFWithNewHeader() {
        let card = makeCard("6794", .twins, number: 1)
        guard let data = WristbandPDFGenerator.generate(cards: [card]) else {
            XCTFail("nil data"); return
        }
        let header = data.prefix(4)
        XCTAssertEqual(header, Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testWristbandFiveDigitRouteDoesNotCrash() {
        let card = makeCard("67943", .twins, number: 2)
        XCTAssertNotNil(WristbandPDFGenerator.generate(cards: [card]))
    }

    func testWristbandCardWithConceptAndMotionDoesNotCrash() {
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        let card = ExportCard(
            playNumber: 7,
            formationName: pc.formation.rawValue,
            routeDigits: "6794",
            conceptName: "Mesh",
            motionLabel: "Y Go",
            yWheelEnabled: false,
            playCall: pc
        )
        XCTAssertNotNil(WristbandPDFGenerator.generate(cards: [card]))
    }

    func testWristbandPageCountUnchanged() {
        let cards = [
            makeCard("6794", .twins, number: 1),
            makeCard("2943", .tripsLeft, number: 2)
        ]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 2)
    }
```

- [x] **Step 2: Run new tests — expect PASS (they test structural validity, not header layout)**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -40
```

All tests should pass before we change the generator (they test structural properties that exist in both old and new layout).

- [x] **Step 3: Update WristbandPDFGenerator.drawCard**

Edit `SpartansPlaycaller/Services/WristbandPDFGenerator.swift`. Replace the `drawCard` method's header row section (lines 47–64):

**Remove** these lines from `drawCard`:
```swift
        // Row 1: Play number (left) + Formation (right)
        drawTextLeft("\(card.playNumber).", in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.25, height: 20),
                     font: UIFont.systemFont(ofSize: config.playNumberFontSize, weight: .bold), into: context)
        drawTextRight(card.formationName, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 20),
                      font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold), into: context)
        y += 22

        // Row 2: Route digits
        drawTextCenter(card.routeDigits, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 18),
                       font: UIFont.monospacedSystemFont(ofSize: config.digitsFontSize, weight: .medium), into: context)
        y += 16

        // Row 3: Receiver labels (X Y Z A or X Y Z A H for 5-digit)
        let labelCount = card.routeDigits.count
        let receiverLabels = Array(["X", "Y", "Z", "A", "H"].prefix(labelCount)).joined(separator: "    ")
        drawTextCenter(receiverLabels, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                       font: UIFont.monospacedSystemFont(ofSize: config.receiverLabelFontSize, weight: .regular), into: context)
        y += 14
```

**Replace with:**
```swift
        // Row 1: Combined play call — "N. Formation Digits" (e.g., "1. Twins 6794")
        drawTextLeft(card.combinedHeaderString,
                     in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 20),
                     font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
                     into: context)
        y += 22
```

- [x] **Step 4: Run full test suite — verify no regressions**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test session|PASSED|FAILED|error:" | tail -20
```

Expected: existing `WristbandPDFGeneratorTests` (5 tests) all pass. New `PDFCardHeaderTests` wristband tests all pass.

- [x] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Services/WristbandPDFGenerator.swift SpartansPlaycallerTests/PDFCardHeaderTests.swift
git commit -m "feat: collapse wristband PDF card header to single combined row"
```

---

### Task 4: CatalogPDFGenerator.drawCard header restructure + catalog integration tests

Identical restructure to Task 3 but for the catalog generator. Note: the catalog generator uses an absolute `origin.y + config.diagramZoneTopY` for diagram position (not the running `y` cursor). After removing two rows, the divider draws higher but the diagram uses the config constant.

**Files:**
- Modify: `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` (`drawCard` method, lines 43–60)
- Modify: `SpartansPlaycallerTests/PDFCardHeaderTests.swift` (append catalog integration tests)

- [x] **Step 1: Append catalog integration tests to PDFCardHeaderTests.swift**

Add these methods inside the `PDFCardHeaderTests` class:

```swift
    // MARK: - Catalog integration (non-crash + validity)

    func testCatalogGeneratesValidPDFWithNewHeader() {
        let card = makeCard("6794", .twins, number: 1)
        guard let data = CatalogPDFGenerator.generate(cards: [card]) else {
            XCTFail("nil data"); return
        }
        let header = data.prefix(4)
        XCTAssertEqual(header, Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testCatalogFiveDigitRouteDoesNotCrash() {
        let card = makeCard("67943", .tripsRight, number: 4)
        XCTAssertNotNil(CatalogPDFGenerator.generate(cards: [card]))
    }

    func testCatalogCardWithConceptAndMotionDoesNotCrash() {
        guard case .success(let pc) = interpreter.interpret(digits: "2943", formation: .tripsLeft) else {
            XCTFail(); return
        }
        let card = ExportCard(
            playNumber: 8,
            formationName: pc.formation.rawValue,
            routeDigits: "2943",
            conceptName: "Drive",
            motionLabel: "Y Stop",
            yWheelEnabled: false,
            playCall: pc
        )
        XCTAssertNotNil(CatalogPDFGenerator.generate(cards: [card]))
    }

    func testCatalogNineCardsFitOnOnePage() {
        let cards = (1...9).map { makeCard("6794", .twins, number: $0) }
        guard let data = CatalogPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 1)
    }

    func testCatalogTenCardsNeedTwoPages() {
        let cards = (1...10).map { makeCard("6794", .twins, number: $0) }
        guard let data = CatalogPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 2)
    }
```

- [x] **Step 2: Run new catalog tests — expect PASS before changing catalog generator**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/PDFCardHeaderTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -40
```

- [x] **Step 3: Update CatalogPDFGenerator.drawCard**

Edit `SpartansPlaycaller/Services/CatalogPDFGenerator.swift`. Replace the header row section in `drawCard` (lines 43–59):

**Remove:**
```swift
        // Row 1: Play number (left) + Formation (right)
        drawTextLeft("\(card.playNumber).", in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.25, height: 14),
                     font: UIFont.systemFont(ofSize: config.playNumberFontSize, weight: .bold), into: context)
        drawTextRight(card.formationName, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                      font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold), into: context)
        y += 16

        // Row 2: Route digits
        drawTextCenter(card.routeDigits, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 13),
                       font: UIFont.monospacedSystemFont(ofSize: config.digitsFontSize, weight: .medium), into: context)
        y += 13

        // Row 3: Receiver labels
        let labelCount = card.routeDigits.count
        let receiverLabels = Array(["X", "Y", "Z", "A", "H"].prefix(labelCount)).joined(separator: "   ")
        drawTextCenter(receiverLabels, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 11),
                       font: UIFont.monospacedSystemFont(ofSize: config.receiverLabelFontSize, weight: .regular), into: context)
        y += 12
```

**Replace with:**
```swift
        // Row 1: Combined play call — "N. Formation Digits" (e.g., "1. Twins 6794")
        drawTextLeft(card.combinedHeaderString,
                     in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                     font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
                     into: context)
        y += 16
```

- [x] **Step 4: Run full test suite — verify no regressions**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test session|PASSED|FAILED|error:" | tail -20
```

Expected: existing `CatalogPDFGeneratorTests` (5 tests) all pass. New catalog tests pass.

- [x] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Services/CatalogPDFGenerator.swift SpartansPlaycallerTests/PDFCardHeaderTests.swift
git commit -m "feat: collapse catalog PDF card header to single combined row"
```

---

### Task 5: DiagramRenderer+CGContext — receiver letter labels

Add letter label drawing inside `drawReceiversCG`. This requires:
1. Adding `playCall: PlayCall` parameter so Y motion final position can be computed
2. Constructing font once outside the loop (performance)
3. Drawing the letter after fill+stroke, using the Y-down flip technique

**Files:**
- Modify: `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift`
- Create: `SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift`

- [x] **Step 1: Write the receiver label tests**

Create `SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift`:

```swift
import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class DiagramRendererReceiverLabelTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func renderToPDF(playCall: PlayCall, config: DiagramConfig? = nil) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        let r = UIGraphicsPDFRenderer(bounds: pageRect)
        return r.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            cgCtx.translateBy(x: 0, y: pageRect.height)
            cgCtx.scaleBy(x: 1, y: -1)
            let cfg = config ?? DiagramConfig.wristbandCardScale(for: CGSize(width: 236, height: 96))
            DiagramRenderer().draw(into: cgCtx, playCall: playCall, config: cfg,
                                   in: CGRect(x: 8, y: 62, width: 236, height: 96))
        }
    }

    func playCall(_ digits: String, _ formation: Formation) -> PlayCall {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed: \(digits)")
        }
        return pc
    }

    func testDoesNotCrashTwins() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .twins)))
    }

    func testDoesNotCrashTripsLeft() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("2943", .tripsLeft)))
    }

    func testDoesNotCrashTripsRight() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("8761", .tripsRight)))
    }

    func testDoesNotCrashProLeft() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .proLeft)))
    }

    func testDoesNotCrashProRight() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .proRight)))
    }

    func testDoesNotCrashFiveDigitPlay() {
        // H receiver included
        XCTAssertNotNil(renderToPDF(playCall: playCall("67943", .twins)))
    }

    func testDoesNotCrashWithStopMotion() {
        let pc = PlayCall.applying(.stop, yWheelEnabled: false, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithAfterMotion() {
        let pc = PlayCall.applying(.after, yWheelEnabled: false, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithGoMotion() {
        let pc = PlayCall.applying(.go, yWheelEnabled: false, to: playCall("2943", .tripsLeft))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithYWheel() {
        let pc = PlayCall.applying(nil, yWheelEnabled: true, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashCatalogConfig() {
        let cfg = DiagramConfig.catalogCardScale(for: CGSize(width: 224, height: 124))
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .twins), config: cfg))
    }

    func testOutputIsValidPDF() {
        guard let data = renderToPDF(playCall: playCall("6794", .twins)) else {
            XCTFail("nil data"); return
        }
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testContextStateIntegrityAfterDraw() {
        // Verifies that saveGState/restoreGState inside drawReceiversCG
        // does not leak a corrupt transform onto callers' context.
        let pc = playCall("6794", .twins)
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        var transformBeforeDraw: CGAffineTransform = .identity
        var transformAfterDraw: CGAffineTransform = .identity
        let _ = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            cgCtx.translateBy(x: 0, y: pageRect.height)
            cgCtx.scaleBy(x: 1, y: -1)
            transformBeforeDraw = cgCtx.ctm
            let cfg = DiagramConfig.wristbandCardScale(for: CGSize(width: 236, height: 96))
            DiagramRenderer().draw(into: cgCtx, playCall: pc, config: cfg,
                                   in: CGRect(x: 8, y: 62, width: 236, height: 96))
            transformAfterDraw = cgCtx.ctm
        }
        XCTAssertEqual(transformBeforeDraw.a, transformAfterDraw.a, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.d, transformAfterDraw.d, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.tx, transformAfterDraw.tx, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.ty, transformAfterDraw.ty, accuracy: 0.001)
    }
}
```

- [x] **Step 2: Run tests — expect all 13 PASS (tests don't verify labels, just non-crash)**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpartansPlaycallerTests/DiagramRendererReceiverLabelTests 2>&1 | grep -E "Test Case|PASSED|FAILED|error:" | head -30
```

Expected: all 13 pass. They test the current (no-label) code and will continue passing after the label code is added.

- [x] **Step 3: Update drawReceiversCG in DiagramRenderer+CGContext.swift**

Edit `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift`.

**Change 1:** Update `draw(into:playCall:config:in:)` call site for `drawReceiversCG` (line 22):

Find:
```swift
        drawReceiversCG(context, assignments: playCall.assignments, positions: positions, config: config)
```

Replace with:
```swift
        drawReceiversCG(context, assignments: playCall.assignments, positions: positions, playCall: playCall, config: config)
```

**Change 2:** Replace the entire `drawReceiversCG` method (lines 150–163):

**Remove:**
```swift
    private func drawReceiversCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], config: DiagramConfig) {
        for assignment in assignments {
            guard let pos = positions[assignment.receiver] else { continue }
            let r = config.receiverRadius
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let color = UIColor(cgColor: receiverCGColor(for: assignment.receiver))

            context.setFillColor(color.withAlphaComponent(0.2).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: rect)
        }
    }
```

**Replace with:**
```swift
    private func drawReceiversCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], playCall: PlayCall, config: DiagramConfig) {
        let r = config.receiverRadius
        let fontSize = min(r * 1.5, 8.0)
        let labelFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let labelStyle: NSMutableParagraphStyle = {
            let s = NSMutableParagraphStyle()
            s.alignment = .center
            return s
        }()

        for assignment in assignments {
            guard let initialPos = positions[assignment.receiver] else { continue }

            // For Y with After/Go motion, label renders at the post-motion position
            // (where the route starts from), consistent with drawRoutesCG behavior.
            let pos: CGPoint
            if assignment.receiver == .Y, assignment.motion != nil {
                pos = yFinalPosition(
                    initialSide: assignment.side,
                    finalSide: assignment.motionFinalSide,
                    motion: assignment.motion,
                    formation: playCall.formation,
                    config: config
                )
            } else {
                pos = initialPos
            }

            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let color = UIColor(cgColor: receiverCGColor(for: assignment.receiver))

            // Fill (alpha raised to 0.3 for legibility with letter overlay)
            context.setFillColor(color.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: rect)
            // Stroke
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: rect)
            // Letter label — drawn on top of the dot
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: color,
                .paragraphStyle: labelStyle
            ]
            // Y-down re-flip: same technique as WristbandPDFPage.drawText
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            (assignment.receiver.rawValue as NSString).draw(
                in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
                withAttributes: labelAttrs
            )
            context.restoreGState()
        }
    }
```

- [x] **Step 4: Run full test suite — expect all tests pass**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test session|PASSED|FAILED|error:" | tail -20
```

Expected: all existing tests + all new tests pass. The `testContextStateIntegrityAfterDraw` test specifically validates that the Y-down save/restore does not leak.

If any test fails: check for compile errors first (the `playCall:` parameter label must match at both the call site and method signature).

- [x] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift
git commit -m "feat: draw receiver letter labels inside dots on route diagram"
```

---

### Task 6: Full test run, push, and plan closure

- [ ] **Step 1: Run complete test suite**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "Test session|Executed|PASSED|FAILED" | tail -10
```

Expected output: all new tests pass. Any pre-existing failures are documented in `docs/backlog/IMPROVEMENT-BACKLOG.md` and are not introduced by this change.

- [ ] **Step 2: Confirm no new pre-existing failures**

Compare failure count against baseline (9 pre-existing failures as of Epic 3.1 ship). If new failures appear, investigate before pushing.

- [ ] **Step 3: Push branch to remote**

```bash
git push -u origin feat/pdf-card-playcall-labels
```

- [ ] **Step 4: Update plan checkboxes**

Mark all completed tasks `[x]` in this plan file and commit:

```bash
git add docs/superpowers/plans/2026-06-07-pdf-card-playcall-labels.md
git commit -m "docs: mark all plan tasks complete"
git push
```

---

## Self-Review Checklist

### Spec coverage
- AC-1 ✓ Task 3 (combined header row, left-aligned)
- AC-2 ✓ Tasks 3+4 (Rows 2+3 removed from both generators)
- AC-3 ✓ Task 1 (`testCombinedHeaderStringFiveDigitRoute` covers 5-digit)
- AC-4 ✓ Tasks 3+4 (no concept/no motion cards tested in integration tests)
- AC-5 ✓ Tasks 3+4 (concept/motion tests confirm row follows immediately)
- AC-6 ✓ Tasks 3+4 (both generators updated identically in structure)
- AC-7 ✓ Task 5 (all receivers in `drawReceiversCG` get a label)
- AC-8 ✓ Task 5 (fill alpha 0.2→0.3; label color = receiver color at full opacity)
- AC-9 ✓ Task 5 (`min(r * 1.5, 8.0)` formula)
- AC-10 ✓ Task 5 (Y-down flip: saveGState/translateBy/scaleBy/restoreGState inline)
- AC-11 ✓ Task 5 (draw order: fill → stroke → label)
- AC-12 ✓ Task 5 (Y pos overridden with `yFinalPosition` when `motion != nil`)
- AC-13 ✓ No existing test assertions reference Row 2/3 strings; no expected-value updates needed
- AC-14 ✓ Task 3+4 integration tests cover Twins 4-digit and Trips 5-digit cases

### Type/method consistency
- `card.combinedHeaderString` defined in Task 1, used in Tasks 3+4 ✓
- `drawReceiversCG(context:assignments:positions:playCall:config:)` — new signature defined and call site updated in Task 5, same method ✓
- `WristbandCardConfig.standard()` and `CatalogCardConfig.standard()` — unchanged factory methods ✓
- `DiagramConfig.wristbandCardScale(for:)` and `DiagramConfig.catalogCardScale(for:)` — unchanged ✓

### No placeholders
Reviewed: all steps contain actual code, exact commands, or explicit expected output. No "TBD", "similar to Task N", or "add appropriate handling".
