import SwiftUI
import FirebaseFirestore

struct ContentViewWrapper: View {
    @State private var isLoggedIn = false
    @State private var needsUsernameSetup = false
    @State private var uid: String?
    @State private var showSplash = true
    @State private var currentUsername: String?

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                Group {
                    if !isLoggedIn {
                        LoginView(isLoggedIn: Binding(
                            get: { self.isLoggedIn },
                            set: { newValue in
                                self.isLoggedIn = newValue
                                if newValue {
                                    self.checkLoginAndUsername()
                                }
                            }
                        ))
                    } else if needsUsernameSetup, let uid = uid {
                        UsernameSetupView(uid: uid) {
                            self.needsUsernameSetup = false
                            self.fetchUsername()
                        }
                    } else {
                        ContentView()
                    }
                }
                .onAppear {
                    checkLoginAndUsername()
                }
            }
        }
    }

    func checkLoginAndUsername() {
        guard let storedUid = UserDefaults.standard.string(forKey: "userIdentifier") else {
            self.isLoggedIn = false
            return
        }

        self.isLoggedIn = true
        self.uid = storedUid

        let userDoc = Firestore.firestore().collection("users").document(storedUid)
        userDoc.getDocument { docSnapshot, error in
            if let error = error {
                print("❌ Fehler beim Lesen des User-Dokuments: \(error.localizedDescription)")
                self.needsUsernameSetup = true
                return
            }

            guard let doc = docSnapshot, doc.exists, let data = doc.data() else {
                self.needsUsernameSetup = true
                return
            }

            if let name = data["username"] as? String,
               !name.isEmpty,
               name != "Unbekannt",
               name.count >= 3 {
                self.currentUsername = name
                self.needsUsernameSetup = false
            } else {
                self.needsUsernameSetup = true
            }
        }
    }

    func fetchUsername() {
        guard let uid = uid else { return }

        let userDoc = Firestore.firestore().collection("users").document(uid)
        userDoc.getDocument { snapshot, error in
            if let data = snapshot?.data(), let name = data["username"] as? String {
                self.currentUsername = name
            }
        }
    }
}
