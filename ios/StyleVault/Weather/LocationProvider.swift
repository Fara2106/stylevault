import CoreLocation
import MapKit

/// Posizione da passare al sito (svNative.setLocation).
struct PlacePayload: Encodable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String
}

/// Una posizione approssimativa alla volta, solo "mentre usi l'app": per il
/// meteo basta la città. Permesso negato o errore → nil, e il sito resta sulla
/// città predefinita.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationWaiter: CheckedContinuation<Void, Never>?
    private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func currentPlace() async -> PlacePayload? {
        if manager.authorizationStatus == .notDetermined, authorizationWaiter == nil {
            await withCheckedContinuation { waiter in
                authorizationWaiter = waiter
                manager.requestWhenInUseAuthorization()
            }
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        // Richieste che arrivano insieme aspettano la stessa risposta
        let location: CLLocation? = await withCheckedContinuation { waiter in
            locationWaiters.append(waiter)
            if locationWaiters.count == 1 { manager.requestLocation() }
        }
        guard let location else { return nil }
        let name = await Self.placeName(for: location) ?? "La mia posizione"
        return PlacePayload(latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude, name: name)
    }

    /// Il nome della città dal telefono (niente servizi esterni).
    private static func placeName(for location: CLLocation) async -> String? {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first else { return nil }
            return item.addressRepresentations?.cityName ?? item.name
        } else {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            return placemark?.locality ?? placemark?.name
        }
    }

    private func finish(_ location: CLLocation?) {
        let waiters = locationWaiters
        locationWaiters = []
        waiters.forEach { $0.resume(returning: location) }
    }

    // Il manager è creato sul main thread: le risposte arrivano lì
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard manager.authorizationStatus != .notDetermined, let waiter = authorizationWaiter else { return }
            authorizationWaiter = nil
            waiter.resume()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { finish(locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}
