import SwiftUI
import Firebase

@main
struct KnubbelGameApp: App {
    init() {
        FirebaseApp.configure()

        // 🔒 Alte E-Mail- und Name-Daten aus UserDefaults löschen, falls jemals gespeichert
        UserDefaults.standard.removeObject(forKey: "email")
        UserDefaults.standard.removeObject(forKey: "fullName")

        // Hintergrundmusik nur starten, wenn aktiviert
        let soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        if soundEnabled {
            MusicManager.shared.startBackgroundMusic()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentViewWrapper() // 👈 hier statt ContentView()
        }
    }
}
