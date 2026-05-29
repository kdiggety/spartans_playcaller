import SwiftUI

/// Displays left and right-side identified concepts in a side-by-side layout.
/// Shows concept badges for each side, with placeholders for nil concepts.
struct ConceptBadgeRow: View {
    let leftConcept: RouteConcept?
    let rightConcept: RouteConcept?
    let hasMotion: Bool

    var body: some View {
        VStack(spacing: 12) {
            if leftConcept == nil && rightConcept == nil && !hasMotion {
                Text("No side-specific concepts identified")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 16) {
                    // Left chevron
                    Text("<")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)

                    // Left concept
                    if let concept = leftConcept {
                        ConceptBadge(concept: concept)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }

                    // Right concept
                    if let concept = rightConcept {
                        ConceptBadge(concept: concept)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("—")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }

                    // Right chevron
                    Text(">")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }

                if hasMotion {
                    Text("Motion Applied")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Both Concepts Identified") {
    ConceptBadgeRow(
        leftConcept: .smash,
        rightConcept: .dagger,
        hasMotion: true
    )
    .padding()
}

#Preview("Left Concept Only") {
    ConceptBadgeRow(
        leftConcept: .smash,
        rightConcept: nil,
        hasMotion: false
    )
    .padding()
}

#Preview("No Concepts") {
    ConceptBadgeRow(
        leftConcept: nil,
        rightConcept: nil,
        hasMotion: false
    )
    .padding()
}
