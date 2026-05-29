import Foundation

/// Groups formations by conceptual family for the two-tier picker.
/// Each family that supports a side selection maps to two Formation values.
enum FormationFamily: String, CaseIterable, Identifiable {
    case twins = "Twins"
    case trips = "Trips"
    case pro = "Pro"

    var id: String { rawValue }

    /// The side choices available for this family.
    /// Returns false when side selection does not apply (Twins).
    var supportsSideSelection: Bool {
        switch self {
        case .twins: return false
        case .trips, .pro: return true
        }
    }

    /// Resolve the concrete Formation for this family + side combination.
    /// Twins ignores the side argument entirely.
    func formation(side: FieldSide) -> Formation {
        switch self {
        case .twins:
            return .twins
        case .trips:
            return side == .left ? .tripsLeft : .tripsRight
        case .pro:
            return side == .left ? .proLeft : .proRight
        }
    }
}

/// Supported formations defining receiver alignment.
/// Each formation places receivers on specific sides of the ball.
enum Formation: String, CaseIterable, Identifiable {
    case twins = "Twins"
    case tripsLeft = "Trips Left"
    case tripsRight = "Trips Right"
    case proLeft = "Pro Left"
    case proRight = "Pro Right"

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

        case .proLeft:
            // X far left, Y slot left; Z far right — no A receiver
            switch receiver {
            case .X, .Y: return .left
            case .Z: return .right
            case .A, .H: return .center
            }

        case .proRight:
            // X far left; Y slot right, Z far right — no A receiver
            switch receiver {
            case .X: return .left
            case .Y, .Z: return .right
            case .A, .H: return .center
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

        case .proLeft:
            // X far left, Y slot left; Z far right
            return (left: [.X, .Y], right: [.Z])

        case .proRight:
            // X far left; Y slot right, Z far right
            return (left: [.X], right: [.Y, .Z])
        }
    }

    /// Check if motion is allowed in this formation.
    /// Motion is only valid in Trips formations.
    func canApplyMotion() -> Bool {
        switch self {
        case .tripsLeft, .tripsRight, .proLeft, .proRight:
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

extension Formation {
    /// The family this formation belongs to.
    var family: FormationFamily {
        switch self {
        case .twins:
            return .twins
        case .tripsLeft, .tripsRight:
            return .trips
        case .proLeft, .proRight:
            return .pro
        }
    }

    /// The directional side of this formation, or nil for Twins.
    var side: FieldSide? {
        switch self {
        case .twins:
            return nil
        case .tripsLeft:
            return .left
        case .tripsRight:
            return .right
        case .proLeft:
            return .left
        case .proRight:
            return .right
        }
    }
}
