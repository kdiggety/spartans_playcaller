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

    /// Return a new PlayCall with motion applied to Y receiver.
    /// Replicates the logic from PlayCallerViewModel.applyMotion() so both
    /// the ViewModel and ExportCard construction share the same code path.
    static func applying(_ motion: ReceiverMotion?, yWheelEnabled: Bool, to playCall: PlayCall) -> PlayCall {
        let updatedAssignments = playCall.assignments.map { assignment -> RouteAssignment in
            if assignment.receiver == .Y && motion != nil {
                var updated = assignment
                updated.motion = motion
                return updated
            }
            return assignment
        }
        return PlayCall(
            formation: playCall.formation,
            routeDigits: playCall.routeDigits,
            assignments: updatedAssignments,
            concept: playCall.concept,
            yWheelEnabled: yWheelEnabled
        )
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
