import SwiftUI
import UIKit

struct PlayLibraryView: View {
    @EnvironmentObject private var store: PlayLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSelectMode = false
    @State private var editMode: EditMode = .inactive
    @State private var preSessionOrder: [SavedPlay] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var showExportSheet = false
    @State private var exportMode: ExportMode? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil
    @State private var playBeingEdited: SavedPlay? = nil
    @State private var playPendingDelete: SavedPlay? = nil
    @State private var showMultiDeleteConfirmation = false
    @State private var showDeleteAllConfirmation = false

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
                    if isSelectMode {
                        Button("Cancel") { cancelEdit() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if !isSelectMode && !store.plays.isEmpty {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteAllConfirmation = true
                                } label: {
                                    Label("Delete All Plays", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .accessibilityLabel("More options")
                            }
                        }
                        if isSelectMode {
                            Button("Done") { commitEdit() }
                        } else {
                            Button("Edit") { enterEditMode() }
                                .disabled(store.plays.isEmpty)
                        }
                    }
                }
                if isSelectMode {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Select All") {
                                selectedIDs = Set(store.plays.map { $0.id })
                            }
                            Spacer()
                            Button(role: .destructive) {
                                showMultiDeleteConfirmation = true
                            } label: {
                                Label("Delete \(selectedIDs.count)", systemImage: "trash")
                            }
                            .disabled(selectedIDs.isEmpty)
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
        .sheet(item: $playBeingEdited) { play in
            EditPlayView(play: play)
                .environmentObject(store)
        }
        .alert(item: $playPendingDelete) { play in
            Alert(
                title: Text("Delete Play?"),
                message: Text("\(play.formationName) \(play.routeDigits)"),
                primaryButton: .destructive(Text("Delete")) {
                    if let index = store.plays.firstIndex(where: { $0.id == play.id }) {
                        store.delete(at: IndexSet([index]))
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Delete \(selectedIDs.count) Play\(selectedIDs.count == 1 ? "" : "s")?",
               isPresented: $showMultiDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let indices = IndexSet(store.plays.indices.filter { selectedIDs.contains(store.plays[$0].id) })
                store.delete(at: indices)
                selectedIDs = []
                isSelectMode = false
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete All \(store.plays.count) Play\(store.plays.count == 1 ? "" : "s")?",
               isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                store.deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
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
                PlayLibraryRow(
                    play: play,
                    isSelectMode: isSelectMode,
                    isSelected: selectedIDs.contains(play.id),
                    dragHandleEnabled: store.plays.count > 1
                ) {
                    if isSelectMode {
                        if selectedIDs.contains(play.id) {
                            selectedIDs.remove(play.id)
                        } else {
                            selectedIDs.insert(play.id)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isSelectMode {
                        Button(role: .destructive) {
                            playPendingDelete = play
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            playBeingEdited = play
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .onMove { offsets, destination in
                store.move(fromOffsets: offsets, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
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

    // MARK: - Edit mode lifecycle

    private func enterEditMode() {
        preSessionOrder = store.plays
        withAnimation(.easeInOut(duration: 0.15)) {
            isSelectMode = true
            editMode = .active
        }
    }

    private func commitEdit() {
        store.commitReorder()
        preSessionOrder = []
        withAnimation(.easeInOut(duration: 0.15)) {
            isSelectMode = false
            editMode = .inactive
            selectedIDs = []
        }
    }

    private func cancelEdit() {
        store.cancelReorder(snapshot: preSessionOrder)
        preSessionOrder = []
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectMode = false
            editMode = .inactive
            selectedIDs = []
        }
    }
}

// MARK: - PlayLibraryRow

private struct PlayLibraryRow: View {
    let play: SavedPlay
    let isSelectMode: Bool
    let isSelected: Bool
    let dragHandleEnabled: Bool
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
                if isSelectMode {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .opacity(dragHandleEnabled ? 1.0 : 0.3)
                        .allowsHitTesting(dragHandleEnabled)
                        .accessibilityLabel("Reorder \(play.formationName) \(play.routeDigits)")
                        .accessibilityHint(dragHandleEnabled ? "" : "Reordering requires at least 2 plays")
                }
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
