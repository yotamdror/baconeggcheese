import CoreLocation
import Foundation

/// Fire-and-forget anonymous usage events. No account, device ID, or precise coordinates.
enum UsageEventLogger {
    private static let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/log-usage-event")!

    enum Event: String {
        /// Minimum success: open places shown after client filter.
        case resultLoaded = "result_loaded"
        /// Strong: user opened the detail drawer.
        case drawerOpen = "drawer_open"
        /// Strong: user picked a non-default nearby option.
        case alternateSelected = "alternate_selected"
        /// Best: user tapped through to Maps.
        case navigateTapped = "navigate_tapped"
        /// Acquisition: user shared a result (wire when share-button merges).
        case shareTapped = "share_tapped"
    }

    static func log(
        _ event: Event,
        category: Category,
        location: CLLocation,
        resultCount: Int? = nil
    ) {
        Task {
            struct Body: Encodable {
                let event_type: String
                let category: String
                let latitude: Double
                let longitude: Double
                let result_count: Int?
                let in_manhattan: Bool
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(Body(
                event_type: event.rawValue,
                category: category.rawValue,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                result_count: resultCount,
                in_manhattan: LocationManager.isInManhattan(location)
            ))
            _ = try? await URLSession.shared.data(for: req)
        }
    }
}
