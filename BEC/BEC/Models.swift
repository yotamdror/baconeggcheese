import Foundation
import CoreLocation

enum Category: String, CaseIterable, Identifiable {
    case pizza, bagel, bec
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .pizza: return "🍕"
        case .bagel: return "🥯"
        case .bec:   return "🥓"
        }
    }

    var label: String {
        switch self {
        case .pizza: return "PIZZA"
        case .bagel: return "BAGEL"
        case .bec:   return "BEC"
        }
    }

    var loadingText: String {
        switch self {
        case .pizza: return "triangulating nearest cheese situation…"
        case .bagel: return "locating acceptable schmear within striking distance…"
        case .bec:   return "sniffing out the nearest egg situation…"
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
    let hoursLabel: String?
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

    func bearing(from user: CLLocation) -> Double {
        let lat1 = user.coordinate.latitude  * .pi / 180
        let lat2 = location.latitude          * .pi / 180
        let dLon = (location.longitude - user.coordinate.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    func cardinalDirection(from user: CLLocation) -> String {
        let b = bearing(from: user)
        if LocationManager.isInManhattan(user) {
            // Rotate by 30° to align true north with Manhattan's street grid
            // (avenues run ~NNW, so uptown ≈ true bearing 330°; +30° maps that to 0°)
            let g = (b + 30).truncatingRemainder(dividingBy: 360)
            switch g {
            case 315..<360, 0..<45: return "uptown"
            case 45..<135:          return "crosstown"
            case 135..<225:         return "downtown"
            default:                return "crosstown"
            }
        }
        switch b {
        case 22.5..<67.5:   return "NE"
        case 67.5..<112.5:  return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default:            return "N"
        }
    }

    struct DisplayName: Decodable { let text: String }
    struct Coordinates: Decodable { let latitude: Double; let longitude: Double }
    struct Hours: Decodable { let openNow: Bool? }
    struct Review: Decodable { let text: String; let author: String }
}
