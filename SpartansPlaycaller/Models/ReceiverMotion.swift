import Foundation

/// Motion directives for receiver pre-snap movement.
/// Motion changes where a receiver lines up or where they end up after movement.
/// This is distinct from the route itself — it modifies the receiver's final position before the snap.
enum ReceiverMotion: String, CaseIterable, Identifiable {
    /// No motion: Y receiver executes route from original alignment.
    case stop = "Y Stop"

    /// Motion to opposite side (pre- or post-snap) with arc toward sideline and route flip.
    case after = "Y After"

    /// Motion to opposite side (direct/faster) with immediate route flip.
    case go = "Y Go"

    /// Semi-circular arc motion behind formation, stays on original side.
    case wheel = "Y Wheel"

    var id: String { rawValue }

    /// Compute the final field side after motion is applied.
    /// - **stop**: Receiver stays on original side, no flip.
    /// - **after**: Receiver flips to opposite side and runs route from that side.
    /// - **go**: Receiver flips to opposite side and runs route from that side.
    /// - **wheel**: Receiver stays on original side (semi-circle arc), no flip.
    ///
    /// - Parameter originalSide: The side the receiver aligns on in the formation.
    /// - Returns: The side where the receiver will execute their route.
    func finalSide(originalSide: FieldSide) -> FieldSide {
        switch self {
        case .stop, .wheel:
            return originalSide
        case .after, .go:
            switch originalSide {
            case .left:
                return .right
            case .right:
                return .left
            case .center:
                return .center
            }
        }
    }
}
