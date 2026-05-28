import SwiftUI

/// Main view model coordinating user interactions with the play call system.
@MainActor
final class PlayCallerViewModel: ObservableObject {

    // MARK: - Input State

    @Published var selectedFormation: Formation = .twins
    @Published var selectedConcept: RouteConcept?
    @Published var routeDigitInput: String = ""
    @Published var yMotion: ReceiverMotion? = nil

    // MARK: - Output State

    @Published var currentPlayCall: PlayCall?
    @Published var currentPlayCallWithMotion: PlayCall?
    @Published var errorMessage: String?
    @Published var availableConcepts: [RouteConcept] = []
    @Published var leftSideConcept: RouteConcept?
    @Published var rightSideConcept: RouteConcept?

    // MARK: - Services

    private let interpreter = RouteInterpreter()
    private let library = ConceptLibrary.shared

    // MARK: - Initialization

    init() {
        updateAvailableConcepts()
    }

    // MARK: - Actions

    /// Generate a play call from the selected concept
    func generateFromConcept() {
        errorMessage = nil

        guard let concept = selectedConcept else {
            errorMessage = "Select a concept to generate"
            return
        }

        if let playCall = interpreter.generate(concept: concept, formation: selectedFormation) {
            currentPlayCall = playCall
            routeDigitInput = playCall.routeDigits
            yMotion = nil  // Reset motion when generating new play
            applyMotion()
        } else {
            errorMessage = "\(concept.rawValue) is not available in \(selectedFormation.rawValue)"
        }
    }

    /// Parse manually entered route digits
    func parseRouteDigits() {
        errorMessage = nil

        let trimmed = routeDigitInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter route digits (4 or 5 digits)"
            return
        }

        let result = interpreter.interpret(digits: trimmed, formation: selectedFormation)

        switch result {
        case .success(let playCall):
            currentPlayCall = playCall
            // Sync concept picker if a concept was identified
            selectedConcept = playCall.concept
            yMotion = nil  // Reset motion when parsing new digits
            applyMotion()

        case .failure(let error):
            errorMessage = error.localizedDescription
            currentPlayCall = nil
            yMotion = nil
            applyMotion()
        }
    }

    /// Update available concepts when formation changes
    func updateAvailableConcepts() {
        availableConcepts = library.concepts(for: selectedFormation)
        // Clear concept selection if it's not available in new formation
        if let current = selectedConcept, !availableConcepts.contains(current) {
            selectedConcept = nil
        }
    }

    /// Clear all state
    func reset() {
        routeDigitInput = ""
        currentPlayCall = nil
        errorMessage = nil
        selectedConcept = nil
        yMotion = nil
        currentPlayCallWithMotion = nil
        leftSideConcept = nil
        rightSideConcept = nil
    }

    /// Handle motion change with validation
    func setYMotion(_ motion: ReceiverMotion?) {
        // Only allow motion in Trips formations
        guard selectedFormation.canApplyMotion() else {
            errorMessage = "Motion only available in Trips formations"
            yMotion = nil
            return
        }

        yMotion = motion
        applyMotion()
    }

    /// Apply motion to the current play call and re-identify concepts per side
    private func applyMotion() {
        guard let playCall = currentPlayCall else {
            currentPlayCallWithMotion = nil
            leftSideConcept = nil
            rightSideConcept = nil
            return
        }

        // Create new RouteAssignments with motion applied to Y
        let updatedAssignments = playCall.assignments.map { assignment -> RouteAssignment in
            if assignment.receiver == .Y && yMotion != nil {
                var updated = assignment
                updated.motion = yMotion
                return updated
            }
            return assignment
        }

        // Create derived PlayCall with original concept preserved
        // (View layer decides whether to display it based on motion state)
        currentPlayCallWithMotion = PlayCall(
            formation: playCall.formation,
            routeDigits: playCall.routeDigits,
            assignments: updatedAssignments,
            concept: playCall.concept
        )

        // Re-match concepts for left and right sides independently
        reidentifyConceptsBySide(assignments: updatedAssignments, formation: playCall.formation)
    }

    /// Re-identify concepts separately for left and right sides after motion
    private func reidentifyConceptsBySide(assignments: [RouteAssignment], formation: Formation) {
        // Group receivers by final side after motion
        let leftAssignments = assignments.filter {
            let finalSide = $0.motionFinalSide
            return finalSide == .left
        }
        let rightAssignments = assignments.filter {
            let finalSide = $0.motionFinalSide
            return finalSide == .right
        }

        leftSideConcept = interpreter.identifyForSide(.left, assignments: leftAssignments, formation: formation)
        rightSideConcept = interpreter.identifyForSide(.right, assignments: rightAssignments, formation: formation)
    }

    /// Called when formation changes
    func formationChanged() {
        updateAvailableConcepts()
        // Reset motion when formation changes (motion only valid in Trips formations)
        if !selectedFormation.canApplyMotion() {
            yMotion = nil
        }
        // Re-parse if there are digits entered
        if !routeDigitInput.isEmpty {
            parseRouteDigits()
        } else {
            currentPlayCall = nil
            applyMotion()
        }
    }
}
