import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DebugTestView: View {
    @StateObject private var firestore = FirestoreManager()
    @State private var userId: String = ""
    @State private var playerName: String = ""
    @State private var currentCoins: Int = 0
    @State private var gameId: String = ""
    @State private var einsatz: Int = 20
    @State private var einsatzBezahlt: Bool = false
    @State private var logMessages: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("🛠 Debug: Einsatz- & Rematch-Test").bold()

            Text("Spieler: \(playerName)")
            Text("Coins: \(currentCoins)")
            Text("Game-ID: \(gameId)")
            Text("Einsatz: \(einsatz) Münzen")
            Text("EinsatzBezahlt: \(einsatzBezahlt ? "✅ Ja" : "❌ Nein")")

            Button("1️⃣ Testspiel starten") {
                createTestGame()
            }
            .buttonStyle(.borderedProminent)

            Button("🚀 Spiel starten") {
                //firestore.startGame()
                log("Spielstart manuell ausgelöst")
            }
            .disabled(gameId.isEmpty)

            Button("♻️ Rematch vorbereiten") {
                resetGameForRematch()
            }
            .disabled(gameId.isEmpty)

            Button("🔄 Coins neu laden") {
                fetchUserCoins()
                fetchGameStatus()
            }

            Divider()
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(logMessages.reversed(), id: \.self) { msg in
                        Text("• \(msg)").font(.caption)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            setupUser()
        }
    }

    func log(_ message: String) {
        logMessages.append("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))] \(message)")
    }

    func setupUser() {
        if let uid = Auth.auth().currentUser?.uid {
            self.userId = uid
            let db = Firestore.firestore()
            db.collection("users").document(uid).getDocument { snapshot, _ in
                let data = snapshot?.data()
                self.playerName = data?["username"] as? String ?? "Unbekannt"
                self.currentCoins = data?["coins"] as? Int ?? 0
            }
        }
    }

    func fetchUserCoins() {
        Firestore.firestore().collection("users").document(userId).getDocument { snapshot, _ in
            if let coins = snapshot?.data()?["coins"] as? Int {
                self.currentCoins = coins
                log("📥 Coins neu geladen: \(coins)")
            }
        }
    }

    func fetchGameStatus() {
        guard !gameId.isEmpty else { return }
        Firestore.firestore().collection("games").document(gameId).getDocument { snapshot, _ in
            if let data = snapshot?.data() {
                self.einsatzBezahlt = data["einsatzBezahlt"] as? Bool ?? false
                log("📦 EinsatzBezahlt = \(self.einsatzBezahlt)")
            }
        }
    }

    func createTestGame() {
        let gameCode = "TEST\(Int.random(in: 100...999))"
        let game = GameSession(
            id: gameCode,
            players: [playerName],
            currentTurn: 0,
            dice: [],
            isFinished: false,
            createdAt: Date(),
            started: false,
            extraModus: false,
            host: playerName,
            modus: "standard",
            einsatzCoins: einsatz,
            ready: [:],
            coinDistribution: [:],
            scoreBonuses: [:],
            einsatzBezahlt: false
        )

        do {
            try Firestore.firestore().collection("games").document(gameCode).setData(from: game)
            firestore.listenToGame(id: gameCode)
            self.gameId = gameCode
            log("✅ Testspiel erstellt: \(gameCode)")
        } catch {
            log("❌ Fehler beim Erstellen: \(error.localizedDescription)")
        }
    }

    func resetGameForRematch() {
        guard !gameId.isEmpty else { return }

        let ref = Firestore.firestore().collection("games").document(gameId)
        ref.collection("rounds").getDocuments { snapshot, _ in
            for doc in snapshot?.documents ?? [] {
                doc.reference.delete()
            }
            log("🗑 Alte Runden gelöscht")

            ref.updateData([
                "rematchReady": FieldValue.delete(),
                "gameOver": false,
                "winner": FieldValue.delete(),
                "winnerScore": FieldValue.delete(),
                "activePlayer": playerName,
                "coinDistribution": FieldValue.delete(),
                "scoreBonuses": FieldValue.delete(),
                "einsatzBezahlt": false
            ]) { error in
                if let error = error {
                    log("❌ Fehler beim Rematch-Reset: \(error.localizedDescription)")
                } else {
                    log("✅ Rematch-Reset abgeschlossen")
                    fetchGameStatus()
                }
            }
        }
    }
}
