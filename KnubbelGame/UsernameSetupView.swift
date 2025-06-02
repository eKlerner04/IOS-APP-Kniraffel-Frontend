import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct UsernameSetupView: View {
    @State private var username: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading = false
    
    let uid: String
    let onComplete: () -> Void  // Callback, wenn fertig
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Wähle deinen Username")
                .font(.title)
                .padding(.top)
            
            TextField("Username", text: $username)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Button(action: checkAndSaveUsername) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Bestätigen")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading)
            
            Spacer()
        }
        .padding()
    }
    
    func checkAndSaveUsername() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Bitte gib einen Username ein."
            return
        }
        
        guard trimmedUsername.count >= 3 else {
            errorMessage = "Der Username muss mindestens 3 Zeichen haben."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let usersRef = Firestore.firestore().collection("users")
        
        usersRef.whereField("username", isEqualTo: trimmedUsername).getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Fehler beim Überprüfen: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if let docs = snapshot?.documents, !docs.isEmpty {
                DispatchQueue.main.async {
                    self.errorMessage = "Dieser Username ist bereits vergeben."
                    self.isLoading = false
                }
            } else {
                usersRef.document(uid).setData([
                    "username": trimmedUsername,
                    "updatedAt": Timestamp()
                ], merge: true) { error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error = error {
                            self.errorMessage = "Speicherfehler: \(error.localizedDescription)"
                        } else {
                            self.onComplete()
                        }
                    }
                }
            }
        }
    }
}
