import Combine
import CoreLocation
import MapKit

/// Progress along the active route.
struct RouteProgress: Equatable {
    var stepIndex: Int
    var distanceToStepEnd: CLLocationDistance
    var remainingDistance: CLLocationDistance
    var remainingTime: TimeInterval
}

/// Shared state for the phone and CarPlay scenes: live location, heading,
/// the GTA-style "area name", and the active route.
final class NavigationModel: NSObject, ObservableObject {
    static let shared = NavigationModel()

    @Published private(set) var location: CLLocation?
    /// Direction of travel in degrees (course while moving, compass when stopped).
    @Published private(set) var bearing: CLLocationDirection = 0
    @Published private(set) var areaName = ""
    @Published private(set) var streetName = ""

    @Published private(set) var route: MKRoute?
    @Published private(set) var destination: MKMapItem?
    @Published private(set) var isNavigating = false
    @Published private(set) var progress: RouteProgress?
    /// Fires once when the destination is reached.
    let arrived = PassthroughSubject<Void, Never>()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?
    private var started = false

    private static let arrivalRadius: CLLocationDistance = 30
    private static let geocodeInterval: CLLocationDistance = 120

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.headingFilter = 2
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true // keeps CarPlay live with the phone locked
    }

    func start() {
        guard !started else { return }
        started = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    // MARK: Routing (Apple MapKit directions — free, on-device API)

    func calculateRoute(to item: MKMapItem) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = item
        request.transportType = .automobile
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { throw MKError(.directionsNotFound) }
        return route
    }

    /// Shows the route on the map without starting guidance.
    func preview(_ route: MKRoute, to destination: MKMapItem) {
        self.route = route
        self.destination = destination
        isNavigating = false
        progress = nil
    }

    func startNavigation() {
        guard let route else { return }
        isNavigating = true
        // MapKit's first step is usually a zero-length "start" step.
        let first = route.steps.first.map { $0.distance == 0 } == true ? 1 : 0
        updateProgress(startingAt: min(first, route.steps.count - 1))
    }

    func endNavigation() {
        isNavigating = false
        route = nil
        destination = nil
        progress = nil
    }

    private func updateProgress(startingAt index: Int? = nil) {
        guard isNavigating, let route, let location, !route.steps.isEmpty else { return }
        var stepIndex = index ?? progress?.stepIndex ?? 0
        var toStepEnd = location.distance(from: route.steps[stepIndex].endLocation)

        // Advance past every step whose end point we've reached.
        while toStepEnd < Self.arrivalRadius, stepIndex < route.steps.count - 1 {
            stepIndex += 1
            toStepEnd = location.distance(from: route.steps[stepIndex].endLocation)
        }

        if stepIndex == route.steps.count - 1, toStepEnd < Self.arrivalRadius {
            arrived.send()
            endNavigation()
            return
        }

        let later = route.steps[(stepIndex + 1)...].reduce(0) { $0 + $1.distance }
        let remaining = toStepEnd + later
        let remainingTime = route.distance > 0 ? route.expectedTravelTime * remaining / route.distance : 0
        progress = RouteProgress(stepIndex: stepIndex,
                                 distanceToStepEnd: toStepEnd,
                                 remainingDistance: remaining,
                                 remainingTime: remainingTime)
    }

    // MARK: GTA-style location banner

    private func reverseGeocodeIfNeeded(_ location: CLLocation) {
        if let last = lastGeocodedLocation, last.distance(from: location) < Self.geocodeInterval { return }
        guard !geocoder.isGeocoding else { return }
        lastGeocodedLocation = location
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let mark = placemarks?.first else { return }
            self.areaName = mark.subLocality ?? mark.locality ?? mark.administrativeArea ?? ""
            self.streetName = mark.thoroughfare ?? ""
        }
    }
}

extension NavigationModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0 else { return }
        location = latest
        if latest.course >= 0, latest.speed > 1.5 {
            bearing = latest.course
        }
        reverseGeocodeIfNeeded(latest)
        updateProgress()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use the compass only when standing still; course is steadier while driving.
        guard (location?.speed ?? 0) <= 1.5, newHeading.headingAccuracy >= 0 else { return }
        bearing = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

extension MKRoute.Step {
    var endLocation: CLLocation {
        let count = polyline.pointCount
        guard count > 0 else { return CLLocation(latitude: 0, longitude: 0) }
        let coordinate = polyline.points()[count - 1].coordinate
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
