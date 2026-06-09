import Foundation
import Combine

enum UpdateError: LocalizedError {
    case playNotFound(UUID)
    case invalidRouteDigits(String)
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .playNotFound:
            return "Play no longer exists. It may have been deleted."
        case .invalidRouteDigits(let msg):
            return msg
        case .persistenceFailed:
            return "Could not save. Your edit was not written to disk."
        }
    }
}

extension UpdateError: Equatable {
    static func == (lhs: UpdateError, rhs: UpdateError) -> Bool {
        switch (lhs, rhs) {
        case (.playNotFound(let a), .playNotFound(let b)): return a == b
        case (.invalidRouteDigits(let a), .invalidRouteDigits(let b)): return a == b
        case (.persistenceFailed, .persistenceFailed): return true
        default: return false
        }
    }
}

@MainActor
final class PlayLibraryStore: ObservableObject {
    @Published private(set) var plays: [SavedPlay] = []

    private let fileURL: URL

    nonisolated static var defaultFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("play-library.json")
    }

    init(fileURL: URL = PlayLibraryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func save(_ playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool) {
        plays.append(SavedPlay.from(playCall: playCall, motion: motion, yWheelEnabled: yWheelEnabled))
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    func delete(at offsets: IndexSet) {
        plays.remove(atOffsets: offsets)
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    func deleteAll() {
        plays = []
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    @discardableResult
    func update(_ play: SavedPlay) -> Result<Void, UpdateError> {
        guard let index = plays.firstIndex(where: { $0.id == play.id }) else {
            return .failure(.playNotFound(play.id))
        }
        guard let formation = Formation(rawValue: play.formationName) else {
            return .failure(.invalidRouteDigits("Unknown formation: \(play.formationName)"))
        }
        let playCall: PlayCall
        switch RouteInterpreter().interpret(digits: play.routeDigits, formation: formation) {
        case .failure(let e):
            return .failure(.invalidRouteDigits(e.localizedDescription))
        case .success(let pc):
            playCall = pc
        }
        let original = plays[index]
        let updated = SavedPlay(
            id: play.id,
            savedAt: Date(),
            formationName: play.formationName,
            routeDigits: play.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: play.motionLabel,
            yWheelEnabled: play.yWheelEnabled
        )
        plays[index] = updated
        do {
            try persist()
            return .success(())
        } catch {
            plays[index] = original
            return .failure(.persistenceFailed(error))
        }
    }

    // MARK: - Reorder

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        plays.move(fromOffsets: offsets, toOffset: destination)
        // NOTE: No persist() call here — deferred to commitReorder().
    }

    func commitReorder() {
        do { try persist() } catch { print("[PlayLibraryStore] commitReorder persist failed: \(error)") }
    }

    func cancelReorder(snapshot: [SavedPlay]) {
        if snapshot.isEmpty && !plays.isEmpty {
            assertionFailure("[PlayLibraryStore] cancelReorder called with empty snapshot but plays is non-empty — snapshot not initialized on mode entry")
        }
        plays = snapshot
        // NOTE: No persist() call here — snapshot restore must never write to disk (AC-2.3).
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            plays = try JSONDecoder().decode([SavedPlay].self, from: data)
        } catch {
            print("[PlayLibraryStore] load failed: \(error)")
            plays = []
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(plays)
        try data.write(to: fileURL, options: .completeFileProtection)
    }
}
