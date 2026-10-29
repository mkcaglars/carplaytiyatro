import SwiftUI
import AVFoundation

@main
struct TiyatroApp: App {
    init() {
        // Sesin araç hoparlörlerinden ve arka planda da çalması için.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
