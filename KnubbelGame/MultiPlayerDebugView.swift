import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MultiPlayerDebugView: View {
    @State private var log: [String] = []
    @State private var einsatz: Int = 20
    @State private var playerCount: Int = 2
    @State private var createdPlayers: [String] = []
    @State private var gameId: String = ""
    @State private var isRunning = false
    @State private var showError = false
    @State private var lastError: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("🧪 Multiplayer Debug")
                .font(.title2)
                .bold()

            Stepper("Spieleranzahl: \(playerCount)", value: $playerCount, in: 1...4)
            Stepper("Einsatz: \(einsatz) Münzen", value: $einsatz, in: 0...100)

            Button("🚀 Testlauf starten") {
                Task {
                    await runFullTest()
                }
            }
            .disabled(isRunning)
            .buttonStyle(.borderedProminent)

            if showError {
                Text("⚠️ Fehler: \(lastError)")
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(log.reversed(), id: \ .self) { line in
                        Text("• \(line)").font(.caption).padding(.vertical, 1)
                    }
                }
            }
        }
        .padding()
    }

    func runFullTest() async {
        isRunning = true
        log = []
        showError = false
        lastError = ""

        do {
            try await createTestPlayers()
            try await Task.sleep(nanoseconds: 500_000_000)

            try await createTestGame()
            try await Task.sleep(nanoseconds: 500_000_000)

            try await startGameAndSimulateRounds()
            try await Task.sleep(nanoseconds: 500_000_000)

            try await triggerRematch()
        } catch {
            lastError = error.localizedDescription
            showError = true
            log.append("❌ Test abgebrochen: \(error.localizedDescription)")
        }

        isRunning = false
    }

    func createTestPlayers() async throws {
        createdPlayers = []
        let db = Firestore.firestore()
        for i in 1...playerCount {
            let name = "Testspieler_\(i)"
            createdPlayers.append(name)
            let docRef = db.collection("users").document("test_user_\(i)")
            try await docRef.setData([
                "username": name,
                "coins": 100,
                "playerHistory": [],
                "totalScore_standard": 0,
                "totalScore_erweitert": 0,
                "purchasedSkins": [],
                "selectedSkin": "skin_classic"
            ])
            log.append("✅ Spieler \(name) erstellt mit 100 Coins")
        }
    }

    func createTestGame() async throws {
        let db = Firestore.firestore()
        gameId = "DEBUG_\(Int.random(in: 100...999))"

        let gameData: [String: Any] = [
            "id": gameId,
            "players": createdPlayers,
            "currentTurn": 0,
            "dice": [],
            "isFinished": false,
            "createdAt": Timestamp(date: Date()),
            "started": false,
            "extraModus": false,
            "host": createdPlayers.first ?? "",
            "modus": "standard",
            "einsatzCoins": einsatz,
            "ready": Dictionary(uniqueKeysWithValues: createdPlayers.map { ($0, true) }),
            "einsatzBezahlt": false
        ]

        try await db.collection("games").document(gameId).setData(gameData)
        log.append("🎲 Spiel \(gameId) erstellt mit \(createdPlayers.count) Spielern")
    }

    func startGameAndSimulateRounds() async throws {
        let db = Firestore.firestore()
        let gameRef = db.collection("games").document(gameId)

        for name in createdPlayers {
            let query = db.collection("users").whereField("username", isEqualTo: name)
            let snapshot = try await query.getDocuments()
            guard let doc = snapshot.documents.first else { throw NSError(domain: "Fehlender Spieler", code: 0) }
            let coins = doc["coins"] as? Int ?? 0
            let uid = doc.documentID
            try await db.collection("users").document(uid).updateData([
                "coins": coins - einsatz
            ])
            log.append("💸 \(name): Einsatz \(einsatz) abgezogen")
        }

        try await gameRef.updateData(["started": true, "einsatzBezahlt": true])
        log.append("✅ Spiel gestartet")

        for name in createdPlayers {
            let score = Int.random(in: 150...350)
            let bonus = score >= 300 ? 8 : score >= 250 ? 4 : score >= 200 ? 2 : score >= 150 ? 1 : 0

            let query = db.collection("users").whereField("username", isEqualTo: name)
            let snapshot = try await query.getDocuments()
            guard let doc = snapshot.documents.first else { throw NSError(domain: "Fehlender Spieler", code: 1) }
            let uid = doc.documentID

            try await db.collection("users").document(uid).updateData([
                "totalScore_standard": FieldValue.increment(Int64(score)),
                "playerHistory": FieldValue.arrayUnion([
                    ["score": score, "date": Timestamp(date: Date()), "modus": "standard"]
                ])
            ])

            if bonus > 0 {
                try await db.collection("users").document(uid).updateData([
                    "coins": FieldValue.increment(Int64(bonus))
                ])
            }

            log.append("📊 \(name): \(score) Punkte, Bonus: \(bonus)")
        }
    }

    func triggerRematch() async throws {
        let db = Firestore.firestore()
        let gameRef = db.collection("games").document(gameId)

        try await gameRef.updateData([
            "rematchReady": Dictionary(uniqueKeysWithValues: createdPlayers.map { ($0, true) }),
            "gameOver": true
        ])

        log.append("♻️ Rematch ausgelöst – Status gesetzt")

        try await Task.sleep(nanoseconds: 1_000_000_000)

        let roundsRef = gameRef.collection("rounds")
        let snapshot = try await roundsRef.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }

        try await gameRef.updateData([
            "rematchReady": FieldValue.delete(),
            "gameOver": false,
            "winner": FieldValue.delete(),
            "winnerScore": FieldValue.delete(),
            "activePlayer": createdPlayers.first ?? "",
            "coinDistribution": FieldValue.delete(),
            "einsatzBezahlt": false
        ])

        log.append("🔄 Rematch-Reset abgeschlossen – bereit für nächste Runde")
    }
}
