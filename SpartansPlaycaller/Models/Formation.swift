import Foundation

/// Supported formations defining receiver alignment.
/// Each formation places receivers on specific sides of the ball.
enum Formation: String, CaseIterable, Identifiable {
    case twins = "Twins"
    case tripsLeft = "Trips Left"
    case tripsRight = "Trips Right"

    var id: String { rawValue }

    /// Which side of the ball each receiver aligns on in this formation.
    /// This is the critical mapping that drives route interpretation.
    func side(for receiver: Receiver) -> FieldSide {
        switch self {
        case .twins:
            // X and Y left, Z and A right
            switch receiver {
            case .X, .Y: return .left
            case .Z, .A: return .right
            case .H: return .center
            }

        case .tripsLeft:
            // X, Y, A on left; Z isolated right
            switch receiver {
            case .X, .Y, .A: return .left
            case .Z: return .right
            case .H: return .center
            }

        case .tripsRight:
            // X isolated left; Y, Z, A on right
            switch receiver {
            case .X: return .left
            case .Y, .Z, .A: return .right
            case .H: return .center
            }
        }
    }

    /// Receiver alignment positions for diagram rendering.
    /// Returns receivers in order from outside-left to outside-right.
    var alignmentOrder: (left: [Receiver], right: [Receiver]) {
        switch self {
        case .twins:
            return (left: [.X, .Y], right: [.Z, .A])

        case .tripsLeft:
            // A outside X, X, Y inside X
            return (left: [.A, .X, .Y], right: [.Z])

        case .tripsRight:
            // X isolated left; Y inside Z, Z, A outside Z
            return (left: [.X], right: [.Y, .Z, .A])
        }
    }

    /// Check if motion is allowed in this formation.
    /// Motion is only valid in Trips formations.
    func canApplyMotion() -> Bool {
        switch self {
        case .tripsLeft, .tripsRight:
            return true
        case .twins:
            return false
        }
    }
}

/// The side of the ball a receiver aligns on.
/// Route interpretation depends entirely on this value.
enum FieldSide: String {
    case left, right, center
}
