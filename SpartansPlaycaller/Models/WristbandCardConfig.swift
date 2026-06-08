import CoreGraphics

struct WristbandCardConfig {
    // Card dimensions
    let cardWidth: CGFloat = 252.0      // 3.5" at 72pt/in
    let cardHeight: CGFloat = 180.0     // 2.5" at 72pt/in
    let cardInset: CGFloat = 8.0

    // Page
    let pageWidth: CGFloat = 612.0      // US Letter portrait
    let pageHeight: CGFloat = 792.0
    let margin: CGFloat = 18.0          // 0.25"
    let gutter: CGFloat = 9.0           // 0.125"

    // Pre-computed card origins (top-left, screen coordinates)
    var cardOrigins: [CGPoint] {
        let xOffset: CGFloat = 49.5     // (612 - 2×252 - 9) / 2 = 31.5 + 18 = 49.5
        let yOffset: CGFloat = 211.5    // (792 - 2×180 - 9) / 2 = 193.5 + 18 = 211.5
        return [
            CGPoint(x: xOffset, y: yOffset),
            CGPoint(x: xOffset + cardWidth + gutter, y: yOffset),
            CGPoint(x: xOffset, y: yOffset + cardHeight + gutter),
            CGPoint(x: xOffset + cardWidth + gutter, y: yOffset + cardHeight + gutter)
        ]
    }

    // Font sizes
    let playNumberFontSize: CGFloat = 18.0
    let formationFontSize: CGFloat = 14.0
    let digitsFontSize: CGFloat = 14.0
    let receiverLabelFontSize: CGFloat = 9.0
    let conceptFontSize: CGFloat = 12.0
    let motionFontSize: CGFloat = 11.0
    let notesFontSize: CGFloat = 8.0

    // Diagram zone (relative to card top-left)
    // Starts at y=92pt within card (after header rows), ends 10pt from card bottom
    let diagramZoneTopY: CGFloat = 92.0

    var diagramZoneSize: CGSize {
        let height = cardHeight - diagramZoneTopY - cardInset - 14.0 // -14 for notes line
        return CGSize(width: cardWidth - 2 * cardInset, height: height)
    }

    static func standard() -> WristbandCardConfig { WristbandCardConfig() }
}
