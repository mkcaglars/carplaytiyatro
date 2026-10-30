import CarPlay
import Combine
import MapKit

/// CarPlay navigation scene: the GTA map fills the car screen, CarPlay templates
/// provide search, trip preview and turn-by-turn guidance on top.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private let model = NavigationModel.shared
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private let mapViewController = MapViewController()
    private let mapTemplate = CPMapTemplate()
    private var searchHandler: CarPlaySearchHandler?
    private var navigationSession: CPNavigationSession?
    private var activeTrip: CPTrip?
    private var cancellables = Set<AnyCancellable>()

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController,
                                  to window: CPWindow) {
        self.interfaceController = interfaceController
        carWindow = window
        window.rootViewController = mapViewController

        mapTemplate.mapDelegate = self
        mapTemplate.guidanceBackgroundColor = .black
        mapTemplate.tripEstimateStyle = .dark
        configureMapButtons()
        configureBarButtons()
        interfaceController.setRootTemplate(mapTemplate, animated: false, completion: nil)

        model.start()
        bindModel()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        navigationSession?.cancelTrip()
        navigationSession = nil
        cancellables.removeAll()
        self.interfaceController = nil
        carWindow = nil
    }

    // MARK: Buttons

    private func configureMapButtons() {
        let zoomIn = CPMapButton { [weak self] _ in self?.mapViewController.zoomIn() }
        zoomIn.image = UIImage(systemName: "plus.magnifyingglass")
        let zoomOut = CPMapButton { [weak self] _ in self?.mapViewController.zoomOut() }
        zoomOut.image = UIImage(systemName: "minus.magnifyingglass")
        let recenter = CPMapButton { [weak self] _ in self?.mapViewController.recenter() }
        recenter.image = UIImage(systemName: "location.north.line.fill")
        let pan = CPMapButton { [weak self] _ in self?.mapTemplate.showPanningInterface(animated: true) }
        pan.image = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        mapTemplate.mapButtons = [zoomIn, zoomOut, recenter, pan]
    }

    private func configureBarButtons() {
        if model.isNavigating {
            let end = CPBarButton(title: "End") { [weak self] _ in self?.endTrip() }
            mapTemplate.leadingNavigationBarButtons = []
            mapTemplate.trailingNavigationBarButtons = [end]
        } else if model.route != nil {
            let cancel = CPBarButton(title: "Cancel") { [weak self] _ in self?.endTrip() }
            mapTemplate.leadingNavigationBarButtons = []
            mapTemplate.trailingNavigationBarButtons = [cancel]
        } else {
            let search = CPBarButton(image: UIImage(systemName: "magnifyingglass")!) { [weak self] _ in
                self?.showSearch()
            }
            mapTemplate.leadingNavigationBarButtons = [search]
            mapTemplate.trailingNavigationBarButtons = []
        }
    }

    // MARK: Search → trip preview

    private func showSearch() {
        let handler = CarPlaySearchHandler(region: model.location.map {
            MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }) { [weak self] item in
            await self?.previewTrip(to: item)
        }
        searchHandler = handler
        let template = CPSearchTemplate()
        template.delegate = handler
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    @MainActor
    private func previewTrip(to destination: MKMapItem) async {
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        do {
            let route = try await model.calculateRoute(to: destination)
            model.preview(route, to: destination)

            let minutes = Int((route.expectedTravelTime / 60).rounded())
            let km = Measurement(value: route.distance, unit: UnitLength.meters)
            let distance = MeasurementFormatter.trip.string(from: km)
            let choice = CPRouteChoice(summaryVariants: [route.name.isEmpty ? "Fastest route" : "via \(route.name)"],
                                       additionalInformationVariants: ["\(minutes) min · \(distance)"],
                                       selectionSummaryVariants: [])
            let trip = CPTrip(origin: .forCurrentLocation(), destination: destination, routeChoices: [choice])
            activeTrip = trip
            let text = CPTripPreviewTextConfiguration(startButtonTitle: "Drive",
                                                      additionalRoutesButtonTitle: nil,
                                                      overviewButtonTitle: nil)
            mapTemplate.showTripPreviews([trip], textConfiguration: text)
            mapTemplate.updateEstimates(CPTravelEstimates(distanceRemaining: km,
                                                          timeRemaining: route.expectedTravelTime),
                                        for: trip)
        } catch {
            let alert = CPAlertTemplate(titleVariants: ["No route found"],
                                        actions: [CPAlertAction(title: "OK", style: .cancel) { [weak self] _ in
                                            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                                        }])
            interfaceController?.presentTemplate(alert, animated: true, completion: nil)
        }
    }

    private func endTrip() {
        mapTemplate.hideTripPreviews()
        navigationSession?.cancelTrip()
        navigationSession = nil
        activeTrip = nil
        model.endNavigation()
    }

    // MARK: Guidance

    private func bindModel() {
        Publishers.CombineLatest(model.$route, model.$isNavigating)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                // Publishers fire before the property is set; read the new values on the next run loop.
                DispatchQueue.main.async { self?.configureBarButtons() }
            }
            .store(in: &cancellables)

        model.$progress
            .compactMap { $0 }
            .removeDuplicates { $0.stepIndex == $1.stepIndex && abs($0.distanceToStepEnd - $1.distanceToStepEnd) < 10 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in self?.updateGuidance(progress) }
            .store(in: &cancellables)

        model.arrived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.navigationSession?.finishTrip()
                self?.navigationSession = nil
                self?.activeTrip = nil
            }
            .store(in: &cancellables)
    }

    private var shownStepIndex: Int?

    private func updateGuidance(_ progress: RouteProgress) {
        guard let session = navigationSession, let route = model.route, let trip = activeTrip else { return }
        let step = route.steps[progress.stepIndex]
        let stepEstimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: progress.distanceToStepEnd, unit: UnitLength.meters),
            timeRemaining: 0)

        if shownStepIndex != progress.stepIndex {
            shownStepIndex = progress.stepIndex
            let maneuver = CPManeuver()
            maneuver.instructionVariants = [step.instructions.isEmpty ? "Continue" : step.instructions]
            maneuver.symbolImage = UIImage(systemName: ManeuverSymbol.name(for: step.instructions))
            maneuver.initialTravelEstimates = stepEstimates
            session.upcomingManeuvers = [maneuver]
        } else if let maneuver = session.upcomingManeuvers.first {
            session.updateEstimates(stepEstimates, for: maneuver)
        }

        mapTemplate.updateEstimates(
            CPTravelEstimates(distanceRemaining: Measurement(value: progress.remainingDistance, unit: UnitLength.meters),
                              timeRemaining: progress.remainingTime),
            for: trip)
    }
}

