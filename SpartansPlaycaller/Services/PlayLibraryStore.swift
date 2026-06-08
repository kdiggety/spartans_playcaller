import Foundation
import Combine

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
        persist()
    }

    func delete(at offsets: IndexSet) {
        plays.remove(atOffsets: offsets)
        persist()
    }

    func deleteAll() {
        plays = []
        persist()
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

    private func persist() {
        do {
            let data = try JSONEncoder().encode(plays)
            try data.write(to: fileURL, options: .completeFileProtection)
        } catch {
            print("[PlayLibraryStore] persist failed: \(error)")
        }
    }
}
