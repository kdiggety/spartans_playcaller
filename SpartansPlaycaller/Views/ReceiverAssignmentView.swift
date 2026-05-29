import SwiftUI

/// Displays the receiver assignment table showing each receiver's
/// route number, field side, and interpreted route meaning.
/// Also provides a motion picker for the Y receiver (Trips formations only).
struct ReceiverAssignmentView: View {
    let assignments: [RouteAssignment]
    @Binding var selectedMotion: ReceiverMotion?
    let onMotionChange: (ReceiverMotion?) -> Void
    let isMotionEnabled: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("WR")
                    .frame(width: 36, alignment: .leading)
                Text("#")
                    .frame(width: 24, alignment: .center)
                Text("Side")
                    .frame(width: 50, alignment: .center)
                Text("Route")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Rows
            ForEach(assignments) { assignment in
                VStack(spacing: 0) {
                    HStack {
                        Text(assignment.receiver.rawValue)
                            .font(.system(.body, design: .monospaced, weight: .bold))
                            .foregroundColor(receiverColor(assignment.receiver))
                            .frame(width: 36, alignment: .leading)

                        Text("\(assignment.routeNumber.rawValue)")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 24, alignment: .center)

                        // Side column with motion indicator
                        VStack(alignment: .center, spacing: 2) {
                            Text(assignment.side.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if assignment.receiver == .Y && assignment.motion != nil && assignment.motionFinalSide != assignment.side {
                                Text("→ \(assignment.motionFinalSide.rawValue.capitalized)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(width: 50, alignment: .center)

                        Text(assignment.meaning.rawValue)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    // Motion picker for Y receiver (Trips/Pro formations only)
                    if assignment.receiver == .Y && isMotionEnabled {
                        Divider().padding(.leading, 12)

                        VStack(spacing: 8) {
                            Picker("Y Motion", selection: $selectedMotion) {
                                Text("None").tag(Optional<ReceiverMotion>.none)
                                Text("Stop").tag(Optional<ReceiverMotion>.some(.stop))
                                Text("After").tag(Optional<ReceiverMotion>.some(.after))
                                Text("Go").tag(Optional<ReceiverMotion>.some(.go))
                                Text("Wheel").tag(Optional<ReceiverMotion>.some(.wheel))
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedMotion) { _, newValue in
                                onMotionChange(newValue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                    }
                }

                if assignment.id != assignments.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func receiverColor(_ receiver: Receiver) -> Color {
        switch receiver {
        case .X: return .cyan
        case .Y: return .yellow
        case .Z: return .green
        case .A: return .orange
        case .H: return .pink
        }
    }
}
