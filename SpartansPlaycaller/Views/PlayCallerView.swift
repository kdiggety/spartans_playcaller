import SwiftUI
import UIKit

/// Main play caller interface.
/// Provides formation/concept selection, digit entry, and displays
/// the route diagram and assignment table.
struct PlayCallerView: View {
    @StateObject private var viewModel = PlayCallerViewModel()
    @FocusState private var digitFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    controlsSection
                    conceptSection
                    digitInputSection

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

            Picker("Formation Family", selection: Binding(
                get: { viewModel.selectedFormation.family },
                set: { viewModel.setFormationFamily($0) }
            )) {
                ForEach(FormationFamily.allCases) { family in
                    Text(family.rawValue).tag(family)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedFormation.family.supportsSideSelection {
                Picker("Side", selection: Binding(
                    get: { viewModel.selectedFormation.side ?? .left },
                    set: { viewModel.setFormationSide($0) }
                )) {
                    Text("Left").tag(FieldSide.left)
                    Text("Right").tag(FieldSide.right)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONCEPT")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if viewModel.selectedFormation == .twins {
                VStack(alignment: .leading, spacing: 12) {
                    sideConceptRow(label: "Left", selection: $viewModel.selectedLeftConcept)
                        .onChange(of: viewModel.selectedLeftConcept) { _, _ in
                            viewModel.routeDigitInput = ""
                            viewModel.autoUpdate()
                        }
                    sideConceptRow(label: "Right", selection: $viewModel.selectedRightConcept)
                        .onChange(of: viewModel.selectedRightConcept) { _, _ in
                            viewModel.routeDigitInput = ""
                            viewModel.autoUpdate()
                        }
                }
            } else {
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
                                    viewModel.routeDigitInput = ""
                                    viewModel.autoUpdate()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sideConceptRow(label: String, selection: Binding<RouteConcept?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableConcepts) { concept in
                        ConceptChip(
                            concept: concept,
                            isSelected: selection.wrappedValue == concept
                        ) {
                            selection.wrappedValue = selection.wrappedValue == concept ? nil : concept
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
                    .focused($digitFieldFocused)
                    .onChange(of: viewModel.routeDigitInput) { _, newValue in
                        guard digitFieldFocused else { return }
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            viewModel.routeDigitInput = filtered
                        } else if !filtered.isEmpty {
                            viewModel.autoUpdate()
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                        }
                    }

                Text("X  Y  Z  A  H")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
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

                let showSideBadges = (viewModel.yMotion != nil && viewModel.selectedFormation.canApplyMotion())
                                   || viewModel.selectedFormation == .twins

                if showSideBadges {
                    let hasAnySideConcept = viewModel.leftSideConcept != nil || viewModel.rightSideConcept != nil
                    if hasAnySideConcept {
                        SideConceptBadges(
                            left: viewModel.leftSideConcept,
                            right: viewModel.rightSideConcept
                        )
                    }
                } else if let concept = playCall.concept {
                    ConceptBadge(concept: concept)
                }
                // else: show nothing when concept doesn't match and no motion
            }

            // Route diagram
            RouteDiagramView(playCall: playCall)
                .frame(height: 320)

            // Assignment table with motion picker
            // Use assignments with motion applied (currentPlayCallWithMotion) if available
            let displayAssignments = viewModel.currentPlayCallWithMotion?.assignments ?? playCall.assignments
            ReceiverAssignmentView(
                assignments: displayAssignments,
                selectedMotion: $viewModel.yMotion,
                yWheelEnabled: $viewModel.yWheelEnabled,
                onMotionChange: viewModel.setYMotion,
                isMotionEnabled: viewModel.selectedFormation.canApplyMotion()
            )
            .onChange(of: viewModel.yWheelEnabled) { _, _ in
                viewModel.applyMotion()
            }
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

struct SideConceptBadges: View {
    let left: RouteConcept?
    let right: RouteConcept?

    var body: some View {
        HStack(spacing: 8) {
            if let left {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.caption2)
                    Text(left.rawValue)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
            if left != nil && right != nil {
                Text("|")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let right {
                HStack(spacing: 4) {
                    Text(right.rawValue)
                        .font(.subheadline.bold())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    PlayCallerView()
}
