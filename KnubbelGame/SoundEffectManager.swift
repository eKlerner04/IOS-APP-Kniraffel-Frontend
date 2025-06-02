import AVFoundation

class SoundEffectManager {
    static let shared = SoundEffectManager()
    private var player: AVAudioPlayer?

    private init() {}

    // 🔘 Allgemeiner Button-Sound
    func playButtonSound() {
        let isEnabled = UserDefaults.standard.bool(forKey: "buttonSoundEnabled")
        guard isEnabled else {
            print("🔕 Button-Sound deaktiviert")
            return
        }

        playSound(named: "button_click")
    }

    // 🎲 Würfelwurf-Sound
    func playDiceSound() {
        let isEnabled = UserDefaults.standard.bool(forKey: "buttonSoundEnabled")
        guard isEnabled else {
            print("🎲 Würfel-Sound deaktiviert")
            return
        }

        playSound(named: "dice_rolling")
    }

    // 🔊 Hilfsfunktion zum Abspielen einer Sound-Datei
    private func playSound(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("❌ Sounddatei '\(fileName).mp3' nicht gefunden")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1.0
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("❌ Fehler beim Abspielen von '\(fileName)': \(error.localizedDescription)")
        }
    }
}
