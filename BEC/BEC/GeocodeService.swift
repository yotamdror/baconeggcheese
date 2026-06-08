import Foundation
import CoreLocation

struct GeocodeResult: Decodable, Identifiable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(latitude),\(longitude)" }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

struct GeocodeService {
    private static let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/geocode-proxy")!

    static func fetch(query: String) async throws -> [GeocodeResult] {
        struct Body: Encodable { let query: String }
        struct Response: Decodable { let results: [GeocodeResult] }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Body(query: query))

        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(Response.self, from: data).results
    }
}
