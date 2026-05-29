import Foundation

/// Motion directives for receiver pre-snap movement.
/// Motion changes where a receiver lines up or where they end up after movement.
/// This is distinct from the route itself — it modifies the receiver's final position before the snap.
enum ReceiverMotion: String, CaseIterable, Identifiable {
    /// Motion to opposite side (pre- or post-snap) with dramatic arc and route flip.
    case after = "Y After/Go"

    var id: String { rawValue }

    /// Compute the final field side after motion is applied.
    /// - **after**: Receiver flips to opposite side and runs route from that side.
    ///
    /// - Parameter originalSide: The side the receiver aligns on in the formation.
    /// - Returns: The side where the receiver will execute their route.
    func finalSide(originalSide: FieldSide) -> FieldSide {
        // Flip to opposite side
        switch originalSide {
        case .left:
            return .right
        case .right:
            return .left
        case .center:
            // Center does not flip (H in middle field)
            return .center
        }
    }
}
