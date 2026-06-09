import SwiftUI

@MainActor
final class EditPlayViewModel: ObservableObject {
    @Published var selectedFormation: Formation
    @Published var routeDigitInput: String
    @Published var selectedMotion: ReceiverMotion?
    @Published var yWheelEnabled: Bool
    @Published var validationError: String?
    @Published var persistError: String?
    @Published var didSave = false

    private let _original: SavedPlay

    var isDirty: Bool {
        selectedFormation.rawValue != _original.formationName
            || routeDigitInput != _original.routeDigits
            || selectedMotion?.rawValue != _original.motionLabel
            || yWheelEnabled != _original.yWheelEnabled
    }

    init(play: SavedPlay) {
        self.selectedFormation = Formation(rawValue: play.formationName) ?? .twins
        self.routeDigitInput = play.routeDigits
        self.selectedMotion = play.motionLabel.flatMap(ReceiverMotion.init(rawValue:))
        self.yWheelEnabled = play.yWheelEnabled
        self._original = play
    }

    func validateInput() {
        let trimmed = routeDigitInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationError = "Enter route digits (4 or 5 digits)"
            return
        }
        switch RouteInterpreter().interpret(digits: trimmed, formation: selectedFormation) {
        case .success:
            validationError = nil
        case .failure(let e):
            validationError = e.localizedDescription
        }
    }

    func save(to store: PlayLibraryStore) {
        let trimmed = routeDigitInput.trimmingCharacters(in: .whitespaces)
        let candidate = SavedPlay(
            id: _original.id,
            savedAt: Date(),
            formationName: selectedFormation.rawValue,
            routeDigits: trimmed,
            conceptName: _original.conceptName,
            motionLabel: selectedMotion?.rawValue,
            yWheelEnabled: yWheelEnabled
        )
        switch store.update(candidate) {
        case .success:
            didSave = true
        case .failure(.invalidRouteDigits(let msg)):
            validationError = msg
        case .failure(.playNotFound):
            persistError = "Play no longer exists. It may have been deleted."
        case .failure(.persistenceFailed):
            persistError = "Could not save. Your edit was not written to disk."
        }
    }
}
