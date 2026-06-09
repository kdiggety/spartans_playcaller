import PDFKit
import UIKit

// MARK: - CatalogPDFPage

final class CatalogPDFPage: PDFPage {
    let pageCards: [ExportCard]      // 1–9 cards for this page
    let config: CatalogCardConfig

    init(pageCards: [ExportCard], config: CatalogCardConfig) {
        self.pageCards = pageCards
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

        let origins = config.cellOrigins
        for (i, card) in pageCards.enumerated() where i < origins.count {
            drawCard(card, at: origins[i], into: context)
        }
    }

    private func drawCard(_ card: ExportCard, at origin: CGPoint, into context: CGContext) {
        let w = config.cardWidth
        let inset = config.cardInset
        let usableWidth = w - 2 * inset

        // Card border
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(0.4)
        context.stroke(CGRect(origin: origin, size: CGSize(width: w, height: config.cardHeight)))

        var y = origin.y + inset

        // Row 1: Combined play call — "N. Formation Digits" (e.g., "1. Twins 6794")
        drawTextLeft(card.combinedHeaderString,
                     in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                     font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
                     into: context)
        y += 16

        // Row 2: Concept + Motion (conditional)
        if card.conceptName != nil || card.motionLabel != nil {
            if let concept = card.conceptName {
                drawTextLeft(concept, in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.6, height: 13),
                             font: UIFont.systemFont(ofSize: config.conceptFontSize, weight: .semibold), into: context)
            }
            if let motion = card.motionLabel {
                drawTextRight(motion, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 13),
                              font: UIFont.systemFont(ofSize: config.motionFontSize, weight: .regular), into: context)
            }
            y += 14
        }

        // Divider
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: origin.x + inset, y: y + 2))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: y + 2))
        context.strokePath()

        // Diagram zone
        let diagramRect = CGRect(
            x: origin.x + inset,
            y: origin.y + config.diagramZoneTopY,
            width: usableWidth,
            height: config.diagramZoneSize.height
        )
        let diagramConfig = DiagramConfig.catalogCardScale(for: diagramRect.size)
        DiagramRenderer().draw(into: context, playCall: card.playCall, config: diagramConfig, in: diagramRect)
    }

    // MARK: - Text helpers (same Y-down flip technique as WristbandPDFPage)

    private func drawTextLeft(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .left, font: font, into: context)
    }

    private func drawTextRight(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .right, font: font, into: context)
    }

    private func drawTextCenter(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .center, font: font, into: context)
    }

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

// MARK: - CatalogPDFGenerator

struct CatalogPDFGenerator {
    /// Generate a catalog PDF. 9 cards per landscape page; ceil(N/9) pages.
    /// Returns nil for empty input or if PDFKit serialization fails.
    static func generate(cards: [ExportCard]) -> Data? {
        guard !cards.isEmpty else { return nil }

        let config = CatalogCardConfig.standard()
        let document = PDFDocument()

        // REQ-SEC-1: set only title attribute
        let title = "\(cards.count) Plays — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: title]

        let pageSize = 9
        let pageCount = Int(ceil(Double(cards.count) / Double(pageSize)))

        for pageIndex in 0..<pageCount {
            let start = pageIndex * pageSize
            let end = min(start + pageSize, cards.count)
            let pageCards = Array(cards[start..<end])
            let page = CatalogPDFPage(pageCards: pageCards, config: config)
            document.insert(page, at: pageIndex)
        }

        return document.dataRepresentation()
    }
}
