import Foundation

/// Protocol for route meaning semantics. Each route (0–9) implements this to define
/// how a receiver interprets the route based on field side.
protocol RouteSemanticProvider {
    /// Return the route meaning for a receiver on a given field side.
    /// - Parameter side: The field side (left, right, or center).
    /// - Returns: The RouteMeaning describing the route's direction and type.
    func meaning(on side: FieldSide) -> RouteMeaning
}

/// Standard side-aware route: meaning differs based on receiver's field side.
/// Example: Route 1 is Quick Out on left side, Quick Slant on right side.
struct SideAwareRouteSemantics: RouteSemanticProvider {
    let leftMeaning: RouteMeaning
    let rightMeaning: RouteMeaning

    func meaning(on side: FieldSide) -> RouteMeaning {
        switch side {
        case .left:
            return leftMeaning
        case .right:
            return rightMeaning
        case .center:
            return leftMeaning // Center (H) treats as left for interpretation
        }
    }
}

/// Absolute direction route: meaning is identical regardless of receiver's field side.
/// The route always breaks in the same direction (e.g., 3 always breaks left, 4 always breaks right).
struct AbsoluteDirectionRouteSemantics: RouteSemanticProvider {
    let meaning: RouteMeaning

    func meaning(on side: FieldSide) -> RouteMeaning {
        return meaning // Same meaning, all sides
    }
}

/// Bubble/screen route: receiver steps back behind line of scrimmage.
/// Same meaning both sides; defines a backward/lateral direction.
struct BubbleRouteSemantics: RouteSemanticProvider {
    let meaning: RouteMeaning

    func meaning(on side: FieldSide) -> RouteMeaning {
        return meaning // Screen routes are not side-dependent
    }
}
