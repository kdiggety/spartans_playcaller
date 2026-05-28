import Foundation

/// A complete play call: formation + route assignments + optional concept identification.
struct PlayCall: Identifiable {
    let id = UUID()
    let formation: Formation
    let routeDigits: String
    let assignments: [RouteAssignment]
    let concept: RouteConcept?

    /// Human-readable play call string (e.g., "Twins 6794")
    var displayName: String {
        if let concept = concept {
            return "\(formation.rawValue) \(concept.rawValue) (\(routeDigits))"
        }
        return "\(formation.rawValue) \(routeDigits)"
    }
}
