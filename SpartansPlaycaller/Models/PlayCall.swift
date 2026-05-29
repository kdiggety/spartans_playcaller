import Foundation

/// A complete play call: formation + route assignments + optional concept identification.
struct PlayCall: Identifiable {
    let id = UUID()
    let formation: Formation
    let routeDigits: String
    var assignments: [RouteAssignment]
    let concept: RouteConcept?
    let yWheelEnabled: Bool

    /// Human-readable play call string (e.g., "Twins 6794")
    var displayName: String {
        "\(formation.rawValue) \(routeDigits)"
    }

    init(
        formation: Formation,
        routeDigits: String,
        assignments: [RouteAssignment],
        concept: RouteConcept?,
        yWheelEnabled: Bool = false
    ) {
        self.formation = formation
        self.routeDigits = routeDigits
        self.assignments = assignments
        self.concept = concept
        self.yWheelEnabled = yWheelEnabled
    }
}
