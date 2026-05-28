import Foundation

/// Matches a set of route assignments against the concept library
/// to identify known concepts. The Twins formation is special:
/// it checks both left-side and right-side concept templates.
struct ConceptMatcher {

    private let library: ConceptLibrary

    init(library: ConceptLibrary = .shared) {
        self.library = library
    }

    /// Attempt to identify a concept from parsed route assignments.
    /// Returns nil if no known concept matches.
    func identify(assignments: [RouteAssignment], formation: Formation) -> RouteConcept? {
        let routeMap = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.receiver, $0.routeNumber) }
        )

        // For Twins formation, check both left and right concept groups
        if formation == .twins {
            if let match = library.templates.first(where: {
                $0.formationContext == .twinsLeft && $0.matches(assignments: routeMap)
            }) {
                return match.concept
            }
            if let match = library.templates.first(where: {
                $0.formationContext == .twinsRight && $0.matches(assignments: routeMap)
            }) {
                return match.concept
            }
        }

        let matchingTemplate = library.templates.first { template in
            template.formationContext.matches(formation: formation) && template.matches(assignments: routeMap)
        }

        return matchingTemplate?.concept
    }

    /// Generate the full route digits for a concept in a formation.
    /// Non-concept receivers default to Go (9).
    func generateDigits(concept: RouteConcept, formation: Formation, fillRoute: RouteNumber = .nine) -> String? {
        guard let template = library.template(for: concept, in: formation) else {
            // For Twins, try both sides
            if formation == .twins {
                if let leftTemplate = library.templates.first(where: {
                    $0.concept == concept && $0.formationContext == .twinsLeft
                }) {
                    return buildDigits(from: leftTemplate, fillRoute: fillRoute)
                }
                if let rightTemplate = library.templates.first(where: {
                    $0.concept == concept && $0.formationContext == .twinsRight
                }) {
                    return buildDigits(from: rightTemplate, fillRoute: fillRoute)
                }
            }
            return nil
        }
        return buildDigits(from: template, fillRoute: fillRoute)
    }

    private func buildDigits(from template: ConceptTemplate, fillRoute: RouteNumber) -> String {
        let receivers: [Receiver] = [.X, .Y, .Z, .A]
        let digits = receivers.map { receiver -> String in
            let route = template.receiverRoutes[receiver] ?? fillRoute
            return "\(route.rawValue)"
        }
        return digits.joined()
    }
}

extension FormationContext: Equatable {
    static func == (lhs: FormationContext, rhs: FormationContext) -> Bool {
        switch (lhs, rhs) {
        case (.specific(let a), .specific(let b)): return a == b
        case (.twinsLeft, .twinsLeft): return true
        case (.twinsRight, .twinsRight): return true
        case (.tripsLeft, .tripsLeft): return true
        case (.tripsRight, .tripsRight): return true
        default: return false
        }
    }
}
