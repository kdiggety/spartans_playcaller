import Foundation

/// A fully-resolved route assignment for one receiver.
/// Contains the raw digit, the receiver, their field side, and the interpreted meaning.
struct RouteAssignment: Identifiable {
    let id = UUID()
    let receiver: Receiver
    let routeNumber: RouteNumber
    let side: FieldSide
    let meaning: RouteMeaning

    var label: String {
        "\(receiver.rawValue) (\(routeNumber.rawValue)) — \(meaning.rawValue)"
    }
}
