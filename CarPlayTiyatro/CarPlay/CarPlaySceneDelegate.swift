import CarPlay
import Combine

/// CarPlay bağlantısını yönetir. Navigasyon (carplay-maps) yetkisi sayesinde
/// araç ekranına kendi görünümümüzü çizebiliriz; kontroller CPMapTemplate düğmeleridir.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var videoViewController: CarPlayVideoViewController?
    private var playPauseButton: CPMapButton?
    private var targetButton: CPBarButton?
    private var cancellables = Set<AnyCancellable>()

    private let player = PlayerController.shared

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        carWindow = window

        let videoViewController = CarPlayVideoViewController()
        window.rootViewController = videoViewController
        self.videoViewController = videoViewController

        interfaceController.setRootTemplate(makeMapTemplate(), animated: false, completion: nil)

        player.carDidConnect(container: videoViewController.videoContainer)
        observePlayer()

        DrivingMonitor.shared.onChange = { [weak self] moving in
            DispatchQueue.main.async { self?.player.setDrivingLocked(moving) }
        }
        DrivingMonitor.shared.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        DrivingMonitor.shared.onChange = nil
        DrivingMonitor.shared.stop()
        cancellables.removeAll()
        player.carDidDisconnect()
        window.rootViewController = nil
        self.interfaceController = nil
        carWindow = nil
        videoViewController = nil
    }

    // MARK: - Şablon

    private func makeMapTemplate() -> CPMapTemplate {
        let template = CPMapTemplate()
        template.automaticallyHidesNavigationBar = false

        let playPause = mapButton("play.fill") { [weak self] in self?.player.togglePlay() }
        playPauseButton = playPause
        template.mapButtons = [
            mapButton("gobackward.10") { [weak self] in self?.player.seek(by: -10) },
            playPause,
            mapButton("goforward.10") { [weak self] in self?.player.seek(by: 10) },
            mapButton("arrow.up.left.and.arrow.down.right") { [weak self] in self?.player.toggleCinemaMode() }
        ]

        template.leadingNavigationBarButtons = StreamingService.allCases.map { service in
            CPBarButton(title: service.title) { [weak self] _ in
                self?.player.open(service)
                self?.player.setTarget(.car)
            }
        }

        let back = CPBarButton(title: "Geri") { [weak self] _ in self?.player.goBack() }
        let target = CPBarButton(title: "Telefona Al") { [weak self] _ in self?.player.toggleTarget() }
        targetButton = target
        template.trailingNavigationBarButtons = [back, target]

        return template
    }

    private func mapButton(_ symbolName: String, action: @escaping () -> Void) -> CPMapButton {
        let button = CPMapButton { _ in action() }
        button.image = UIImage(systemName: symbolName)
        return button
    }

    // MARK: - Durum takibi

    private func observePlayer() {
        player.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.playPauseButton?.image = UIImage(systemName: playing ? "pause.fill" : "play.fill")
            }
            .store(in: &cancellables)

        player.$isDrivingLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locked in
                self?.videoViewController?.setDrivingLocked(locked)
            }
            .store(in: &cancellables)

        player.$target
            .receive(on: DispatchQueue.main)
            .sink { [weak self] target in
                self?.targetButton?.title = target == .car ? "Telefona Al" : "Araca Al"
            }
            .store(in: &cancellables)
    }
}
