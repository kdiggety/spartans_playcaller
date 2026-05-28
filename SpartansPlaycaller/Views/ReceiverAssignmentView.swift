import SwiftUI

/// Displays the receiver assignment table showing each receiver's
/// route number, field side, and interpreted route meaning.
struct ReceiverAssignmentView: View {
    let assignments: [RouteAssignment]

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
                HStack {
                    Text(assignment.receiver.rawValue)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .foregroundColor(receiverColor(assignment.receiver))
                        .frame(width: 36, alignment: .leading)

                    Text("\(assignment.routeNumber.rawValue)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 24, alignment: .center)

                    Text(assignment.side.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .center)

                    Text(assignment.meaning.rawValue)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

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
