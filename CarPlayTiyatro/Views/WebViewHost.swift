import SwiftUI

/// Paylaşılan WKWebView'i telefon ekranında gösteren kap.
struct WebViewHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        PlayerController.shared.registerPhoneContainer(container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
