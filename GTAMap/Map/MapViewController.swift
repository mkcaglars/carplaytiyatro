import Combine
import MapKit
import MapLibre
import UIKit

/// The GTA-style live map. Used as the root view controller of the CarPlay
/// window and embedded in the phone UI.
final class MapViewController: UIViewController {
    private let model = NavigationModel.shared
    private var cancellables = Set<AnyCancellable>()

    private(set) lazy var mapView: MLNMapView = {
        let url = Bundle.main.url(forResource: "gta-style", withExtension: "json")
        let view = MLNMapView(frame: .zero, styleURL: url)
        view.delegate = self
        view.compassView.isHidden = true
        view.logoView.isHidden = true // OSM/OpenFreeMap attribution stays visible via the (i) button.
        view.attributionButton.tintColor = .lightGray
        view.showsUserLocation = false // we draw our own GTA "player blip"
        view.maximumZoomLevel = 19
        return view
    }()

    private let hud = LocationHUDView()
    private var style: MLNStyle?

    /// When true the camera chases the player, tilted, heading-up — like the GTA radar.
    private(set) var isFollowing = true
    private var followAltitude: CLLocationDistance = 600
    private var lastCameraUpdate = Date.distantPast

    private var glowLink: CADisplayLink?
    private var paintTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.086, green: 0.094, blue: 0.106, alpha: 1)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        hud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hud.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            hud.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            hud.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        ])
        bindModel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the player in the lower third so more road ahead is visible.
        mapView.automaticallyAdjustsContentInset = false
        mapView.contentInset = UIEdgeInsets(top: view.bounds.height * 0.35, left: 0, bottom: 0, right: 0)
    }

    // MARK: Public controls (used by CarPlay map buttons and the phone UI)

    func zoomIn() { zoom(by: 0.5) }
    func zoomOut() { zoom(by: 2) }

    func recenter() {
        isFollowing = true
        updateCamera(animated: true)
    }

    func pan(_ direction: UIRectEdge) {
        isFollowing = false
        let step: CGFloat = 140
        var point = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
        if direction.contains(.top) { point.y -= step }
        if direction.contains(.bottom) { point.y += step }
        if direction.contains(.left) { point.x -= step }
        if direction.contains(.right) { point.x += step }
        mapView.setCenter(mapView.convert(point, toCoordinateFrom: mapView), animated: true)
    }

    private func zoom(by factor: Double) {
        followAltitude = min(max(followAltitude * factor, 150), 20_000)
        if isFollowing {
            updateCamera(animated: true)
        } else {
            mapView.setZoomLevel(mapView.zoomLevel + (factor < 1 ? 1 : -1), animated: true)
        }
    }

    // MARK: Model binding

    private func bindModel() {
        Publishers.CombineLatest(model.$location, model.$bearing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updatePlayerBlip()
                self?.updateCamera(animated: true)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(model.$areaName, model.$streetName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] area, street in self?.hud.update(area: area, street: street) }
            .store(in: &cancellables)

        model.$route
            .receive(on: DispatchQueue.main)
            .sink { [weak self] route in self?.showRoute(route) }
            .store(in: &cancellables)

        model.$isNavigating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] navigating in
                guard navigating else { return }
                self?.isFollowing = true
                self?.followAltitude = 600
                self?.updateCamera(animated: true)
            }
            .store(in: &cancellables)
    }

    private func updateCamera(animated: Bool) {
        guard isFollowing, style != nil, let location = model.location else { return }
        let camera = MLNMapCamera(lookingAtCenter: location.coordinate,
                                  altitude: followAltitude,
                                  pitch: 50,
                                  heading: model.bearing)
        // Location arrives about once a second; a linear 1s glide makes the motion continuous.
        let now = Date()
        let duration = animated ? min(now.timeIntervalSince(lastCameraUpdate), 1.0) : 0
        lastCameraUpdate = now
        mapView.setCamera(camera,
                          withDuration: duration,
                          animationTimingFunction: CAMediaTimingFunction(name: .linear))
    }

    private func updatePlayerBlip() {
        guard let source = style?.source(withIdentifier: "player") as? MLNShapeSource,
              let location = model.location else { return }
        let point = MLNPointFeature()
        point.coordinate = location.coordinate
        point.attributes = ["bearing": model.bearing]
        source.shape = point
    }

    // MARK: Route rendering — "paint" the route across the map, then pulse the glow

    private func showRoute(_ route: MKRoute?) {
        paintTimer?.invalidate()
        guard let style,
              let routeSource = style.source(withIdentifier: "route") as? MLNShapeSource,
              let destinationSource = style.source(withIdentifier: "destination") as? MLNShapeSource
        else { return }

        guard let route else {
            routeSource.shape = nil
            destinationSource.shape = nil
            setGlowPulsing(false)
            return
        }

        let coords = route.polyline.coordinates
        if let last = coords.last {
            let point = MLNPointFeature()
            point.coordinate = last
            destinationSource.shape = point
        }
        if !model.isNavigating {
            let bounds = MLNPolyline(coordinates: coords, count: UInt(coords.count)).overlayBounds
            isFollowing = false
            mapView.setVisibleCoordinateBounds(bounds,
                                               edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60),
                                               animated: true,
                                               completionHandler: nil)
        }

        let start = Date()
        let duration: TimeInterval = 1.4
        paintTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            let t = min(Date().timeIntervalSince(start) / duration, 1)
            let eased = 1 - pow(1 - t, 3)
            let count = max(2, Int(Double(coords.count) * eased))
            routeSource.shape = MLNPolylineFeature(coordinates: coords, count: UInt(min(count, coords.count)))
            if t >= 1 {
                timer.invalidate()
                self?.setGlowPulsing(true)
            }
        }
    }

    private func setGlowPulsing(_ on: Bool) {
        glowLink?.invalidate()
        glowLink = nil
        guard on else { return }
        let link = CADisplayLink(target: self, selector: #selector(pulseGlow(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30)
        link.add(to: .main, forMode: .common)
        glowLink = link
    }

    @objc private func pulseGlow(_ link: CADisplayLink) {
        guard let layer = style?.layer(withIdentifier: "route-glow-outer") as? MLNLineStyleLayer else { return }
        let phase = (sin(link.timestamp * 2.4) + 1) / 2 // 0...1
        layer.lineOpacity = NSExpression(forConstantValue: 0.2 + 0.3 * phase)
    }
}

extension MapViewController: MLNMapViewDelegate {
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        self.style = style
        style.setImage(PlayerBlip.image(), forName: "player-arrow")
        updatePlayerBlip()
        showRoute(model.route)
        if let location = model.location {
            mapView.setCenter(location.coordinate, zoomLevel: 16, animated: false)
        }
        updateCamera(animated: false)
    }

    func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
        let gestures: MLNCameraChangeReason = [.gesturePan, .gesturePinch, .gestureRotate, .gestureZoomIn,
                                               .gestureZoomOut, .gestureOneFingerZoom, .gestureTilt]
        if !reason.intersection(gestures).isEmpty {
            isFollowing = false
        }
    }
}
