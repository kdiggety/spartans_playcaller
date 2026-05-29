import Foundation

/// Errors that can occur when validating or creating route assignments.
enum RouteAssignmentError: LocalizedError {
    /// Motion is not supported in the given formation.
    /// Example: Y motion in a Twins formation (Y motion only valid in Trips).
    case unsupportedMotionInFormation(ReceiverMotion, Formation)

    /// Motion is only applicable to specific receiver types.
    /// Example: Y motion assigned to a non-Y receiver.
    case motionOnlyValidForYReceiver(Receiver, ReceiverMotion)

    var errorDescription: String? {
        switch self {
        case .unsupportedMotionInFormation(let motion, let formation):
            return "\(motion.rawValue) motion is not supported in \(formation.rawValue) formation"

        case .motionOnlyValidForYReceiver(let receiver, let motion):
            return "\(motion.rawValue) motion is only valid for Y receiver, not \(receiver.rawValue)"
        }
    }
}
