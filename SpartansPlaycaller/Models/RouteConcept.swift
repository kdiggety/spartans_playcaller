import Foundation

/// Named route concepts. These are first-class objects representing
/// known combinations of receiver routes in specific formations.
enum RouteConcept: String, CaseIterable, Identifiable {
    case smash = "Smash"
    case dagger = "Dagger"
    case verts = "Verts"
    case scissors = "Scissors"
    case sail = "Sail"
    case china = "China"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .smash: return "High-low concept with a curl/hitch underneath and a corner over the top"
        case .dagger: return "Deep dig route with a go route to clear space"
        case .verts: return "All verticals stretching the defense deep"
        case .scissors: return "Post-corner combination creating a scissors action"
        case .sail: return "Three-level flood concept with go, out, and flat"
        case .china: return "Smash variation with a curl replacing the flat route"
        }
    }
}
