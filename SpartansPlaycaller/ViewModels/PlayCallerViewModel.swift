import SwiftUI

/// Main view model coordinating user interactions with the play call system.
@MainActor
final class PlayCallerViewModel: ObservableObject {

    // MARK: - Input State

    @Published var selectedFormation: Formation = .twins
    @Published var selectedConcept: RouteConcept?
    @Published var selectedLeftConcept: RouteConcept?
    @Published var selectedRightConcept: RouteConcept?
    @Published var routeDigitInput: String = ""
    @Published var yMotion: ReceiverMotion? = nil
    @Published var yWheelEnabled: Bool = false

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

    /// Generate a play call from the selected concept(s)
    func generateFromConcept() {
        errorMessage = nil

        if selectedFormation == .twins {
            guard let left = selectedLeftConcept, let right = selectedRightConcept else {
                errorMessage = "Select a concept for each side"
                return
            }
            guard let digits = interpreter.generateTwinsDigits(leftConcept: left, rightConcept: right) else {
                errorMessage = "Cannot generate from \(left.rawValue) / \(right.rawValue)"
                return
            }
            if case .success(let playCall) = interpreter.interpret(digits: digits, formation: selectedFormation) {
                currentPlayCall = playCall
                routeDigitInput = digits
                yMotion = nil
                applyMotion()
            }
        } else {
            guard let concept = selectedConcept else {
                errorMessage = "Select a concept to generate"
                return
            }

            if let playCall = interpreter.generate(concept: concept, formation: selectedFormation) {
                currentPlayCall = playCall
                routeDigitInput = playCall.routeDigits
                yMotion = nil
                applyMotion()
            } else {
                errorMessage = "\(concept.rawValue) is not available in \(selectedFormation.rawValue)"
            }
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
            yMotion = nil  // Reset motion when parsing new digits

            if selectedFormation == .twins {
                // Identify each side and sync to chip selections
                let leftAssignments = playCall.assignments.filter { $0.side == .left }
                let rightAssignments = playCall.assignments.filter { $0.side == .right }
                selectedLeftConcept = interpreter.identifyForSide(.left, assignments: leftAssignments, formation: .twins)
                selectedRightConcept = interpreter.identifyForSide(.right, assignments: rightAssignments, formation: .twins)
                leftSideConcept = selectedLeftConcept
                rightSideConcept = selectedRightConcept
            } else {
                selectedConcept = playCall.concept
            }

            applyMotion()

        case .failure(let error):
            errorMessage = error.localizedDescription
            currentPlayCall = nil
            yMotion = nil
            applyMotion()
        }
    }

    /// Auto-update diagram based on available inputs
    /// Called whenever formation, concepts, or route digits change
    func autoUpdate() {
        if !routeDigitInput.isEmpty {
            parseRouteDigits()
        } else {
            generateFromConcept()
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
        selectedLeftConcept = nil
        selectedRightConcept = nil
        yMotion = nil
        currentPlayCallWithMotion = nil
        leftSideConcept = nil
        rightSideConcept = nil
    }

    /// Handle motion change with validation
    func setYMotion(_ motion: ReceiverMotion?) {
        // Only allow motion in Trips formations
        guard selectedFormation.canApplyMotion() else {
            errorMessage = "Motion only available in Trips and Pro formations"
            yMotion = nil
            return
        }

        yMotion = motion
        applyMotion()
    }

    /// Apply motion to the current play call and re-identify concepts per side
    func applyMotion() {
        guard let playCall = currentPlayCall else {
            currentPlayCallWithMotion = nil
            leftSideConcept = nil
            rightSideConcept = nil
            return
        }

        currentPlayCallWithMotion = PlayCall.applying(yMotion, yWheelEnabled: yWheelEnabled, to: playCall)

        let updatedAssignments = currentPlayCallWithMotion!.assignments
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

    /// Called when formation changes (family change or side toggle)
    /// - Parameter isFamilyChange: true if the formation family changed (Twins→Trips or vice versa);
    ///   false if only the side changed within the same family (Trips Left→Right)
    func formationChanged(isFamilyChange: Bool = true) {
        updateAvailableConcepts()

        // Preserve concepts and motion during side toggle (within same family)
        let savedConcept = !isFamilyChange ? selectedConcept : nil
        let savedLeftConcept = !isFamilyChange ? selectedLeftConcept : nil
        let savedRightConcept = !isFamilyChange ? selectedRightConcept : nil
        let savedMotion = !isFamilyChange ? yMotion : nil

        // Clear concept selections only on family change
        if isFamilyChange {
            selectedLeftConcept = nil
            selectedRightConcept = nil
            selectedConcept = nil
        }

        // Reset motion only when switching to formations that don't support it
        if !selectedFormation.canApplyMotion() {
            yMotion = nil
        }

        // Reset wheel toggle only on family change (not on side toggle within same family)
        if isFamilyChange {
            yWheelEnabled = false
        }

        // Re-parse if there are digits entered (needed for both family change and side toggle)
        if !routeDigitInput.isEmpty {
            parseRouteDigits()
            // Restore concepts and motion after re-parsing if we're toggling sides
            if !isFamilyChange {
                selectedConcept = savedConcept
                selectedLeftConcept = savedLeftConcept
                selectedRightConcept = savedRightConcept
                if selectedFormation.canApplyMotion() {
                    yMotion = savedMotion
                    applyMotion()
                }
                // Regenerate play call to match restored concept (parseRouteDigits may have identified a different concept)
                if selectedConcept != nil || selectedLeftConcept != nil || selectedRightConcept != nil {
                    let motionBeforeRegenerate = yMotion
                    currentPlayCall = nil
                    generateFromConcept()
                    yMotion = motionBeforeRegenerate
                    if yMotion != nil {
                        applyMotion()
                    }
                }
            }
        } else {
            currentPlayCall = nil
            // When toggling sides with concepts selected, regenerate the play call
            if !isFamilyChange && (selectedConcept != nil || selectedLeftConcept != nil || selectedRightConcept != nil) {
                let motionBeforeRegenerate = savedMotion
                generateFromConcept()
                yMotion = motionBeforeRegenerate
                if yMotion != nil {
                    applyMotion()
                }
            } else {
                applyMotion()
            }
        }
    }

    /// Called when the user picks a formation family (e.g. Twins vs. Trips).
    /// Resolves the concrete Formation using the current side (or .left default
    /// for newly-selected side-bearing families) and triggers formationChanged().
    func setFormationFamily(_ family: FormationFamily) {
        if family.supportsSideSelection {
            let currentSide = selectedFormation.family == family
                ? (selectedFormation.side ?? .left)
                : .left
            selectedFormation = family.formation(side: currentSide)
        } else {
            selectedFormation = family.formation(side: .left)
        }
        formationChanged()
    }

    /// Called when the user toggles Left / Right within a side-bearing family.
    /// No-ops when the current family does not support side selection.
    func setFormationSide(_ side: FieldSide) {
        guard selectedFormation.family.supportsSideSelection else { return }
        let newFormation = selectedFormation.family.formation(side: side)
        guard newFormation != selectedFormation else { return }
        selectedFormation = newFormation
        // isFamilyChange: false because we're only toggling side within the same family
        // This preserves Y motion and concept selections
        formationChanged(isFamilyChange: false)
    }
}
