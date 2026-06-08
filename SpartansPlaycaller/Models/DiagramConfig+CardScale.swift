import CoreGraphics

extension DiagramConfig {
    /// DiagramConfig scaled for wristband cards (diagram zone ~242pt × 72pt).
    static func wristbandCardScale(for size: CGSize) -> DiagramConfig {
        DiagramConfig(
            fieldWidth: size.width,
            fieldHeight: size.height,
            lineOfScrimmageY: size.height * 0.50,
            routeLength: size.height * 0.35,
            breakLength: size.height * 0.25,
            receiverRadius: 4.0,
            footballSize: 5.0,
            receiverSpacing: size.width * 0.14,
            sideMargin: size.width * 0.06
        )
    }

    /// DiagramConfig scaled for catalog cards (diagram zone ~224pt × 89pt).
    static func catalogCardScale(for size: CGSize) -> DiagramConfig {
        DiagramConfig(
            fieldWidth: size.width,
            fieldHeight: size.height,
            lineOfScrimmageY: size.height * 0.50,
            routeLength: size.height * 0.38,
            breakLength: size.height * 0.28,
            receiverRadius: 4.0,
            footballSize: 5.0,
            receiverSpacing: size.width * 0.13,
            sideMargin: size.width * 0.05
        )
    }
}
