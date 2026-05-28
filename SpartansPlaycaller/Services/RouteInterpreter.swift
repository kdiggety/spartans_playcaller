import Foundation

/// High-level service that coordinates parsing, interpretation, and concept matching
/// to produce a complete PlayCall from user input.
struct RouteInterpreter {

    private let parser = PlayCallParser()
    private let matcher = ConceptMatcher()

    /// Parse route digits and produce a full PlayCall with concept identification.
    func interpret(digits: String, formation: Formation) -> Result<PlayCall, PlayCallParser.ParseError> {
        let parseResult = parser.parse(digits: digits, formation: formation)

        switch parseResult {
        case .success(let assignments):
            let concept = matcher.identify(assignments: assignments, formation: formation)
            let playCall = PlayCall(
                formation: formation,
                routeDigits: digits,
                assignments: assignments,
                concept: concept
            )
            return .success(playCall)

        case .failure(let error):
            return .failure(error)
        }
    }

    /// Generate a play call from a concept selection.
    func generate(concept: RouteConcept, formation: Formation) -> PlayCall? {
        guard let digits = matcher.generateDigits(concept: concept, formation: formation) else {
            return nil
        }

        // Parse the generated digits to get full assignments
        if case .success(let assignments) = parser.parse(digits: digits, formation: formation) {
            return PlayCall(
                formation: formation,
                routeDigits: digits,
                assignments: assignments,
                concept: concept
            )
        }
        return nil
    }

    /// Identify concept for a specific field side from assignments after motion is applied.
    /// This is used for side-aware concept matching when motion changes receiver groupings.
    func identifyForSide(_ side: FieldSide, assignments: [RouteAssignment], formation: Formation) -> RouteConcept? {
        return matcher.identifyForSide(side, assignments: assignments, formation: formation)
    }
}
