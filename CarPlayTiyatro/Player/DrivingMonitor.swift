import CoreLocation

/// GPS hızına bakarak aracın hareket edip etmediğini bildirir.
final class DrivingMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = DrivingMonitor()

    /// Bu hızın (m/s) üstünde araç hareket ediyor sayılır (~9 km/s).
    private let movingThreshold: CLLocationSpeed = 2.5
    /// Bu hızın altına inince tekrar durmuş sayılır (~3 km/s).
    private let stoppedThreshold: CLLocationSpeed = 0.8

    var onChange: ((Bool) -> Void)?
    private(set) var isMoving = false

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // İzin yoksa güvenli tarafta kal: hareket ediyor varsay.
            update(moving: true)
        default:
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        update(moving: false)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            update(moving: true)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let speed = locations.last?.speed, speed >= 0 else { return }
        if isMoving {
            if speed < stoppedThreshold { update(moving: false) }
        } else {
            if speed > movingThreshold { update(moving: true) }
        }
    }

    private func update(moving: Bool) {
        guard moving != isMoving else { return }
        isMoving = moving
        onChange?(moving)
    }
}
