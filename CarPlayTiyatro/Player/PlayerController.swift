import UIKit
import WebKit
import Combine

/// Tek bir WKWebView'i yönetir ve onu telefon ya da CarPlay ekranı arasında taşır.
final class PlayerController: NSObject, ObservableObject {
    static let shared = PlayerController()

    enum DisplayTarget: String {
        case phone
        case car
    }

    @Published private(set) var service: StreamingService?
    @Published private(set) var target: DisplayTarget = .phone
    @Published private(set) var isCarConnected = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isCinemaMode = false
    /// Araç hareket ediyorsa CarPlay ekranında video gösterilmez.
    @Published private(set) var isDrivingLocked = false
    @Published var allowAudioWhileDriving = UserDefaults.standard.bool(forKey: "allowAudioWhileDriving") {
        didSet { UserDefaults.standard.set(allowAudioWhileDriving, forKey: "allowAudioWhileDriving") }
    }

    let webView: WKWebView
    private weak var phoneContainer: UIView?
    private weak var carContainer: UIView?

    private override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        let contentController = configuration.userContentController
        contentController.add(self, name: PlayerScripts.messageName)
        contentController.addUserScript(WKUserScript(
            source: PlayerScripts.bootstrap,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
    }

    // MARK: - Servis

    func open(_ service: StreamingService) {
        self.service = service
        isCinemaMode = false
        webView.customUserAgent = service.userAgent
        webView.load(URLRequest(url: service.homeURL))
    }

    // MARK: - Ekran yönetimi

    func registerPhoneContainer(_ container: UIView) {
        phoneContainer = container
        reattach()
    }

    func carDidConnect(container: UIView) {
        carContainer = container
        isCarConnected = true
        reattach()
    }

    func carDidDisconnect() {
        carContainer = nil
        isCarConnected = false
        isDrivingLocked = false
        target = .phone
        reattach()
    }

    func setTarget(_ newTarget: DisplayTarget) {
        guard newTarget != .car || isCarConnected else { return }
        target = newTarget
        if newTarget == .car && isDrivingLocked && !allowAudioWhileDriving {
            pause()
        }
        // Araç ekranında videonun tamamen görünmesi için sinema modunu otomatik aç.
        setCinemaMode(newTarget == .car)
        reattach()
    }

    func toggleTarget() {
        setTarget(target == .car ? .phone : .car)
    }

    private func reattach() {
        let host = target == .car ? carContainer : phoneContainer
        guard let host else { return }
        guard webView.superview !== host else { return }

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.insertSubview(webView, at: 0)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
    }

    // MARK: - Sürüş kilidi

    func setDrivingLocked(_ locked: Bool) {
        guard locked != isDrivingLocked else { return }
        isDrivingLocked = locked
        if locked && target == .car && !allowAudioWhileDriving {
            pause()
        }
    }

    // MARK: - Oynatma kontrolleri

    func togglePlay() {
        // Araç hareket halindeyken (ve yalnızca ses izni yoksa) araç ekranında oynatmayı başlatma.
        if !isPlaying && isDrivingLocked && target == .car && !allowAudioWhileDriving { return }
        run(PlayerScripts.togglePlay)
    }

    func pause() {
        run(PlayerScripts.pause)
    }

    func seek(by seconds: Double) {
        run(PlayerScripts.seek(by: seconds))
    }

    func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    func goHome() {
        if let service { open(service) }
    }

    func toggleCinemaMode() {
        setCinemaMode(!isCinemaMode)
    }

    private func setCinemaMode(_ enabled: Bool) {
        isCinemaMode = enabled
        run(PlayerScripts.cinema(enabled))
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

extension PlayerController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let state = message.body as? String else { return }
        isPlaying = state == "playing"
    }
}

extension PlayerController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Tam sayfa yüklemelerinde enjekte edilen stil kaybolur; tekrar uygula.
        if isCinemaMode { run(PlayerScripts.cinema(true)) }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isPlaying = false
    }
}
