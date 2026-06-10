import AppIntents
import CoreLocation
import WidgetKit

// MARK: - Refresh

struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: widgetAppGroupID)!
        let category = loadCurrentCategory()

        let location = await fetchCurrentLocation(fallback: loadStoredLocation())

        if let loc = location {
            defaults.set(loc.coordinate.latitude,  forKey: "widgetLastLatitude")
            defaults.set(loc.coordinate.longitude, forKey: "widgetLastLongitude")
        }

        if let loc = location,
           let place = try? await WidgetPlacesService.fetch(category: category, location: loc).first {
            saveCachedPlace(place, category: category)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "BECWidget")
        return .result()
    }

    // Gets a GPS fix with a 5s timeout, falls back to stored location
    private func fetchCurrentLocation(fallback: CLLocation?) async -> CLLocation? {
        let task = Task<CLLocation?, Never> {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let loc = update.location { return loc }
                }
            } catch {}
            return nil
        }
        let timeoutTask = Task<CLLocation?, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            task.cancel()
            return nil
        }
        let result = await task.value
        timeoutTask.cancel()
        return result ?? fallback
    }
}

// MARK: - Category cycling

struct NextCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Category"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: widgetAppGroupID)!
        let next = loadCurrentCategory().next
        defaults.set(next.rawValue, forKey: "widgetCategory")
        WidgetCenter.shared.reloadTimelines(ofKind: "BECWidget")
        return .result()
    }
}

struct PrevCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Category"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: widgetAppGroupID)!
        let prev = loadCurrentCategory().previous
        defaults.set(prev.rawValue, forKey: "widgetCategory")
        WidgetCenter.shared.reloadTimelines(ofKind: "BECWidget")
        return .result()
    }
}
