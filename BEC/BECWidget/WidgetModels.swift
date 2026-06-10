import SwiftUI
import CoreLocation
import Foundation

// MARK: - App Group

let widgetAppGroupID = "group.com.dror.BEC"

// MARK: - Category

enum WidgetCategory: String, CaseIterable {
    case bec, bagel, pizza

    var iconName: String {
        switch self {
        case .bec:   return "bec-icon"
        case .bagel: return "bagel-icon"
        case .pizza: return "pizza-icon"
        }
    }

    var accentColor: Color {
        switch self {
        case .bec:   return Color(red: 0,       green: 102/255, blue: 178/255)
        case .bagel: return .white
        case .pizza: return Color(red: 255/255, green: 102/255, blue: 0)
        }
    }

    var onAccentColor: Color {
        switch self {
        case .bec, .pizza: return .white
        case .bagel:       return .black
        }
    }

    var next: WidgetCategory {
        let all = WidgetCategory.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var previous: WidgetCategory {
        let all = WidgetCategory.allCases
        return all[(all.firstIndex(of: self)! + all.count - 1) % all.count]
    }
}

// MARK: - Place

struct WidgetPlace: Codable {
    let id: String
    let displayName: DisplayName
    let location: Coordinates
    let currentOpeningHours: Hours?
    let regularOpeningHours: Hours?

    var name: String { displayName.text }
    var isOpen: Bool { currentOpeningHours?.openNow ?? regularOpeningHours?.openNow ?? true }

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
        if widgetIsInManhattan(user) {
            let g = (b - 29 + 360).truncatingRemainder(dividingBy: 360)
            switch g {
            case 315..<360, 0..<45: return "uptown"
            case 45..<135:          return "crosstown"
            case 135..<225:         return "downtown"
            default:                return "crosstown"
            }
        }
        switch b {
        case 22.5..<67.5:   return "northeast"
        case 67.5..<112.5:  return "east"
        case 112.5..<157.5: return "southeast"
        case 157.5..<202.5: return "south"
        case 202.5..<247.5: return "southwest"
        case 247.5..<292.5: return "west"
        case 292.5..<337.5: return "northwest"
        default:            return "north"
        }
    }

    struct DisplayName: Codable { let text: String }
    struct Coordinates: Codable { let latitude: Double; let longitude: Double }
    struct Hours: Codable { let openNow: Bool? }
}

struct WidgetPlacesResponse: Decodable {
    let places: [WidgetPlace]?
}

// MARK: - Manhattan detection (copied from LocationManager.swift)

func widgetIsInManhattan(_ location: CLLocation) -> Bool {
    let px = location.coordinate.longitude
    let py = location.coordinate.latitude
    let poly: [(x: Double, y: Double)] = [
        (-74.0200, 40.7000), (-74.0060, 40.7020), (-73.9975, 40.7065),
        (-73.9720, 40.7280), (-73.9710, 40.7550), (-73.9450, 40.7800),
        (-73.9190, 40.8070), (-73.9140, 40.8700), (-73.9350, 40.8820),
        (-73.9650, 40.8820), (-73.9650, 40.8060), (-74.0050, 40.7680),
        (-74.0200, 40.7260),
    ]
    var inside = false
    var j = poly.count - 1
    for i in 0..<poly.count {
        let xi = poly[i].x, yi = poly[i].y
        let xj = poly[j].x, yj = poly[j].y
        if (yi > py) != (yj > py), px < (xj - xi) * (py - yi) / (yj - yi) + xi {
            inside = !inside
        }
        j = i
    }
    return inside
}

// MARK: - Places service

struct WidgetPlacesService {
    private static let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/places-proxy")!

    static func fetch(category: WidgetCategory, location: CLLocation) async throws -> [WidgetPlace] {
        struct Body: Encodable { let category: String; let latitude: Double; let longitude: Double }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(
            category: category.rawValue,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        ))
        let (data, _) = try await URLSession.shared.data(for: req)
        let response = try JSONDecoder().decode(WidgetPlacesResponse.self, from: data)
        return response.places?.filter { $0.isOpen } ?? []
    }
}

// MARK: - App Group cache helpers

func loadCachedPlace(category: WidgetCategory) -> WidgetPlace? {
    guard let data = UserDefaults(suiteName: widgetAppGroupID)?.data(forKey: "widgetResult_\(category.rawValue)"),
          let place = try? JSONDecoder().decode(WidgetPlace.self, from: data) else { return nil }
    return place
}

func saveCachedPlace(_ place: WidgetPlace, category: WidgetCategory) {
    guard let data = try? JSONEncoder().encode(place) else { return }
    let defaults = UserDefaults(suiteName: widgetAppGroupID)
    defaults?.set(data, forKey: "widgetResult_\(category.rawValue)")
    defaults?.set(Date(), forKey: "widgetUpdated_\(category.rawValue)")
}

func loadLastUpdated(category: WidgetCategory) -> Date? {
    UserDefaults(suiteName: widgetAppGroupID)?.object(forKey: "widgetUpdated_\(category.rawValue)") as? Date
}

func loadStoredLocation() -> CLLocation? {
    let defaults = UserDefaults(suiteName: widgetAppGroupID)
    guard let lat = defaults?.object(forKey: "widgetLastLatitude") as? Double,
          let lng = defaults?.object(forKey: "widgetLastLongitude") as? Double else { return nil }
    return CLLocation(latitude: lat, longitude: lng)
}

func loadCurrentCategory() -> WidgetCategory {
    let raw = UserDefaults(suiteName: widgetAppGroupID)?.string(forKey: "widgetCategory") ?? "bec"
    return WidgetCategory(rawValue: raw) ?? .bec
}

// MARK: - Arrow view

struct WidgetArrowView: View {
    let bearing: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let cx = sz.width / 2
            var shaft = Path()
            shaft.move(to: CGPoint(x: cx, y: sz.height * 0.89))
            shaft.addLine(to: CGPoint(x: cx, y: sz.height * 0.22))
            ctx.stroke(shaft, with: .color(color),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
            var head = Path()
            head.move(to:    CGPoint(x: sz.width * 0.27, y: sz.height * 0.47))
            head.addLine(to: CGPoint(x: cx,               y: sz.height * 0.19))
            head.addLine(to: CGPoint(x: sz.width * 0.73, y: sz.height * 0.47))
            ctx.stroke(head, with: .color(color),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(bearing))
    }
}

// MARK: - Relative time

func relativeTimeString(from date: Date) -> String {
    let mins = Int(Date().timeIntervalSince(date) / 60)
    switch mins {
    case 0:       return "just now"
    case 1:       return "1 min ago"
    case 2..<60:  return "\(mins) min ago"
    default:      return "\(mins / 60)h ago"
    }
}
