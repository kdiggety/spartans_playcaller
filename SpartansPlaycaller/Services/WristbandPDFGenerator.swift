import PDFKit
import UIKit

// MARK: - WristbandPDFPage

final class WristbandPDFPage: PDFPage {
    let card: ExportCard
    let config: WristbandCardConfig

    init(card: ExportCard, config: WristbandCardConfig) {
        self.card = card
        self.config = config
        super.init()
        setBounds(CGRect(x: 0, y: 0, width: config.pageWidth, height: config.pageHeight), for: .mediaBox)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        let mediaBox = bounds(for: box)

        // Flip to screen coordinates (Y-down from top)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        // Draw 4 identical copies
        for origin in config.cardOrigins {
            drawCard(card, at: origin, into: context)
        }

        // Cut guides
        drawCutGuidesCG(context)
    }

    private func drawCard(_ card: ExportCard, at origin: CGPoint, into context: CGContext) {
        let w = config.cardWidth
        let h = config.cardHeight
        let inset = config.cardInset
        let usableWidth = w - 2 * inset

        // Card border
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(origin: origin, size: CGSize(width: w, height: h)))

        var y = origin.y + inset

        // Row 1: Combined play call — "N. Formation Digits" (e.g., "1. Twins 6794")
        drawTextLeft(card.combinedHeaderString,
                     in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 20),
                     font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
                     into: context)
        y += 22

        // Row 2: Concept (left) + Motion (right) — conditional
        if card.conceptName != nil || card.motionLabel != nil {
            if let concept = card.conceptName {
                drawTextLeft(concept, in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.6, height: 16),
                             font: UIFont.systemFont(ofSize: config.conceptFontSize, weight: .semibold), into: context)
            }
            if let motion = card.motionLabel {
                drawTextRight(motion, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 16),
                              font: UIFont.systemFont(ofSize: config.motionFontSize, weight: .regular), into: context)
            }
            y += 17
        }

        // Divider
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: origin.x + inset, y: y + 2))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: y + 2))
        context.strokePath()
        y += 5

        // Diagram zone
        let diagramRect = CGRect(x: origin.x + inset, y: y, width: usableWidth, height: config.diagramZoneSize.height)
        let diagramConfig = DiagramConfig.wristbandCardScale(for: diagramRect.size)
        DiagramRenderer().draw(into: context, playCall: card.playCall, config: diagramConfig, in: diagramRect)

        // Notes line
        let notesY = origin.y + h - 14
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(0.3)
        context.move(to: CGPoint(x: origin.x + inset + 30, y: notesY))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: notesY))
        context.strokePath()
        drawTextLeft("Notes:", in: CGRect(x: origin.x + inset, y: notesY - 10, width: 30, height: 12),
                     font: UIFont.systemFont(ofSize: config.notesFontSize, weight: .regular), into: context)
    }

    private func drawCutGuidesCG(_ context: CGContext) {
        let origins = config.cardOrigins
        let gutter = config.gutter

        context.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(0.25)

        // Vertical cut guide (between column 0 and column 1)
        let vCutX = origins[0].x + config.cardWidth + gutter / 2
        context.move(to: CGPoint(x: vCutX, y: config.margin))
        context.addLine(to: CGPoint(x: vCutX, y: config.pageHeight - config.margin))
        context.strokePath()

        // Horizontal cut guide (between row 0 and row 1)
        let hCutY = origins[0].y + config.cardHeight + gutter / 2
        context.move(to: CGPoint(x: config.margin, y: hCutY))
        context.addLine(to: CGPoint(x: config.pageWidth - config.margin, y: hCutY))
        context.strokePath()
    }

    // MARK: - Text drawing helpers (handle Y-down context)

    private func drawTextLeft(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .left, font: font, into: context)
    }

    private func drawTextRight(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .right, font: font, into: context)
    }

    private func drawTextCenter(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .center, font: font, into: context)
    }

    /// Core text drawing: temporarily re-flip to Y-up so UIKit renders text correctly.
    private func drawText(_ text: String, in rect: CGRect, alignment: NSTextAlignment, font: UIFont, into context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)

        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), withAttributes: attrs)
        context.restoreGState()
    }
}

// MARK: - WristbandPDFGenerator

struct WristbandPDFGenerator {
    /// Generate a wristband PDF. One page per card; each page shows 4 copies.
    /// Returns nil for empty input or if PDFKit serialization fails.
    static func generate(cards: [ExportCard]) -> Data? {
        guard !cards.isEmpty else { return nil }

        let config = WristbandCardConfig.standard()
        let document = PDFDocument()

        // REQ-SEC-1: set only title attribute; no author/creator/subject
        let titleString = cards.count == 1
            ? "\(cards[0].formationName) \(cards[0].routeDigits)"
            : "\(cards.count) Plays — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: titleString]

        for (index, card) in cards.enumerated() {
            let page = WristbandPDFPage(card: card, config: config)
            document.insert(page, at: index)
        }

        return document.dataRepresentation()
    }
}
