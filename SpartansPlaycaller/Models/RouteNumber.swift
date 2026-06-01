import Foundation

/// A route digit (0-9). Each digit has a STATIC number but its
/// meaning changes based on which side of the ball the receiver is on.
enum RouteNumber: Int, CaseIterable, Identifiable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9

    var id: Int { rawValue }

    /// Semantic provider for this route. Each route uses a semantic type
    /// (SideAware, AbsoluteDirection, Bubble) to define how meaning
    /// varies (or stays constant) based on field side.
    var semanticProvider: RouteSemanticProvider {
        switch self {
        case .zero:
            return BubbleRouteSemantics(meaning: .hitch)

        case .one:
            return SideAwareRouteSemantics(
                leftMeaning: .quickOut,
                rightMeaning: .quickSlant
            )

        case .two:
            return SideAwareRouteSemantics(
                leftMeaning: .quickSlant,
                rightMeaning: .quickOut
            )

        case .three:
            return SideAwareRouteSemantics(
                leftMeaning: .out,
                rightMeaning: .digIn
            )

        case .four:
            return SideAwareRouteSemantics(
                leftMeaning: .digIn,
                rightMeaning: .out
            )

        case .five:
            return SideAwareRouteSemantics(
                leftMeaning: .comeback,
                rightMeaning: .curl
            )

        case .six:
            return SideAwareRouteSemantics(
                leftMeaning: .curl,
                rightMeaning: .comeback
            )

        case .seven:
            return SideAwareRouteSemantics(
                leftMeaning: .corner,
                rightMeaning: .post
            )

        case .eight:
            return SideAwareRouteSemantics(
                leftMeaning: .post,
                rightMeaning: .corner
            )

        case .nine:
            return SideAwareRouteSemantics(
                leftMeaning: .goFade,
                rightMeaning: .goFade
            )
        }
    }

    /// Interpret this route number based on field side.
    /// This is the CORE logic: same number means different routes
    /// depending on left vs right alignment.
    func meaning(on side: FieldSide) -> RouteMeaning {
        return semanticProvider.meaning(on: side)
    }

    /// Parse a single character to a RouteNumber
    static func from(_ char: Character) -> RouteNumber? {
        guard let digit = char.wholeNumberValue else { return nil }
        return RouteNumber(rawValue: digit)
    }
}
