import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationProvider: NSObject {
    var authorization: CLAuthorizationStatus
    var coordinate: CLLocationCoordinate2D?
    var error: String?

    private let manager = CLLocationManager()

    override init() {
        self.authorization = .notDetermined
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.authorization = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    private func apply(authorization: CLAuthorizationStatus) {
        self.authorization = authorization
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    private func apply(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    private func apply(error: String) {
        self.error = error
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.apply(authorization: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.apply(coordinate: coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.apply(error: message)
        }
    }
}
