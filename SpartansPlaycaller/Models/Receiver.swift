import Foundation

/// Receiver positions in the formation system.
/// X is always LEFT, Z is always RIGHT.
/// Y and A move based on formation context.
/// H is an optional running back.
enum Receiver: String, CaseIterable, Identifiable {
    case X, Y, Z, A, H

    var id: String { rawValue }

    /// The canonical digit-sequence index for route parsing.
    /// Route digits are ALWAYS ordered: X, Y, Z, A, H
    var sequenceIndex: Int {
        switch self {
        case .X: return 0
        case .Y: return 1
        case .Z: return 2
        case .A: return 3
        case .H: return 4
        }
    }

    /// All receivers that always participate (H is optional)
    static var required: [Receiver] { [.X, .Y, .Z, .A] }
}
