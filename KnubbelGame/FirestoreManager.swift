
import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()

    @Published var currentGame: GameSession?
    @Published var joinError: String? = nil
    @Published var joinSuccessful: Bool = false
    private var listener: ListenerRegistration?
    private var isEntryFeeBeingCollected = false


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
            db.collection("games").document(customCode).updateData(["einsatzCoins": 0])

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

    /*
    func startGame() {
        guard let game = currentGame, let id = game.id else { return }

        // Nur der Host darf das Spiel starten
        let currentName = UserDefaults.standard.string(forKey: "playerName") ?? ""
        guard game.host == currentName else {
            print("⛔️ Nur Host darf das Spiel starten (Host ist \(game.host ?? "-"), ich bin \(currentName))")
            return
        }

        if game.einsatzCoins ?? 0 > 0 {
            if game.einsatzBezahlt {
                db.collection("games").document(id).updateData(["started": true])
                print("⛔️ Einsatz bereits bezahlt – Spiel trotzdem gestartet")
                return
            }

            collectEntryFeeFromAllPlayers(entryFee: game.einsatzCoins ?? 0) { success, error in
                if success {
                    self.db.collection("games").document(id).updateData([
                        "started": true,
                        "einsatzBezahlt": true
                    ])
                    print("✅ Spiel gestartet (mit Einsatz)")
                } else {
                    print("❌ Einsatz konnte nicht eingezogen werden: \(error ?? "Unbekannter Fehler")")
                }
            }
        } else {
            db.collection("games").document(id).updateData(["started": true])
            print("✅ Spiel gestartet (ohne Einsatz)")
        }
    }
     */
    
    func startGame() {
        print("🚀 [startGame] Funktion aufgerufen")

        guard let game = currentGame, let id = game.id else {
            print("❌ [startGame] Kein gültiges Spielobjekt oder fehlende ID")
            return
        }

        let currentName = UserDefaults.standard.string(forKey: "playerName") ?? "Unbekannt"
        print("👤 [startGame] Aktueller Spielername laut UserDefaults: \(currentName)")

        guard game.host == currentName else {
            print("⛔️ [startGame] Nicht der Host – Host ist \(game.host ?? "-"), ich bin \(currentName)")
            return
        }

        print("🟢 [startGame] Host bestätigt – Spiel kann gestartet werden")

        let gameRef = Firestore.firestore().collection("games").document(id)

        gameRef.getDocument { snapshot, error in
            if let error = error {
                print("❌ [startGame] Fehler beim Lesen des Dokuments: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data() else {
                print("❌ [startGame] Snapshot leer – kein Spielzustand gefunden")
                return
            }

            let einsatz = data["einsatzCoins"] as? Int ?? 0
            let bezahlt = data["einsatzBezahlt"] as? Bool ?? false

            print("ℹ️ [startGame] Einsatz: \(einsatz), Bereits bezahlt: \(bezahlt)")

            if einsatz > 0 && !bezahlt {
                print("💸 [startGame] Einsatz > 0 und noch nicht bezahlt → versuche Abzug")

                self.collectEntryFeeFromAllPlayers(entryFee: einsatz) { success, err in
                    if success {
                        print("✅ [startGame] Einsatz erfolgreich eingezogen – Spiel wird gestartet")
                        gameRef.updateData([
                            "started": true,
                            "einsatzBezahlt": true
                        ]) { err in
                            if let err = err {
                                print("⚠️ [startGame] Fehler beim Setzen von 'started': \(err.localizedDescription)")
                            } else {
                                print("✅ [startGame] Firestore-Feld 'started' erfolgreich gesetzt")
                            }
                        }
                    } else {
                        print("❌ [startGame] Einsatz-Abzug fehlgeschlagen: \(err ?? "Unbekannt")")
                    }
                }
            } else {
                print("✅ [startGame] Einsatz 0 oder bereits bezahlt – Spiel wird direkt gestartet")
                gameRef.updateData([
                    "started": true
                ]) { err in
                    if let err = err {
                        print("⚠️ [startGame] Fehler beim Setzen von 'started': \(err.localizedDescription)")
                    } else {
                        print("✅ [startGame] Firestore-Feld 'started' erfolgreich gesetzt")
                    }
                }
            }
        }
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

    func addCoinsToPlayer(playerId: String, coins: Int, reason: String = "Belohnung") {
        guard coins != 0 else {
            print("⚠️ Keine Münzen zum Hinzufügen – Abbruch.")
            return
        }
        
        let userRef = Firestore.firestore().collection("users").document(playerId)
        userRef.updateData([
            "coins": FieldValue.increment(Int64(coins))
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Hinzufügen von \(coins) Münzen an \(playerId): \(error.localizedDescription)")
            } else {
                print("✅ \(coins) Münzen an Spieler \(playerId) hinzugefügt. Grund: \(reason)")
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

        let entry: [String: Any] = [
            "date": Timestamp(date: Date()),
            "score": score,
            "modus": extraModus ? "erweitert" : "standard"
        ]

        // 🔍 Fall 1: playerId ist wirklich die UID → direkt updaten
        let userRef = Firestore.firestore().collection("users").document(playerId)
        userRef.getDocument { snapshot, error in
            if let snap = snapshot, snap.exists {
                userRef.updateData([
                    "playerHistory": FieldValue.arrayUnion([entry])
                ]) { error in
                    if let error = error {
                        print("❌ Fehler beim Speichern der playerHistory: \(error.localizedDescription)")
                    } else {
                        print("✅ History-Eintrag für User \(playerId) gespeichert")
                    }
                }
            } else {
                // 🔍 Fall 2: Versuch, UID aus dem Spielernamen zu ermitteln
                Firestore.firestore().collection("users")
                    .whereField("username", isEqualTo: playerId)
                    .getDocuments { query, _ in
                        if let doc = query?.documents.first {
                            let uid = doc.documentID
                            Firestore.firestore().collection("users").document(uid).updateData([
                                "playerHistory": FieldValue.arrayUnion([entry])
                            ]) { error in
                                if let error = error {
                                    print("❌ Fehler beim Speichern (username→uid): \(error.localizedDescription)")
                                } else {
                                    print("✅ History für \(playerId) (via username) gespeichert")
                                }
                            }
                        } else {
                            print("❌ Spieler nicht gefunden für history: \(playerId)")
                        }
                    }
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
        guard let game = self.currentGame else {
            completion(false, "❌ Kein Spiel aktiv")
            return
        }

        if isEntryFeeBeingCollected {
            print("⚠️ Einsatz wird bereits eingezogen – Aufruf ignoriert")
            completion(false, "Einsatz wird bereits verarbeitet")
            return
        }

        if entryFee == 0 {
            completion(true, nil)
            return
        }

        if game.einsatzBezahlt {
            print("⛔️ Einsatz bereits bezahlt – kein weiterer Abzug")
            completion(true, nil)
            return
        }

        isEntryFeeBeingCollected = true

        let usersRef = db.collection("users")
        let dispatchGroup = DispatchGroup()
        var success = true
        var errorMessage: String?
        var userUpdates: [(docRef: DocumentReference, newCoins: Int)] = []

        for player in game.players {
            dispatchGroup.enter()
            usersRef.whereField("username", isEqualTo: player).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }

                guard let doc = snapshot?.documents.first else {
                    success = false
                    errorMessage = "Spieler \(player) nicht gefunden"
                    return
                }

                let currentCoins = doc["coins"] as? Int ?? 0
                if currentCoins < entryFee {
                    success = false
                    errorMessage = "\(player) hat nicht genug Münzen"
                    return
                }

                let docRef = doc.reference
                userUpdates.append((docRef, currentCoins - entryFee))
            }
        }

        dispatchGroup.notify(queue: .main) {
            defer { self.isEntryFeeBeingCollected = false }

            if success {
                // Coins abziehen
                for update in userUpdates {
                    update.docRef.updateData(["coins": update.newCoins]) { error in
                        if let error = error {
                            print("❌ Fehler beim Abzug: \(error.localizedDescription)")
                        } else {
                            print("💸 Einsatz abgezogen, neuer Stand: \(update.newCoins)")
                        }
                    }
                }

                // Einsatz als bezahlt markieren
                if let gameId = game.id {
                    self.db.collection("games").document(gameId)
                        .updateData(["einsatzBezahlt": true])
                    print("✅ Einsatz als bezahlt gespeichert")
                }

                completion(true, nil)
            } else {
                print("❌ Einsatz konnte nicht abgezogen werden: \(errorMessage ?? "Unbekannt")")
                completion(false, errorMessage)
            }
        }
    }




    
    // MARK: - Tamagotchi Funktionen

    func initializeTamagotchi(for userId: String) {
        let userRef = Firestore.firestore().collection("users").document(userId)

        let tamagotchiData: [String: Any] = [
            "name": "Gina",
            "hunger": 100,
            "happiness": 100,
            "energy": 100,
            "level": 1,
            "lastUpdated": Timestamp(date: Date())
        ]

        userRef.updateData([
            "tamagotchi": tamagotchiData
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Initialisieren des Tamagotchi: \(error.localizedDescription)")
            } else {
                print("✅ Tamagotchi erfolgreich initialisiert!")
            }
        }
    }

    func fetchTamagotchi(for userId: String, completion: @escaping ([String: Any]?) -> Void) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let tamagotchi = data["tamagotchi"] as? [String: Any] {
                completion(tamagotchi)
            } else {
                completion(nil)
            }
        }
    }

    func updateTamagotchi(for userId: String, data: [String: Any]) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.updateData([
            "tamagotchi": data,
            "tamagotchi.lastUpdated": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Update des Tamagotchi: \(error.localizedDescription)")
            } else {
                print("✅ Tamagotchi-Daten aktualisiert")
            }
        }
    }
    func updateTamagotchiField(for userId: String, key: String, value: Any) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.updateData([
            "tamagotchi.\(key)": value,
            "tamagotchi.lastUpdated": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Setzen von tamagotchi.\(key): \(error.localizedDescription)")
            } else {
                print("✅ tamagotchi.\(key) erfolgreich aktualisiert")
            }
        }
    }

    
    // MARK: - Inventar: Stroh kaufen & verbrauchen

    func addItemToInventory(for userId: String, item: String, quantity: Int = 1) {
        let userRef = db.collection("users").document(userId)

        let fieldPath = "inventory.\(item)"
        userRef.updateData([
            fieldPath: FieldValue.increment(Int64(quantity))
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Hinzufügen zu Inventar: \(error.localizedDescription)")
            } else {
                print("✅ \(quantity)x \(item) zum Inventar hinzugefügt")
            }
        }
    }


    func removeItemFromInventory(for userId: String, item: String, quantity: Int = 1, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)

        userRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  var inventory = data["inventory"] as? [String: Int],
                  let current = inventory[item], current >= quantity else {
                print("❌ Nicht genug \(item) im Inventar")
                completion(false)
                return
            }

            let newCount = current - quantity
            var update: [String: Any]
            if newCount > 0 {
                update = ["inventory.\(item)": newCount]
            } else {
                update = ["inventory.\(item)": FieldValue.delete()]
            }

            userRef.updateData(update) { error in
                if let error = error {
                    print("❌ Fehler beim Entfernen aus Inventar: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ \(quantity)x \(item) entfernt")
                    completion(true)
                }
            }
        }
    }
    func addSkinToPlayer(playerId: String, skin: String) {
        let ref = Firestore.firestore().collection("users").document(playerId)
        ref.updateData([
            "purchasedSkins": FieldValue.arrayUnion([skin])
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Freischalten von Skin '\(skin)': \(error.localizedDescription)")
            } else {
                print("✅ Skin '\(skin)' wurde freigeschaltet!")
            }
        }
    }


    func fetchInventory(for userId: String, completion: @escaping ([String: Int]) -> Void) {
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let inventory = data["inventory"] as? [String: Int] {
                completion(inventory)
            } else {
                completion([:]) 
            }
        }
    }
}





