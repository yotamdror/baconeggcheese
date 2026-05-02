import Foundation
import CoreLocation

struct DirectionsResult {
    let durationMinutes: Int
    let blockDescription: String
}

struct DirectionsService {
    private static let url = URL(string: "https://zpstulodssnymskvjuya.supabase.co/functions/v1/directions-proxy")!

    static func fetch(origin: CLLocation, destination: Place) async -> DirectionsResult? {
        struct Body: Encodable {
            let originLat, originLng, destLat, destLng: Double
        }
        struct Response: Decodable {
            let durationMinutes: Int
            let blockDescription: String
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONEncoder().encode(Body(
            originLat: origin.coordinate.latitude,
            originLng: origin.coordinate.longitude,
            destLat: destination.location.latitude,
            destLng: destination.location.longitude
        )) else { return nil }
        req.httpBody = body

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let result = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        return DirectionsResult(
            durationMinutes: result.durationMinutes,
            blockDescription: result.blockDescription
        )
    }
}
