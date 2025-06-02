import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var currentNonce: String?
    @State private var isLoading = false  // ➔ neuer State

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Text("🎲 Willkommen bei Kniraffel 🦒")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    },
                    onCompletion: { result in
                        isLoading = true  // ➔ Start Loading
                        switch result {
                        case .success(let authResults):
                            handleAuth(authResults) {
                                DispatchQueue.main.async {
                                    isLoggedIn = true
                                    isLoading = false  // ➔ Stop Loading (optional, falls Übergang verzögert)
                                }
                            }
                        case .failure(let error):
                            print("❌ Authorization failed: \(error.localizedDescription)")
                            isLoading = false  // ➔ Stop Loading
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding()

                Spacer()
            }

            if isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                LoadingView()
            }
        }
    }


    
    func handleAuth(_ authResults: ASAuthorization, completion: @escaping () -> Void = {}) {
        guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Kein gültiges Apple-Credential.")
            return
        }
        guard let nonce = currentNonce else {
            print("❌ Kein Nonce vorhanden.")
            return
        }
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            print("❌ Konnte Identity Token nicht lesen.")
            return
        }

        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: tokenString, rawNonce: nonce)

        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                print("❌ Firebase Auth Fehler: \(error.localizedDescription)")
                return
            }

            guard let firebaseUser = authResult?.user else {
                print("❌ Kein Firebase-User gefunden.")
                return
            }

            let userIdentifier = firebaseUser.uid
            UserDefaults.standard.set(userIdentifier, forKey: "userIdentifier")

            var userData: [String: Any] = [
                "lastLogin": Timestamp()
            ]

            // 🚫 Sicherstellen, dass weder Name noch E-Mail lokal noch in Firestore gespeichert werden
            UserDefaults.standard.removeObject(forKey: "fullName")
            UserDefaults.standard.removeObject(forKey: "email")

            print("✅ Firebase User ID: \(userIdentifier)")
            print("✅ Gespeicherte User-Daten (ohne Name/E-Mail): \(userData)")

            saveUserToFirestore(userId: userIdentifier, userData: userData) {
                print("✅ User-Daten erfolgreich in Firestore gespeichert")

                let db = Firestore.firestore()
                db.collection("users").document(userIdentifier).getDocument { snapshot, error in
                    if let data = snapshot?.data(), let username = data["username"] as? String {
                        UserDefaults.standard.set(username, forKey: "playerName")
                        print("✅ Username lokal gespeichert: \(username)")
                    } else {
                        print("⚠️ Kein Username gefunden oder Fehler: \(error?.localizedDescription ?? "Unbekannt")")
                    }
                    completion()
                }
            }
        }
    }


   
  

    /**
    func saveUserToFirestore(userId: String, userData: [String: Any], completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("❌ Fehler beim Schreiben: \(error.localizedDescription)")
            } else {
                print("✅ Firestore-Dokument aktualisiert (oder neu angelegt).")
            }
            completion()
        }
    }
     */
    func saveUserToFirestore(userId: String, userData: [String: Any], completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            if let snapshot = snapshot, !snapshot.exists {
                // Erstelle neuen Nutzer mit Startmünzen
                var initialData = userData
                initialData["coins"] = 0  // Startwert festlegen
                initialData["username"] = UserDefaults.standard.string(forKey: "playerName") ?? "Unbekannt"
                initialData["purchasedSkins"] = []  // Start: keine Skins gekauft
                    initialData["selectedSkin"] = "skin_classic"  // Standard-Skin
                userRef.setData(initialData, merge: true) { error in
                    if let error = error {
                        print("❌ Fehler beim Anlegen: \(error.localizedDescription)")
                    } else {
                        print("✅ Neuer Nutzer mit 100 Münzen angelegt.")
                    }
                    completion()
                }
            } else {
                // User existiert → nur normale Updates
                userRef.setData(userData, merge: true) { error in
                    if let error = error {
                        print("❌ Fehler beim Schreiben: \(error.localizedDescription)")
                    } else {
                        print("✅ Firestore-Dokument aktualisiert (oder neu angelegt).")
                    }
                    completion()
                }
            }
        } //Test kommentar gitHub

    }

    
    
    

    // MARK: - Nonce-Helper

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
