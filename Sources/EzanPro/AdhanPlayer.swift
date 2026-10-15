import AVFoundation

/// What plays when a prayer time begins. Reminders always use the short system sound (or nothing for `.off`).
enum AdhanSound: String, CaseIterable, Identifiable {
    case clip, full, standard, off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clip: "Ezan – Ausschnitt (26 s)"
        case .full: "Ezan – komplett (1:26 min)"
        case .standard: "Standard-Ton"
        case .off: "Aus"
        }
    }
}

@MainActor
final class AdhanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    func play(_ sound: AdhanSound) {
        let name: String
        switch sound {
        case .clip: name = "Ezan.caf"
        case .full: name = "EzanFull.m4a"
        case .standard, .off: return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        stop()
        player.delegate = self
        player.play()
        self.player = player
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.isPlaying = false
        }
    }
}