extension CarPlaySceneDelegate: CPMapTemplateDelegate {
    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        mapTemplate.hideTripPreviews()
        shownStepIndex = nil
        navigationSession = mapTemplate.startNavigationSession(for: trip)
        model.startNavigation()
        mapViewController.recenter()
    }

    func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
        endTrip()
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        var edge: UIRectEdge = []
        if direction.contains(.up) { edge.insert(.top) }
        if direction.contains(.down) { edge.insert(.bottom) }
        if direction.contains(.left) { edge.insert(.left) }
        if direction.contains(.right) { edge.insert(.right) }
        mapViewController.pan(edge)
    }

    func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
        mapViewController.recenter()
    }
}

enum ManeuverSymbol {
    /// Rough SF Symbol for a MapKit instruction string (MapKit gives text, not maneuver types).
    static func name(for instruction: String) -> String {
        let text = instruction.lowercased()
        if text.contains("u-turn") { return "arrow.uturn.down" }
        if text.contains("roundabout") { return "arrow.triangle.turn.up.right.circle" }
        if text.contains("slight left") || text.contains("keep left") { return "arrow.up.left" }
        if text.contains("slight right") || text.contains("keep right") { return "arrow.up.right" }
        if text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("right") { return "arrow.turn.up.right" }
        if text.contains("arrive") || text.contains("destination") { return "flag.checkered" }
        return "arrow.up"
    }
}

extension MeasurementFormatter {
    static let trip: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()
}
