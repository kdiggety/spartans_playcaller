import SwiftUI
import UIKit

struct PlayLibraryView: View {
    @EnvironmentObject private var store: PlayLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showExportSheet = false
    @State private var exportMode: ExportMode? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil

    private var selectedPlays: [SavedPlay] {
        store.plays.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.plays.isEmpty {
                    emptyState
                } else {
                    playList
                }
            }
            .navigationTitle("Play Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        Button("Cancel") {
                            isSelectMode = false
                            selectedIDs = []
                        }
                    } else {
                        Button("Select") {
                            isSelectMode = true
                        }
                        .disabled(store.plays.isEmpty)
                    }
                }
                if isSelectMode {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Select All") {
                                selectedIDs = Set(store.plays.map { $0.id })
                            }
                            Spacer()
                            exportButton
                        }
                    }
                }
            }
        }
        .confirmationDialog("Export \(selectedPlays.count) Play\(selectedPlays.count == 1 ? "" : "s")",
                           isPresented: $showExportSheet, titleVisibility: .visible) {
            Button("Play Catalog") { triggerExport(mode: .catalog) }
            Button("Wristband Cards") { triggerExport(mode: .wristband) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Could not generate PDF. Please try again.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No plays saved yet.")
                .font(.headline)
            Text("Build a play and tap the bookmark button to save it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var playList: some View {
        List(selection: isSelectMode ? $selectedIDs : .constant(Set<UUID>())) {
            ForEach(store.plays) { play in
                PlayLibraryRow(play: play, isSelectMode: isSelectMode, isSelected: selectedIDs.contains(play.id)) {
                    if isSelectMode {
                        if selectedIDs.contains(play.id) {
                            selectedIDs.remove(play.id)
                        } else {
                            selectedIDs.insert(play.id)
                        }
                    }
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
        .listStyle(.plain)
    }

    private var exportButton: some View {
        Button {
            showExportSheet = true
        } label: {
            if isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Export \(selectedIDs.count) Play\(selectedIDs.count == 1 ? "" : "s")", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(selectedIDs.isEmpty || isExporting)
    }

    private func triggerExport(mode: ExportMode) {
        isExporting = true
        let plays = selectedPlays
        let interpreter = RouteInterpreter()

        Task {
            let cards: [ExportCard] = plays.enumerated().compactMap { (i, savedPlay) in
                ExportCard.from(savedPlay: savedPlay, playNumber: i + 1, interpreter: interpreter)
            }

            let data: Data?
            switch mode {
            case .catalog: data = CatalogPDFGenerator.generate(cards: cards)
            case .wristband: data = WristbandPDFGenerator.generate(cards: cards)
            }

            await MainActor.run {
                isExporting = false
                guard let pdfData = data else {
                    exportError = "Could not generate PDF. Please try again."
                    return
                }
                presentShareSheet(data: pdfData, mode: mode, cardCount: plays.count)
            }
        }
    }

    private func presentShareSheet(data: Data, mode: ExportMode, cardCount: Int) {
        // REQ-SEC-2: temp file in temporaryDirectory
        let modeSuffix = mode == .catalog ? "catalog" : "wristband"
        let filename = "\(UUID().uuidString)-\(cardCount)-plays-\(modeSuffix).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            // REQ-SEC-3: completeFileProtection
            try data.write(to: tempURL, options: .completeFileProtection)
        } catch {
            exportError = "Could not write PDF. Please try again."
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        // REQ-SEC-4: delete temp file on dismiss
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: tempURL)
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(activityVC, animated: true)
        }
    }
}

// MARK: - PlayLibraryRow

private struct PlayLibraryRow: View {
    let play: SavedPlay
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if isSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(play.formationName)
                            .font(.subheadline.weight(.semibold))
                        Text(play.routeDigits)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    HStack(spacing: 8) {
                        if let concept = play.conceptName {
                            Text(concept)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let motion = play.motionLabel {
                            Text(motion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

// MARK: - ExportMode

enum ExportMode {
    case catalog
    case wristband
}

#Preview {
    PlayLibraryView()
        .environmentObject(PlayLibraryStore())
}
