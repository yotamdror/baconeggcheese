import Foundation
import CoreLocation

struct PlacesService {
    private static let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/places-proxy")!

    static func fetch(category: Category, location: CLLocation) async throws -> [Place] {
        struct Body: Encodable {
            let category: String
            let latitude: Double
            let longitude: Double
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(
            category: category.rawValue,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        ))

        let (data, _) = try await URLSession.shared.data(for: req)
        let response = try JSONDecoder().decode(PlacesResponse.self, from: data)
        return response.places?.filter { $0.isOpen } ?? []
    }
}
