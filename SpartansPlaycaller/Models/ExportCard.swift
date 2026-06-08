import Foundation

/// Shared value type for PDF generators.
/// Carries all fields needed to render one wristband or catalog card.
/// Constructed either from the current play (quick export) or from a SavedPlay (library export).
struct ExportCard {
    let playNumber: Int
    let formationName: String
    let routeDigits: String
    let conceptName: String?
    let motionLabel: String?
    let yWheelEnabled: Bool
    let playCall: PlayCall   // post-motion, drives diagram rendering

    var combinedHeaderString: String {
        "\(playNumber). \(formationName) \(routeDigits)"
    }
}

extension ExportCard {
    /// Quick-export path: construct from the current play call already in memory.
    /// `playCall` must be the post-motion state (currentPlayCallWithMotion ?? currentPlayCall).
    static func from(playCall: PlayCall, motion: ReceiverMotion?, playNumber: Int) -> ExportCard {
        ExportCard(
            playNumber: playNumber,
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,
            yWheelEnabled: playCall.yWheelEnabled,
            playCall: playCall
        )
    }

    /// Library-export path: reconstruct a PlayCall from a SavedPlay using RouteInterpreter.
    /// Returns nil if the formation name or digit string cannot be parsed
    /// (e.g. if a formation was renamed in a future code change).
    static func from(savedPlay: SavedPlay, playNumber: Int, interpreter: RouteInterpreter) -> ExportCard? {
        guard let formation = Formation(rawValue: savedPlay.formationName) else { return nil }
        guard case .success(let parsedCall) = interpreter.interpret(digits: savedPlay.routeDigits, formation: formation) else { return nil }

        let motion = savedPlay.motionLabel.flatMap { ReceiverMotion(rawValue: $0) }
        let finalPlayCall = PlayCall.applying(motion, yWheelEnabled: savedPlay.yWheelEnabled, to: parsedCall)

        return ExportCard(
            playNumber: playNumber,
            formationName: savedPlay.formationName,
            routeDigits: savedPlay.routeDigits,
            conceptName: savedPlay.conceptName,
            motionLabel: savedPlay.motionLabel,
            yWheelEnabled: savedPlay.yWheelEnabled,
            playCall: finalPlayCall
        )
    }
}
