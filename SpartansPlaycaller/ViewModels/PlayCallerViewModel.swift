import SwiftUI

/// Main view model coordinating user interactions with the play call system.
@MainActor
final class PlayCallerViewModel: ObservableObject {

    // MARK: - Input State

    @Published var selectedFormation: Formation = .twins
    @Published var selectedConcept: RouteConcept?
    @Published var routeDigitInput: String = ""

    // MARK: - Output State

    @Published var currentPlayCall: PlayCall?
    @Published var errorMessage: String?
    @Published var availableConcepts: [RouteConcept] = []

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

        case .failure(let error):
            errorMessage = error.localizedDescription
            currentPlayCall = nil
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
    }

    /// Called when formation changes
    func formationChanged() {
        updateAvailableConcepts()
        // Re-parse if there are digits entered
        if !routeDigitInput.isEmpty {
            parseRouteDigits()
        } else {
            currentPlayCall = nil
        }
    }
}
