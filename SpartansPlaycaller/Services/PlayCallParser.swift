import Foundation

/// Parses route digit strings into fully-resolved route assignments.
/// The parser enforces digit ordering (X, Y, Z, A, H) and validates input.
struct PlayCallParser {

    enum ParseError: LocalizedError {
        case invalidLength
        case invalidCharacter(Character)
        case invalidDigit(Int)

        var errorDescription: String? {
            switch self {
            case .invalidLength:
                return "Route digits must be 4 (X,Y,Z,A) or 5 (X,Y,Z,A,H) characters"
            case .invalidCharacter(let c):
                return "Invalid character '\(c)' — only digits 0-9 are allowed"
            case .invalidDigit(let d):
                return "Invalid route digit: \(d)"
            }
        }
    }

    /// Parse a route digit string in the context of a formation.
    /// Digit sequence is ALWAYS: X, Y, Z, A, (optional H)
    func parse(digits: String, formation: Formation) -> Result<[RouteAssignment], ParseError> {
        let trimmed = digits.trimmingCharacters(in: .whitespaces)

        guard trimmed.count == 4 || trimmed.count == 5 else {
            return .failure(.invalidLength)
        }

        let receivers: [Receiver] = trimmed.count == 5
            ? [.X, .Y, .Z, .A, .H]
            : [.X, .Y, .Z, .A]

        var assignments: [RouteAssignment] = []

        for (index, char) in trimmed.enumerated() {
            guard let routeNumber = RouteNumber.from(char) else {
                return .failure(.invalidCharacter(char))
            }

            let receiver = receivers[index]
            let side = formation.side(for: receiver)

            // Side-aware interpretation: the same digit means
            // different things on left vs right
            let meaning = routeNumber.meaning(on: side)

            assignments.append(RouteAssignment(
                receiver: receiver,
                routeNumber: routeNumber,
                side: side,
                initialMeaning: meaning,
                motion: nil
            ))
        }

        return .success(assignments)
    }
}
