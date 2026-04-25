import Foundation
import CoreLocation

enum Category: String, CaseIterable, Identifiable {
    case pizza, bagel, bec
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .pizza: return "🍕"
        case .bagel: return "🥯"
        case .bec: return "🥓🥚🧀"
        }
    }
}

struct PlacesResponse: Decodable {
    let places: [Place]?
}

struct Place: Decodable, Identifiable {
    let id: String
    let displayName: DisplayName
    let formattedAddress: String?
    let location: Coordinates
    let rating: Double?
    let googleMapsUri: String?
    let currentOpeningHours: Hours?
    let regularOpeningHours: Hours?

    let highlightedReview: Review?

    var name: String { displayName.text }
    var isOpen: Bool {
        currentOpeningHours?.openNow ?? regularOpeningHours?.openNow ?? true
    }

    func walkingMinutes(from user: CLLocation) -> Int {
        let dest = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return max(1, Int((user.distance(from: dest) / 80.0).rounded()))
    }

    struct DisplayName: Decodable { let text: String }
    struct Coordinates: Decodable { let latitude: Double; let longitude: Double }
    struct Hours: Decodable { let openNow: Bool? }
    struct Review: Decodable { let text: String; let author: String }
}
