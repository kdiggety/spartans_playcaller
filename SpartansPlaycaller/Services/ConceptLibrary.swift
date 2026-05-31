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
        // TWINS LEFT (X and A on left side)
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
        // TWINS RIGHT (Y and Z on right side)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .eight, .A: .five]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .nine, .A: .three]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .twinsRight,
            receiverRoutes: [.Z: .eight, .A: .seven]
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
            concept: .scissors,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .eight, .Y: .seven, .A: .six]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .tripsLeft,
            receiverRoutes: [.X: .nine, .Y: .three, .A: .two]
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

        // ──────────────────────────────────────────────
        // PRO LEFT (X and Y on left; Z isolated right)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .proLeft,
            receiverRoutes: [.X: .six, .Y: .seven]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .proLeft,
            receiverRoutes: [.X: .four, .Y: .nine]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .proLeft,
            receiverRoutes: [.X: .eight, .Y: .seven]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .proLeft,
            receiverRoutes: [.X: .nine, .Y: .three]
        ))

        // ──────────────────────────────────────────────
        // PRO RIGHT (X isolated left; Y slot and Z on right)
        // ──────────────────────────────────────────────

        templates.append(ConceptTemplate(
            concept: .smash,
            formationContext: .proRight,
            receiverRoutes: [.Y: .eight, .Z: .five]
        ))

        templates.append(ConceptTemplate(
            concept: .dagger,
            formationContext: .proRight,
            receiverRoutes: [.Y: .nine, .Z: .three]
        ))

        templates.append(ConceptTemplate(
            concept: .scissors,
            formationContext: .proRight,
            receiverRoutes: [.Y: .eight, .Z: .seven]
        ))

        templates.append(ConceptTemplate(
            concept: .sail,
            formationContext: .proRight,
            receiverRoutes: [.Y: .four, .Z: .nine]
        ))

        return templates
    }
}
