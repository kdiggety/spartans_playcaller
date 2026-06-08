import Foundation

/// Codable DTO for a persisted play call.
/// Stores only the five display fields needed for export — not the full PlayCall graph.
/// Full PlayCall can be reconstructed at export time via RouteInterpreter.
struct SavedPlay: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let formationName: String   // Formation.rawValue, e.g. "Twins"
    let routeDigits: String     // Raw digit string, e.g. "6794"
    let conceptName: String?    // RouteConcept.rawValue if matched; nil otherwise
    let motionLabel: String?    // ReceiverMotion.rawValue if present; nil otherwise
    let yWheelEnabled: Bool

    static func from(playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool) -> SavedPlay {
        SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,
            yWheelEnabled: yWheelEnabled
        )
    }
}
