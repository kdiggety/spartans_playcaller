import Foundation

/// A concept template defines what route digits specific receivers must run
/// for a concept to be identified in a given formation context.
///
/// Templates are partial: they only specify the receivers involved in the concept.
/// Non-specified receivers can run any route.
struct ConceptTemplate: Identifiable {
    let id = UUID()
    let concept: RouteConcept
    let formationContext: FormationContext
    let receiverRoutes: [Receiver: RouteNumber]

    /// Check if a set of assignments matches this template.
    /// Only the receivers specified in the template need to match.
    func matches(assignments: [Receiver: RouteNumber]) -> Bool {
        for (receiver, expectedRoute) in receiverRoutes {
            guard let actual = assignments[receiver], actual == expectedRoute else {
                return false
            }
        }
        return true
    }
}

/// Defines which formation group a concept template applies to.
enum FormationContext {
    case specific(Formation)
    case twinsLeft
    case twinsRight
    case tripsLeft
    case tripsRight

    func matches(formation: Formation) -> Bool {
        switch self {
        case .specific(let f): return f == formation
        case .twinsLeft: return formation == .twins
        case .twinsRight: return formation == .twins
        case .tripsLeft: return formation == .tripsLeft
        case .tripsRight: return formation == .tripsRight
        }
    }

    var conceptSide: FieldSide {
        switch self {
        case .twinsLeft, .tripsLeft: return .left
        case .twinsRight, .tripsRight: return .right
        case .specific: return .center
        }
    }
}
