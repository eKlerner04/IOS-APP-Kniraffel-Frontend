import AVFoundation

class MusicManager {
    static let shared = MusicManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func startBackgroundMusic() {
        guard let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") else {
            print("🎵 Musikdatei nicht gefunden")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Endlosschleife
            audioPlayer?.volume = 0.3       // Lautstärke (optional)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("❌ Fehler beim Abspielen der Hintergrundmusik: \(error.localizedDescription)")
        }
    }

    func stopBackgroundMusic() {
        audioPlayer?.stop()
    }
}
