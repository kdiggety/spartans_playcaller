import Foundation

/// A fully-resolved route assignment for one receiver.
/// Contains the raw digit, the receiver, their field side, the interpreted meaning,
/// and optional pre-snap receiver motion.
struct RouteAssignment: Identifiable {
    let id = UUID()
    let receiver: Receiver
    let routeNumber: RouteNumber
    let side: FieldSide
    let meaning: RouteMeaning
    var motion: ReceiverMotion?

    /// The field side where this receiver executes their route after motion is applied.
    /// If no motion is assigned, this equals the original formation side.
    /// If motion is present, this is computed from the motion's finalSide logic.
    var motionFinalSide: FieldSide {
        if let motion = motion {
            return motion.finalSide(originalSide: side)
        }
        return side
    }

    var label: String {
        "\(receiver.rawValue) (\(routeNumber.rawValue)) — \(meaning.rawValue)"
    }

    /// Validates that a motion is compatible with the receiver and formation context.
    /// Y motion is only valid for Y receivers in Trips formations (currently enforced at runtime).
    /// - Parameters:
    ///   - motion: The motion to validate (nil is always valid).
    ///   - formation: The formation context.
    /// - Returns: Success if motion is valid for this receiver in the formation, or an error describing the conflict.
    static func validateMotionForFormation(_ motion: ReceiverMotion?, formation: Formation) -> Result<Void, RouteAssignmentError> {
        // No motion always validates
        guard let motion = motion else {
            return .success(())
        }

        // Further motion validation logic can be added here as needed.
        // Currently, all receivers can have motion in all formations.
        // Constraints for specific motion types (e.g., Y motion restrictions) will be enforced
        // at the play-call level in later phases.

        return .success(())
    }
}
