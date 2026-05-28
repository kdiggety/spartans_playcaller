import Foundation

/// The concept library holds all known concept templates.
/// It provides lookup by formation and concept, and supports
/// both generation (concept → digits) and identification (digits → concept).
struct ConceptLibrary {

    /// All registered concept templates
    let templates: [ConceptTemplate]

    /// Singleton with all built-in concepts
    static let shared = ConceptLibrary(templates: ConceptLibrary.buildTemplates())

    /// Get all concepts available for a given formation
    func concepts(for formation: Formation) -> [RouteConcept] {
        let matched = templates
            .filter { $0.formationContext.matches(formation: formation) }
            .map { $0.concept }
        return Array(Set(matched)).sorted { $0.rawValue < $1.rawValue }
    }

    /// Get the template for a specific concept in a formation
    func template(for concept: RouteConcept, in formation: Formation) -> ConceptTemplate? {
        templates.first { $0.concept == concept && $0.formationContext.matches(formation: formation) }
    }

    // MARK: - Template Definitions

    private static func buildTemplates() -> [ConceptTemplate] {
        var templates: [ConceptTemplate] = []

        // ──────────────────────────────────────────────
        // TWINS LEFT (X and Y on left side)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .twinsLeft,
            receiverRoutes: [.X: .six, .Y: .seven]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .twinsLeft,
            receiverRoutes: [.X: .four, .Y: .nine]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .twinsLeft,
            receiverRoutes: [.X: .eight, .Y: .seven]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .twinsLeft,
            receiverRoutes: [.X: .nine, .Y: .three]
        ))

        // ──────────────────────────────────────────────
        // TWINS RIGHT (Z and A on right side)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .five, .A: .eight]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .three, .A: .nine]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .seven, .A: .eight]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .four, .A: .nine]
        ))

        // ──────────────────────────────────────────────
        // TRIPS LEFT (A, X, Y on left)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .six, .Y: .seven, .A: .four]
        ))

        templates.append(ConceptTemplate(
            concept: .china,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .six, .Y: .seven, .A: .six]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .one, .Y: .nine, .A: .four]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .nine, .Y: .three, .A: .one]
        ))

        // ──────────────────────────────────────────────
        // TRIPS RIGHT (Y, Z, A on right)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .tripsRight,
            receiverRoutes: [.Z: .five, .Y: .eight, .A: .one]
        ))

        templates.append(ConceptTemplate(
            concept: .china,
            formationContext: .tripsRight,
            receiverRoutes: [.Z: .five, .Y: .eight, .A: .five]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .tripsRight,
            receiverRoutes: [.Z: .seven, .Y: .eight, .A: .five]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .tripsRight,
            receiverRoutes: [.Z: .two, .Y: .nine, .A: .three]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .tripsRight,
            receiverRoutes: [.Z: .nine, .Y: .four, .A: .one]
        ))

        return templates
    }
}
