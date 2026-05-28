import SwiftUI

/// Main play caller interface.
/// Provides formation/concept selection, digit entry, and displays
/// the route diagram and assignment table.
struct PlayCallerView: View {
    @StateObject private var viewModel = PlayCallerViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    controlsSection
                    conceptSection
                    digitInputSection
                    actionButtons

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    if let playCall = viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall {
                        resultSection(playCall)
                    }
                }
                .padding()
            }
            .navigationTitle("Spartans Playcaller")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset", action: viewModel.reset)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Sections

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FORMATION")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Picker("Formation", selection: $viewModel.selectedFormation) {
                ForEach(Formation.allCases) { formation in
                    Text(formation.rawValue).tag(formation)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedFormation) { _, _ in
                viewModel.formationChanged()
            }
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONCEPT")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if viewModel.availableConcepts.isEmpty {
                Text("No concepts available for this formation")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableConcepts) { concept in
                            ConceptChip(
                                concept: concept,
                                isSelected: viewModel.selectedConcept == concept
                            ) {
                                viewModel.selectedConcept = concept
                            }
                        }
                    }
                }
            }
        }
    }

    private var digitInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTE DIGITS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                TextField("e.g. 6794", text: $viewModel.routeDigitInput)
                    .font(.system(.title2, design: .monospaced, weight: .medium))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)

                Text("X  Y  Z  A  H")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.generateFromConcept) {
                Label("Generate", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.selectedConcept == nil)

            Button(action: viewModel.parseRouteDigits) {
                Label("Parse", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(viewModel.routeDigitInput.isEmpty)
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

    private func resultSection(_ playCall: PlayCall) -> some View {
        VStack(spacing: 16) {
            // Play call header
            VStack(spacing: 4) {
                Text(playCall.displayName)
                    .font(.title2.bold())

                if let concept = playCall.concept {
                    ConceptBadge(concept: concept)
                } else {
                    Text("Unknown / Custom Concept")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }

            // Route diagram
            RouteDiagramView(playCall: playCall)
                .frame(height: 320)

            // Concept badges by side (after motion)
            ConceptBadgeRow(
                leftConcept: viewModel.leftSideConcept,
                rightConcept: viewModel.rightSideConcept,
                hasMotion: viewModel.yMotion != nil
            )

            // Assignment table with motion picker
            // Use assignments with motion applied (currentPlayCallWithMotion) if available
            let displayAssignments = viewModel.currentPlayCallWithMotion?.assignments ?? playCall.assignments
            ReceiverAssignmentView(
                assignments: displayAssignments,
                selectedMotion: $viewModel.yMotion,
                onMotionChange: viewModel.setYMotion,
                isMotionEnabled: viewModel.selectedFormation.canApplyMotion()
            )
        }
    }
}

// MARK: - Supporting Views

struct ConceptChip: View {
    let concept: RouteConcept
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(concept.rawValue)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ConceptBadge: View {
    let concept: RouteConcept

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(concept.rawValue)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    PlayCallerView()
}
