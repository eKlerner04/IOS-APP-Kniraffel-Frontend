
import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()

    @Published var currentGame: GameSession?
    @Published var joinError: String? = nil
    @Published var joinSuccessful: Bool = false
    private var listener: ListenerRegistration?

    func createNewGame(playerName: String) {
        let customCode = generateGameCode()
        let extraModus = self.currentGame?.extraModus ?? false
        let modusString = extraModus ? "erweitert" : "standard"

        let newGame = GameSession(
            id: customCode,
            players: [playerName],
            currentTurn: 0,
            dice: [],
            isFinished: false,
            createdAt: Date(),
            started: false,
            extraModus: extraModus,
            host: playerName,
            modus: modusString
        )

        do {
            try db.collection("games").document(customCode).setData(from: newGame)
            listenToGame(id: customCode)
            joinSuccessful = true
        } catch {
            print("Fehler beim Erstellen des Spiels: \(error)")
        }
    }

    func joinGame(gameId: String, playerName: String) {
        guard !gameId.trimmingCharacters(in: .whitespaces).isEmpty else {
            joinError = "Bitte gib einen gültigen Code ein."
            joinSuccessful = false
            return
        }

        let ref = db.collection("games").document(gameId)
        ref.getDocument { snapshot, error in
            if let doc = snapshot, doc.exists {
                if let game = try? doc.data(as: GameSession.self) {
                    if game.players.contains(playerName) {
                        self.joinError = "❌ Name bereits vergeben. Wähle einen anderen."
                        self.joinSuccessful = false
                        return
                    }
                    ref.updateData([
                        "players": FieldValue.arrayUnion([playerName])
                    ])
                    self.listenToGame(id: gameId)
                    self.joinError = nil
                    self.joinSuccessful = true
                } else {
                    self.joinError = "❌ Fehler beim Laden des Spiels."
                    self.joinSuccessful = false
                }
            } else {
                self.joinError = "❌ Ungültiger Lobby-Code."
                self.joinSuccessful = false
            }
        }
    }

    func listenToGame(id: String) {
        listener?.remove()
        listener = db.collection("games").document(id).addSnapshotListener { snapshot, error in
            if let doc = snapshot, doc.exists {
                self.currentGame = try? doc.data(as: GameSession.self)
            }
        }
    }

    func startGame() {
        guard let id = currentGame?.id else { return }
        db.collection("games").document(id).updateData(["started": true])
    }

    private func generateGameCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).map { _ in letters.randomElement()! })
    }

    func updateModus(to extraModus: Bool) {
        guard let id = currentGame?.id else { return }
        let modusString = extraModus ? "erweitert" : "standard"
        db.collection("games").document(id).updateData(["modus": modusString])
    }
    // MARK: - Coinsystem Ergänzungen

        func addCoinsToPlayer(playerId: String, coins: Int) {
            let userRef = db.collection("users").document(playerId)
            userRef.updateData([
                "coins": FieldValue.increment(Int64(coins))
            ]) { error in
                if let error = error {
                    print("❌ Fehler beim Hinzufügen von Münzen: \(error.localizedDescription)")
                } else {
                    print("✅ \(coins) Münzen an Spieler \(playerId) gutgeschrieben")
                    NotificationCenter.default.post(name: .gameDidUpdate, object: nil)

                }
            }
        }
    
    func checkIfAllPlayersCanPay(entryFee: Int, completion: @escaping (Bool, String) -> Void) {
        guard let game = currentGame else {
            completion(false, "❌ Kein aktuelles Spiel gefunden.")
            return
        }
        if entryFee == 0 {
            completion(true, "✔ Kein Einsatz – alle können mitspielen!")
            return
        }


        let usersRef = Firestore.firestore().collection("users")
        var insufficientPlayers: [String] = []
        let dispatchGroup = DispatchGroup()

        for playerName in game.players {
            dispatchGroup.enter()
            usersRef.whereField("username", isEqualTo: playerName).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                if let doc = snapshot?.documents.first,
                   let coins = doc.data()["coins"] as? Int {
                    if coins < entryFee {
                        insufficientPlayers.append(playerName)
                    }
                } else {
                    insufficientPlayers.append(playerName)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            if insufficientPlayers.isEmpty {
                completion(true, "✔ Alle Spieler haben genug Münzen!")
            } else {
                completion(false, "❌ Nicht genug Münzen bei: \(insufficientPlayers.joined(separator: ", "))")
            }
        }
    }



        func deductCoinsFromPlayer(playerId: String, coins: Int) {
            let userRef = db.collection("users").document(playerId)
            userRef.updateData([
                "coins": FieldValue.increment(Int64(-coins))
            ]) { error in
                if let error = error {
                    print("❌ Fehler beim Abziehen von Münzen: \(error.localizedDescription)")
                } else {
                    print("✅ \(coins) Münzen von Spieler \(playerId) abgezogen")
                    NotificationCenter.default.post(name: .gameDidUpdate, object: nil)

                }
            }
        }
    let rewardThresholdsStandard: [(score: Int, coins: Int)] = [
        (300, 8),
        (250, 4),
        (200, 2),
        (150, 1)
    ]

    let rewardThresholdsErweitert: [(score: Int, coins: Int)] = [
        (350, 8),
        (300, 4),
        (250, 2),
        (200, 1)
    ]
    
    func rewardCoinsForScore(playerId: String, score: Int, extraModus: Bool) {
        let thresholds = extraModus ? rewardThresholdsErweitert : rewardThresholdsStandard
        var coinsToAdd = 0

        for (thresholdScore, coins) in thresholds {
            if score > thresholdScore {
                coinsToAdd = coins
                break
            }
        }

        if coinsToAdd > 0 {
            addCoinsToPlayer(playerId: playerId, coins: coinsToAdd)
        } else {
            print("ℹ️ Keine Münzen für Score \(score)")
        }
    }
    
    func bonusInfoLines(for extraModus: Bool) -> [String] {
        let thresholds = extraModus ? rewardThresholdsErweitert : rewardThresholdsStandard
        return thresholds.map { "• Ab \($0.score) Punkten: +\($0.coins) Münzen" }
    }




    // MARK: - Spielerstatistiken

    func recordGameForPlayer(playerId: String, score: Int, extraModus: Bool) {
        guard score >= 1 else {
            print("⚠️ Kein Score >0, kein History-Eintrag")
            return
        }

        let userRef = Firestore.firestore().collection("users").document(playerId)

        let entry: [String: Any] = [
            "date": Timestamp(date: Date()),
            "score": score,
            "modus": extraModus ? "erweitert" : "standard"
        ]

        userRef.updateData([
            "playerHistory": FieldValue.arrayUnion([entry])
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Speichern der playerHistory: \(error.localizedDescription)")
            } else {
                print("✅ History-Eintrag für Spieler \(playerId) gespeichert")
            }
        }
    }
    
    func setPlayerReady(playerName: String, ready: Bool) {
        guard let gameId = currentGame?.id else { return }
        let ref = Firestore.firestore().collection("games").document(gameId)
        ref.updateData(["ready.\(playerName)": ready]) { error in
            if let error = error {
                print("❌ Fehler beim Setzen des Ready-Status: \(error.localizedDescription)")
            } else {
                print("✅ Ready-Status für \(playerName) auf \(ready) gesetzt")
            }
        }
    }

    
    

    func endGame(for playerId: String, finalScore: Int) {
        recordGameForPlayer(playerId: playerId, score: finalScore, extraModus: self.currentGame?.extraModus ?? false)
        print("✅ endGame aufgerufen für \(playerId) mit Score \(finalScore)")
    }
    
    func distributeWinnerCoins(winnerName: String, totalPlayers: Int, entryFee: Int) {
        guard entryFee > 0 else {
            print("ℹ️ Kein Einsatz gespielt → kein Gewinn auszuzahlen")
            return
        }

        let usersRef = Firestore.firestore().collection("users")
        usersRef.whereField("username", isEqualTo: winnerName).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Fehler beim Finden des Gewinners: \(error.localizedDescription)")
                return
            }
            guard let doc = snapshot?.documents.first else {
                print("⚠️ Kein User-Dokument für Gewinner \(winnerName) gefunden")
                return
            }
            let playerId = doc.documentID
            let totalCoins = entryFee * totalPlayers
            self.addCoinsToPlayer(playerId: playerId, coins: totalCoins)
            print("💰 Gewinner \(winnerName) erhält \(totalCoins) Münzen aus dem Einsatz-Topf")
        }
    }

    func collectEntryFeeFromAllPlayers(entryFee: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let game = currentGame else {
            completion(false, "Kein aktuelles Spiel gefunden.")
            return
        }

        let usersRef = Firestore.firestore().collection("users")
        var insufficientPlayers: [String] = []

        let dispatchGroup = DispatchGroup()

        for playerName in game.players {
            dispatchGroup.enter()
            usersRef.whereField("username", isEqualTo: playerName).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                if let error = error {
                    print("❌ Fehler beim Prüfen der Coins für \(playerName): \(error.localizedDescription)")
                    insufficientPlayers.append(playerName)
                    return
                }
                guard let doc = snapshot?.documents.first,
                      let coins = doc.data()["coins"] as? Int else {
                    print("⚠️ Kein Coin-Daten für \(playerName) gefunden")
                    insufficientPlayers.append(playerName)
                    return
                }

                if coins < entryFee {
                    insufficientPlayers.append(playerName)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            if insufficientPlayers.isEmpty {
                // Alle haben genug → jetzt abziehen
                for playerName in game.players {
                    usersRef.whereField("username", isEqualTo: playerName).getDocuments { snapshot, error in
                        if let doc = snapshot?.documents.first {
                            let playerId = doc.documentID
                            self.deductCoinsFromPlayer(playerId: playerId, coins: entryFee)
                            print("💸 \(entryFee) Münzen von \(playerName) abgezogen")
                        }
                    }
                }
                completion(true, nil)
            } else {
                let message = "Nicht genug Münzen bei: \(insufficientPlayers.joined(separator: ", "))"
                completion(false, message)
            }
        }
    }

}





