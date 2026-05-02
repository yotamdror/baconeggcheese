import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLLocationDirection?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        if let current = location, current.distance(from: newLocation) < 200 { return }
        location = newLocation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    // Ray-casting polygon check against a simplified Manhattan outline.
    static func isInManhattan(_ location: CLLocation) -> Bool {
        let px = location.coordinate.longitude
        let py = location.coordinate.latitude
        // ~11 vertices tracing Manhattan clockwise from the southern tip
        let poly: [(x: Double, y: Double)] = [
            (-74.0200, 40.7000), // SW Battery Park
            (-73.9710, 40.7000), // SE near Brooklyn Bridge
            (-73.9710, 40.7550), // Midtown East / FDR ~50th
            (-73.9450, 40.7800), // UES ~86th
            (-73.9190, 40.8070), // East Harlem ~125th
            (-73.9140, 40.8700), // NE Inwood
            (-73.9350, 40.8820), // Northern tip
            (-73.9650, 40.8820), // NW top
            (-73.9650, 40.8060), // W Harlem ~125th
            (-74.0050, 40.7680), // W Midtown ~59th / Hudson Yards
            (-74.0200, 40.7260), // SW near Holland Tunnel
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
}
