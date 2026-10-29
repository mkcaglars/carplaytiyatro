import SwiftUI

struct ContentView: View {
    @ObservedObject private var player = PlayerController.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if player.service != nil {
                    ControlBar(player: player)
                }
            }
            .navigationTitle("Tiyatro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Sürüşte sesi sürdür", isOn: $player.allowAudioWhileDriving)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(StreamingService.allCases) { service in
                    Button {
                        player.open(service)
                    } label: {
                        Label(service.title, systemImage: service.symbolName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(player.service == service ? .accentColor : .gray)
                }
            }

            Picker("Ekran", selection: Binding(
                get: { player.target },
                set: { player.setTarget($0) }
            )) {
                Label("Telefon", systemImage: "iphone").tag(PlayerController.DisplayTarget.phone)
                Label("Araç", systemImage: "car.fill").tag(PlayerController.DisplayTarget.car)
            }
            .pickerStyle(.segmented)
            .disabled(!player.isCarConnected)

            if !player.isCarConnected {
                Text("CarPlay bağlı değil")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if player.target == .car {
            CarModeView(player: player)
        } else if player.service == nil {
            ContentUnavailableView(
                "Bir servis seçin",
                systemImage: "tv",
                description: Text("YouTube veya Netflix'i açın, videoyu seçin, ardından \"Araç\" ekranına gönderin.")
            )
        } else {
            WebViewHost()
        }
    }
}

/// Video araç ekranındayken telefonda gösterilen uzaktan kumanda.
private struct CarModeView: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: player.isDrivingLocked ? "car.side.fill" : "tv.and.mediabox")
                .font(.system(size: 64))
            Text(player.isDrivingLocked ? "Araç hareket halinde – video kapalı" : "Video araç ekranında oynatılıyor")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Videoyu seçmek veya aramak için ekranı \"Telefon\" olarak değiştirin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct ControlBar: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        HStack {
            button("chevron.backward") { player.goBack() }
            button("gobackward.10") { player.seek(by: -10) }
            button(player.isPlaying ? "pause.fill" : "play.fill") { player.togglePlay() }
            button("goforward.10") { player.seek(by: 10) }
            button(player.isCinemaMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                player.toggleCinemaMode()
            }
            button("house") { player.goHome() }
        }
        .font(.title2)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func button(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
