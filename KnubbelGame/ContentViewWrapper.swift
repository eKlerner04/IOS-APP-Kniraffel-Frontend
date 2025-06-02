import SwiftUI
import FirebaseFirestore

struct ContentViewWrapper: View {
    @State private var isLoggedIn = false
    @State private var needsUsernameSetup = false
    @State private var uid: String?
    @State private var showSplash = true

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
                self.needsUsernameSetup = true  // fallback
                return
            }

            if let doc = docSnapshot, doc.exists, let data = doc.data(), data["username"] != nil {
                self.needsUsernameSetup = false
            } else {
                self.needsUsernameSetup = true
            }
        }
    }
}
