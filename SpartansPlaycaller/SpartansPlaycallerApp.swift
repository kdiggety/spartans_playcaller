import SwiftUI

@main
struct SpartansPlaycallerApp: App {
    @StateObject private var libraryStore = PlayLibraryStore()

    var body: some Scene {
        WindowGroup {
            PlayCallerView()
                .environmentObject(libraryStore)
        }
    }
}
