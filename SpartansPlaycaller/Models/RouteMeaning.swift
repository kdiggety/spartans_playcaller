import Foundation

/// The semantic meaning of a route after side-aware interpretation.
/// These are the actual route types a receiver runs.
enum RouteMeaning: String, CaseIterable, Identifiable {
    case hitch = "Hitch"
    case quickOut = "Quick Out"
    case quickSlant = "Quick Slant"
    case out = "Out"
    case digIn = "Dig/In"
    case comeback = "Comeback"
    case curl = "Curl"
    case corner = "Corner"
    case post = "Post"
    case goFade = "Go/Fade"

    var id: String { rawValue }

    /// Short label for diagram annotations
    var shortLabel: String {
        switch self {
        case .hitch: return "Hitch"
        case .quickOut: return "Q-Out"
        case .quickSlant: return "Q-Slant"
        case .out: return "Out"
        case .digIn: return "Dig"
        case .comeback: return "Come"
        case .curl: return "Curl"
        case .corner: return "Corner"
        case .post: return "Post"
        case .goFade: return "Go"
        }
    }
}
