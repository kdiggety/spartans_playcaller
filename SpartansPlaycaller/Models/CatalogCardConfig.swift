import CoreGraphics

struct CatalogCardConfig {
    // Card dimensions
    let cardWidth: CGFloat = 234.0
    let cardHeight: CGFloat = 174.0
    let cardInset: CGFloat = 5.0

    // Page
    let pageWidth: CGFloat = 792.0      // US Letter landscape (11")
    let pageHeight: CGFloat = 612.0     // US Letter landscape (8.5")
    let margin: CGFloat = 36.0          // 0.5"
    let gutter: CGFloat = 8.0

    // Font sizes (smaller than wristband — read at normal viewing distance)
    let playNumberFontSize: CGFloat = 10.0
    let formationFontSize: CGFloat = 10.0
    let digitsFontSize: CGFloat = 9.0
    let receiverLabelFontSize: CGFloat = 8.0
    let conceptFontSize: CGFloat = 8.0
    let motionFontSize: CGFloat = 8.0

    // Diagram zone (relative to card top-left)
    // Starts at y≈45pt within card (one combined header row + optional concept/motion + divider)
    let diagramZoneTopY: CGFloat = 45.0

    var diagramZoneSize: CGSize {
        let height = cardHeight - diagramZoneTopY - cardInset
        return CGSize(width: cardWidth - 2 * cardInset, height: height)
    }

    /// 9 cell origins in row-major order (row 0 left→right, row 1, row 2).
    var cellOrigins: [CGPoint] {
        var origins: [CGPoint] = []
        let colStride = cardWidth + gutter   // 234 + 8 = 242
        let rowStride = cardHeight + gutter  // 174 + 8 = 182
        for row in 0..<3 {
            for col in 0..<3 {
                origins.append(CGPoint(
                    x: margin + CGFloat(col) * colStride,
                    y: margin + CGFloat(row) * rowStride
                ))
            }
        }
        return origins
    }

    static func standard() -> CatalogCardConfig { CatalogCardConfig() }
}
