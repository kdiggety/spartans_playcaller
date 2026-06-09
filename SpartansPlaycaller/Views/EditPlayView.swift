import SwiftUI

struct EditPlayView: View {
    @StateObject private var viewModel: EditPlayViewModel
    @EnvironmentObject private var store: PlayLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDiscardAlert = false

    init(play: SavedPlay) {
        _viewModel = StateObject(wrappedValue: EditPlayViewModel(play: play))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Formation") {
                    Picker("Formation Family", selection: Binding(
                        get: { viewModel.selectedFormation.family },
                        set: { family in
                            if family.supportsSideSelection {
                                let side = viewModel.selectedFormation.family == family
                                    ? (viewModel.selectedFormation.side ?? .left)
                                    : .left
                                viewModel.selectedFormation = family.formation(side: side)
                            } else {
                                viewModel.selectedFormation = family.formation(side: .left)
                            }
                            if !viewModel.selectedFormation.canApplyMotion() {
                                viewModel.selectedMotion = nil
                            }
                            viewModel.validateInput()
                        }
                    )) {
                        ForEach(FormationFamily.allCases) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.selectedFormation.family.supportsSideSelection {
                        Picker("Side", selection: Binding(
                            get: { viewModel.selectedFormation.side ?? .left },
                            set: { side in
                                viewModel.selectedFormation = viewModel.selectedFormation.family.formation(side: side)
                                viewModel.validateInput()
                            }
                        )) {
                            Text("Left").tag(FieldSide.left)
                            Text("Right").tag(FieldSide.right)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Route Digits") {
                    TextField("e.g. 6794", text: $viewModel.routeDigitInput)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.routeDigitInput) { _, _ in
                            viewModel.validateInput()
                        }
                    if let error = viewModel.validationError {
                        errorBanner(error)
                    }
                }

                if viewModel.selectedFormation.canApplyMotion() {
                    Section("Motion") {
                        Picker("Motion", selection: $viewModel.selectedMotion) {
                            Text("None").tag(Optional<ReceiverMotion>.none)
                            ForEach(ReceiverMotion.allCases) { motion in
                                Text(motion.rawValue).tag(Optional(motion))
                            }
                        }
                    }
                }

                Section {
                    Toggle("Y Wheel", isOn: $viewModel.yWheelEnabled)
                }
            }
            .navigationTitle("Edit Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.isDirty {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(to: store)
                    }
                    .disabled(
                        viewModel.validationError != nil
                        || viewModel.routeDigitInput.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert("Save Failed", isPresented: Binding(
            get: { viewModel.persistError != nil },
            set: { if !$0 { viewModel.persistError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.persistError = nil }
        } message: {
            Text(viewModel.persistError ?? "Could not save. Please try again.")
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    EditPlayView(play: SavedPlay(
        id: UUID(), savedAt: Date(),
        formationName: "Twins", routeDigits: "6794",
        conceptName: "Smash", motionLabel: nil, yWheelEnabled: false
    ))
    .environmentObject(PlayLibraryStore())
}
