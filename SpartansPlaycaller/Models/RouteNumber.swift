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

    /// Interpret this route number based on field side.
    /// This is the CORE logic: same number means different routes
    /// depending on left vs right alignment.
    func meaning(on side: FieldSide) -> RouteMeaning {
        switch (self, side) {
        // 0: Hitch on both sides
        case (.zero, _): return .hitch

        // 1: Quick Out (left), Quick Slant (right)
        case (.one, .left): return .quickOut
        case (.one, .right): return .quickSlant
        case (.one, .center): return .quickSlant

        // 2: Quick Slant (left), Quick Out (right)
        case (.two, .left): return .quickSlant
        case (.two, .right): return .quickOut
        case (.two, .center): return .quickOut

        // 3: Out (left), Dig (right)
        case (.three, .left): return .out
        case (.three, .right): return .digIn
        case (.three, .center): return .digIn

        // 4: Dig (left), Out (right)
        case (.four, .left): return .digIn
        case (.four, .right): return .out
        case (.four, .center): return .out

        // 5: Comeback (left), Curl (right)
        case (.five, .left): return .comeback
        case (.five, .right): return .curl
        case (.five, .center): return .curl

        // 6: Curl (left), Comeback (right)
        case (.six, .left): return .curl
        case (.six, .right): return .comeback
        case (.six, .center): return .comeback

        // 7: Corner (left), Post (right)
        case (.seven, .left): return .corner
        case (.seven, .right): return .post
        case (.seven, .center): return .post

        // 8: Post (left), Corner (right)
        case (.eight, .left): return .post
        case (.eight, .right): return .corner
        case (.eight, .center): return .corner

        // 9: Straight vertical Go/Fade
        case (.nine, _): return .goFade
        }
    }

    /// Parse a single character to a RouteNumber
    static func from(_ char: Character) -> RouteNumber? {
        guard let digit = char.wholeNumberValue else { return nil }
        return RouteNumber(rawValue: digit)
    }
}
