import SwiftUI
import FirebaseFirestore

struct ModusView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage("extraModus") private var extraModus = false
    @AppStorage("playerName") private var playerName = ""

    @EnvironmentObject var firestore: FirestoreManager

    @State private var einsatzCoins: Int = 0  // Startwert
    @State private var einsatzCheckResult: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(isHost ? "🛠️ Host-Einstellungen" : "ℹ️ Einstellungen (Nur Host kann ändern)")) {
                    Toggle("Erweiterter Modus", isOn: Binding(
                        get: { extraModus },
                        set: { newValue in
                            if isHost {
                                extraModus = newValue
                                firestore.updateModus(to: newValue)
                                if let gameID = firestore.currentGame?.id {
                                    Firestore.firestore().collection("games").document(gameID)
                                        .updateData(["extraModus": newValue])
                                }
                            }
                        }
                    ))

                    if isHost {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💰 Einsatz pro Spieler: \(einsatzCoins) Münzen")
                            Slider(value: Binding(
                                get: { Double(einsatzCoins) },
                                set: { newValue in
                                    einsatzCoins = Int(newValue)
                                    if let gameID = firestore.currentGame?.id {
                                        // Nur Host darf setzen!
                                        if isHost {
                                            Firestore.firestore().collection("games").document(gameID)
                                                .updateData(["einsatzCoins": einsatzCoins])
                                            print("✅ Host hat Einsatz auf \(einsatzCoins) gesetzt")
                                        } else {
                                            print("⚠️ Kein Host, Änderung blockiert")
                                        }
                                    }
                                }
                            ), in: 0...20, step: 1)
                        }
                        .padding(.vertical)
                        
                        Button("✅ Überprüfen, ob alle genug Münzen haben") {
                            firestore.checkIfAllPlayersCanPay(entryFee: einsatzCoins) { success, message in
                                einsatzCheckResult = message
                            }
                        }
                        .padding(.top, 8)
                        
                        if let result = einsatzCheckResult {
                            Text(result)
                                .font(.footnote)
                                .foregroundColor(successColor(from: result))
                        }
                    } else {
                        Text("Nur der Host kann diese Optionen ändern.").font(.footnote).foregroundColor(.gray)
                    }

                }
            }
            .navigationTitle("⚙️ Einstellungen")
            .onAppear {
                if let saved = firestore.currentGame?.einsatzCoins {
                    einsatzCoins = saved
                }
            }
        }
    }

    var isHost: Bool {
        firestore.currentGame?.host == playerName
    }
    
    func successColor(from message: String) -> Color {
        message.contains("✔") ? .green : .red
    }
}
