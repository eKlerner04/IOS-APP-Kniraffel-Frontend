import SwiftUI


struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("buttonSoundEnabled") private var buttonSoundEnabled = true

    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Audio")) {
                    Toggle("🎵 Hintergrundmusik", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { value in
                            if value {
                                MusicManager.shared.startBackgroundMusic()
                            } else {
                                MusicManager.shared.stopBackgroundMusic()
                            }
                        }

                    Toggle("🔘 Button-Sound", isOn: $buttonSoundEnabled)
                }

                Section {
                    Button("🚪 Abmelden") {
                        showLogoutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("⚙️ Einstellungen")
            .alert("Abmelden?", isPresented: $showLogoutAlert) {
                Button("Ja, abmelden", role: .destructive) {
                    logout()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "userIdentifier")
        UserDefaults.standard.removeObject(forKey: "fullName")
        UserDefaults.standard.removeObject(forKey: "email")

        // App neustarten → zurück zum Login-Screen
        if let window = UIApplication.shared.windows.first {
            window.rootViewController = UIHostingController(rootView: ContentViewWrapper())
            window.makeKeyAndVisible()
        }
    }
}
