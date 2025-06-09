import SwiftUI
import FirebaseFirestore
import AVFoundation
import FirebaseAuth

extension Notification.Name {
    static let gameDidUpdate = Notification.Name("gameDidUpdate")
}


struct GameView: View {
    var playerName: String
    var firestore: FirestoreManager
    @State private var animateReady = false
    
    @State private var coinChangeTotal: Int = 0
    @State private var coinChangeDetails: [String] = []
    @State private var didCloseRematchSheet = false
    
    
    
    @Environment(\.dismiss) var dismiss
    @State private var showLeaveConfirmation = false
    @State private var showScoreboard = false
    @State private var showDiceView = false
    @State private var showGameOverSheet = false
    @State private var showChat = false
    
    @State private var einsatzCoins: Int = 0
    @State private var currentCoins: Int = 0
    @State private var lastGameWinAmount: Int = 0
    
    @State private var showCoinAlert = false
    @State private var coinAlertMessage = ""
    @State private var bonusCoinsEarned: Int = 0
    
    
    @State private var usedCategories: Set<String> = []
    @State private var categoryScores: [String: Int] = [:]
    
    @State private var activePlayer: String = ""
    @State private var playerTurnIndex: Int = 0
    @State private var totalPlayers: Int = 1
    
    @State private var dice: [Int] = []
    @State private var holds: [Bool] = []
    
    @State private var rollsLeft: Int = 3
    @State private var firstRollDone: Bool = false
    
    @State private var winnerName: String = ""
    @State private var winnerPoints: Int = 0
    
    @State private var lastMessagePreview: String? = nil
    @State private var previewTimer: Timer? = nil
    
    @State private var extraModus = false
    @State private var selectedSkin: String = "skin_classic"
    @State private var rematchReadyCount: Int = 0
    @State private var isPlayerReady: Bool = false
    
    @State private var countdown: Int? = nil
    @State private var countdownTimer: Timer? = nil
    
    
    
    
    
    
    let upperSection = [
        ("Nur Einser zählen", "⚀"),
        ("Nur Zweier zählen", "⚁"),
        ("Nur Dreier zählen", "⚂"),
        ("Nur Vierer zählen", "⚃"),
        ("Nur Fünfer zählen", "⚄"),
        ("Nur Sechser zählen", "⚅")
    ]
    
    var lowerSection: [String] {
        var base = [
            "Dreierpasch", "Viererpasch", "Full House",
            "Kleine Straße", "Große Straße"
        ]
        if extraModus {
            base.append(contentsOf: extendedCategories)
        }
        base.append("Chance")
        base.append("Kniraffel")
        return base
    }
    
    let extendedCategories = [
        "1 Paar", "2 Paare", "3 Paare", "Zwei Drillinge"
    ]
    
    var upperScore: Int {
        upperSection.map { categoryScores[$0.0] ?? 0 }.reduce(0, +)
    }
    
    var lowerScore: Int {
        lowerSection.map { categoryScores[$0] ?? 0 }.reduce(0, +)
    }
    
    var bonus: Int {
        let required = extraModus ? 84 : 63
        return upperScore >= required ? 35 : 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.white, Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    headerView
                    contentView
                    actionBarView
                }
            }
            .navigationTitle("Spiel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showLeaveConfirmation = true
                    }) {
                        Label("Zurück", systemImage: "chevron.left")
                    }
                }
            }
            .alert("Match verlassen?", isPresented: $showLeaveConfirmation) {
                Button("Ja", role: .destructive) {
                    leaveMatch()
                }
                Button("Nein", role: .cancel) {}
            } message: {
                Text("Willst du das laufende Spiel wirklich verlassen?")
            }
            .onAppear(perform: setupGame)
            .onChange(of: firestore.currentGame?.started) { started in
                print("🔁 [onChange] started geändert: \(started?.description ?? "nil")")
                if started == true {
                    print("🎬 [onChange] Rematch gestartet – GameView wird neu initialisiert")
                    setupGame()
                    showGameOverSheet = false
                }
            }

            
            .sheet(isPresented: $showChat) { chatSheet }
            .sheet(isPresented: $showScoreboard) { ScoreboardView(firestore: firestore) }
            .sheet(isPresented: $showDiceView) { diceRollingSheet }
            .sheet(isPresented: $showGameOverSheet) { gameOverSheet }
            
            .onAppear {
                
                
                // Skin laden
                if let userId = Auth.auth().currentUser?.uid {
                    let userRef = Firestore.firestore().collection("users").document(userId)
                    userRef.getDocument { snapshot, error in
                        if let data = snapshot?.data(), let skin = data["selectedSkin"] as? String {
                            selectedSkin = skin
                            print("✅ Geladener Skin: \(skin)")
                        } else {
                            selectedSkin = "skin_classic"
                            print("⚠️ Kein Skin gefunden, Standard gesetzt")
                        }
                    }
                } else {
                    selectedSkin = "skin_classic"
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack {
            Text("🎲 \(playerName) 🦒")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 10)
            
            if activePlayer != playerName {
                Text("⏳ Warte auf \(activePlayer)...")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Text("Noch \(((totalPlayers - playerTurnIndex - 1 + totalPlayers) % totalPlayers) + 1) Runde(n)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreCard(title: "🟦 Oberer Teil", items: upperSection, scores: categoryScores, total: upperScore, bonus: bonus, extraModus: extraModus)
                ScoreCard(title: "⬛️ Unterer Teil", items: lowerSection.map { ($0, "") }, scores: categoryScores, total: lowerScore)
                HStack {
                    Text("🔢 Gesamtsumme").font(.headline)
                    Spacer()
                    Text("\(upperScore + bonus + lowerScore)").font(.headline)
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding(.horizontal)
        }
    }
    
    private var actionBarView: some View {
        HStack(spacing: 20) {
            Button(action: { showScoreboard = true }) { IconButton(icon: "list.bullet.rectangle") }
            if activePlayer == playerName {
                Button(action: { showDiceView = true }) { IconButton(icon: "dice") }
            } else {
                Spacer()
            }
            Button(action: { showChat = true }) { IconButton(icon: "message") }
        }
        .padding(.horizontal)
    }
    
    private func setupGame() {
        if let gameId = firestore.currentGame?.id {
            listenForNewMessages(gameId: gameId)
            listenForChatUpdates(gameId: gameId)
        }
        if let modus = firestore.currentGame?.modus {
            extraModus = (modus == "erweitert")
        }
        let count = extraModus ? 6 : 5
        dice = Array(repeating: 0, count: count)
        holds = Array(repeating: false, count: count)
        observeActivePlayer()
        observeGameOver()
        observeRematchStatus()
        
        
    }
    
    
    private var chatSheet: some View {
        if let gameId = firestore.currentGame?.id {
            return AnyView(ChatView(
                gameId: gameId,
                playerName: playerName,
                onNewMessage: { msg in
                    if msg.sender != playerName {
                        showMessagePreview(msg.text)
                    }
                }
            ))
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private var diceRollingSheet: some View {
        DiceRollingView(
            playerName: playerName,
            firestore: firestore,
            usedCategories: usedCategories,
            usedScores: categoryScores,
            dice: $dice,
            holds: $holds,
            rollsLeft: $rollsLeft,
            firstRollDone: $firstRollDone,
            selectedSkin: selectedSkin,
            extraModus: extraModus
        ) { category, score in
            usedCategories.insert(category)
            categoryScores[category] = score
            let count = extraModus ? 6 : 5
            dice = Array(repeating: 0, count: count)
            holds = Array(repeating: false, count: count)
            rollsLeft = 3
            firstRollDone = false
            showDiceView = false
            advanceTurn()
            checkForGameEnd()
        }
    }
    
    private var gameOverSheet: some View {
        let myTotal = upperScore + lowerScore + bonus
        let isHost = firestore.currentGame?.host == playerName
        let myCoins = currentCoins
        let maxAllowedEinsatz = min(myCoins, 20)
        let players = firestore.currentGame?.players ?? []
        
        return VStack(spacing: 20) {
            Text("🏁 Spiel beendet").font(.largeTitle)
            Text("🏆 Gewinner: \(winnerName)").font(.title2)
            
            Text("📊 Dein Ergebnis: \(myTotal) Punkte")
                .font(.headline)
                .foregroundColor(.purple)
            
            Text("💰 Münzbilanz: \(coinChangeTotal >= 0 ? "+" : "")\(coinChangeTotal) Münzen")
                .font(.title3)
                .bold()
                .foregroundColor(coinChangeTotal >= 0 ? .green : .red)
            
            if bonusCoinsEarned > 0 {
                Text("📈 Bonus: +\(bonusCoinsEarned) Münzen")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(coinChangeDetails.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.subheadline)
                }
            }
            
            Divider()
            
            Text("💼 Kontostand: \(myCoins) Münzen")
                .font(.subheadline)
            
            if isHost {
                Stepper("💸 Einsatz pro Spieler: \(einsatzCoins) Münzen", value: $einsatzCoins, in: 0...maxAllowedEinsatz)
                    .padding()
                    .onChange(of: einsatzCoins) { newValue in
                        if let gameId = firestore.currentGame?.id {
                            Firestore.firestore().collection("games").document(gameId).updateData([
                                "einsatzCoins": newValue
                            ])
                        }
                    }
            } else {
                Text("💸 Einsatz für Rematch: \(einsatzCoins) Münzen (vom Host festgelegt)")
                    .padding()
                
                Text("⏳ Warte auf den Host, das Rematch zu starten…")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if totalPlayers > 1 {
                VStack {
                    Text("✅ Bereit: \(rematchReadyCount) / \(totalPlayers)")
                        .font(.headline)
                        .scaleEffect(animateReady ? 1.1 : 1.0)
                        .foregroundColor(.blue)
                    ProgressView(value: Double(rematchReadyCount), total: Double(totalPlayers))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .padding(.horizontal)
                }
                .padding()
            }
            
            if isHost && rematchReadyCount == totalPlayers {
                VStack(spacing: 10) {
                    if let countdown = self.countdown {
                        Text("🚀 Start in \(countdown)...")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else {
                        Button("♻️ Rematch jetzt starten") {
                            startRematchCountdown()
                        }
                        .font(.headline)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            
            
            Button(isPlayerReady ? "❌ Bereit zurücknehmen" : "✅ Rematch starten") {
                firestore.checkIfAllPlayersCanPay(entryFee: einsatzCoins) { success, message in
                    if success {
                        togglePlayerReady()
                    } else {
                        self.coinAlertMessage = message ?? "Unbekannter Fehler"
                        self.showCoinAlert = true
                    }
                }
            }
            .padding()
            .background(isPlayerReady ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("🚪 Spiel verlassen") {
                leaveMatch()
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .onAppear {
            print("📱 [GameOverSheet] wird angezeigt – Player: \(playerName), Gewinner: \(winnerName)")
            if winnerName.isEmpty, let gameId = firestore.currentGame?.id {
                let docRef = Firestore.firestore().collection("games").document(gameId)
                docRef.getDocument { snapshot, error in
                    if let data = snapshot?.data(), let winner = data["winner"] as? String {
                        winnerName = winner
                        print("📥 [GameOverSheet] Gewinner nachgeladen (manuell): \(winner)")
                    }
                }
            }

            
            guard let game = firestore.currentGame else { return }
            
            if let oldEinsatz = game.einsatzCoins {
                self.einsatzCoins = oldEinsatz
                self.lastGameWinAmount = oldEinsatz * (game.players.count)
                print("🔁 Einsatz aus Vorpartie: \(oldEinsatz) Münzen")
            }
            
            loadMyCurrentCoins()
            
            var details: [String] = []
            var totalChange = 0
            
            if let coinDist = game.coinDistribution,
               let delta = coinDist[playerName] {
                totalChange += delta
                if delta > 0 {
                    details.append("🏆 +\(delta) Münzen gewonnen")
                } else if delta == einsatzCoins {
                    details.append("🤝 Einsatz zurück bei Unentschieden")
                } else {
                    details.append("❌ \(abs(delta)) Münzen verloren")
                }
            }
            
            if let scoreBonus = game.scoreBonuses?[playerName], scoreBonus > 0 {
                totalChange += scoreBonus
                details.append("📈 +\(scoreBonus) Münzen für deinen Score")
            }
            
            self.coinChangeTotal = totalChange
            self.coinChangeDetails = details
            self.bonusCoinsEarned = game.scoreBonuses?[playerName] ?? 0
            
            print("📋 Bilanz für \(playerName): \(totalChange) Münzen")
        }
        .onReceive(firestore.$currentGame) { updatedGame in
            if let newEinsatz = updatedGame?.einsatzCoins {
                self.einsatzCoins = newEinsatz
            }
        }
        .alert(isPresented: $showCoinAlert) {
            Alert(
                title: Text("❌ Nicht genug Münzen"),
                message: Text(coinAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    
    
    
    func togglePlayerReady() {
        guard let gameId = firestore.currentGame?.id else { return }
        
        let ref = Firestore.firestore().collection("games").document(gameId)
        ref.updateData(["rematchReady.\(playerName)": !isPlayerReady]) { error in
            if let error = error {
                print("❌ Fehler beim Aktualisieren des Ready-Status: \(error.localizedDescription)")
            } else {
                isPlayerReady.toggle()
            }
        }
    }
    
    func loadMyCurrentCoins() {
        if let userId = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    self.currentCoins = data["coins"] as? Int ?? 0
                    print("💰 Eigene Coins geladen: \(self.currentCoins)")
                } else {
                    print("⚠️ Fehler beim Laden der eigenen Coins: \(error?.localizedDescription ?? "Unbekannt")")
                }
            }
        }
    }
    /*
    func startRematchCountdown() {
        guard countdown == nil else { return }
        countdown = 3
        
        print("⏱ [startRematchCountdown] Countdown gestartet")

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let current = countdown, current > 1 {
                countdown = current - 1
            } else {
                timer.invalidate()
                countdownTimer = nil
                countdown = nil
                if let game = firestore.currentGame,
                   let gameId = game.id,
                   game.players.allSatisfy({ game.ready?[$0] == true }),
                   game.host == playerName {

                    print("✅ [startRematchCountdown] Host startet Rematch nach Countdown")
                    resetAndStartRematch(for: game.players)
                }
            }
        }
    }
     */
    func startRematchCountdown() {
        guard countdown == nil else { return }
        countdown = 3

        print("⏱ [startRematchCountdown] Countdown gestartet")

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let current = countdown, current > 1 {
                countdown = current - 1
            } else {
                timer.invalidate()
                countdownTimer = nil
                countdown = nil

                guard let game = firestore.currentGame,
                      let gameId = game.id,
                      game.host == playerName else {
                    print("❌ [startRematchCountdown] Abbruch – kein gültiges Spiel oder kein Host")
                    return
                }

                let allReady = game.players.allSatisfy { game.rematchReady?[$0] == true }

                if allReady {
                    print("✅ [startRematchCountdown] Alle Spieler bereit – Rematch wird gestartet")
                    resetAndStartRematch(for: game.players)
                } else {
                    print("❌ [startRematchCountdown] Nicht alle Spieler bereit")
                }
            }
        }
    }

    
    
    func resetAndStartRematch(for players: [String]) {
        print("🔁 [resetAndStartRematch] wird aufgerufen für Spieler: \(players)")

        guard let game = firestore.currentGame,
              let gameId = game.id else {
            print("❌ [resetAndStartRematch] Kein gültiges Spielobjekt")
            return
        }

        let ref = Firestore.firestore().collection("games").document(gameId)

        print("🔁 [resetAndStartRematch] Starte continueRematchCleanup...")

        continueRematchCleanup(ref: ref, players: players)

        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🕹️ [resetAndStartRematch] Starte jetzt startGame()...")
            firestore.startGame()
        }
    }


    
    
    
    
    func loadAllPlayerCoinsAndSetMaxEinsatz() {
        guard let game = firestore.currentGame else { return }
        let usersRef = Firestore.firestore().collection("users")
        var minCoins = Int.max
        
        let dispatchGroup = DispatchGroup()
        
        for player in game.players {
            dispatchGroup.enter()
            usersRef.whereField("username", isEqualTo: player).getDocuments { snapshot, error in
                defer { dispatchGroup.leave() }
                if let doc = snapshot?.documents.first,
                   let coins = doc.data()["coins"] as? Int {
                    minCoins = min(minCoins, coins)
                    print("💰 Spieler \(player) hat \(coins) Coins")
                } else {
                    print("⚠️ Coins für \(player) nicht gefunden")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Setze den Maximalwert z. B. maximal 20 oder minimaler Coinstand
            let calculatedMax = min(minCoins, 20)
            print("✅ Einsatz-Maximum festgelegt: \(calculatedMax)")
            self.einsatzCoins = min(self.einsatzCoins, calculatedMax)  // ggf. runterschneiden
        }
    }
    
    func listenForChatUpdates(gameId: String) {
        Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("chatMessages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, _ in
                guard let doc = snapshot?.documents.first else { return }
                
                let data = doc.data()
                let sender = data["sender"] as? String ?? ""
                let text = data["text"] as? String ?? ""
                
                if sender != playerName {
                    showMessagePreview(text)
                }
            }
    }
    
    
    func leaveMatch() {
        guard let game = firestore.currentGame, let gameId = game.id else { return }
        let ref = Firestore.firestore().collection("games").document(gameId)
        
        let myPlayerName = playerName
        let myUID = Auth.auth().currentUser?.uid ?? ""
        
        let roundsRef = Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("rounds")
            .whereField("player", isEqualTo: myPlayerName)
        
        roundsRef.getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else {
                print("⚠️ Keine Runden für \(myPlayerName) gefunden")
                actuallyLeave(ref: ref, updatedPlayers: game.players.filter { $0 != myPlayerName })
                return
            }
            
            var scoreDict: [String: Int] = [:]
            for doc in docs {
                if let cat = doc["category"] as? String,
                   let pts = doc["score"] as? Int {
                    scoreDict[cat] = pts
                }
            }
            
            let upper = upperSection.map { scoreDict[$0.0] ?? 0 }.reduce(0, +)
            let lower = lowerSection.map { scoreDict[$0] ?? 0 }.reduce(0, +)
            let bonusThreshold = extraModus ? 84 : 63
            let bonus = upper >= bonusThreshold ? 35 : 0
            let total = upper + lower + bonus
            
            firestore.recordGameForPlayer(playerId: myUID, score: total, extraModus: extraModus)
            print("✅ [LeaveMatch] Mein eigener Spielstand gespeichert: \(total)")
            
            actuallyLeave(ref: ref, updatedPlayers: game.players.filter { $0 != myPlayerName })
        }
    }
    
    private func actuallyLeave(ref: DocumentReference, updatedPlayers: [String]) {
        ref.updateData(["players": updatedPlayers]) { error in
            if let error = error {
                print("❌ Fehler beim Entfernen des Spielers: \(error.localizedDescription)")
            } else {
                print("✅ Spieler \(playerName) hat das Match verlassen")
                dismiss()
            }
        }
    }
    
    
    
    /*
     func observeActivePlayer() {
     guard let game = firestore.currentGame else { return }
     totalPlayers = game.players.count
     let gameId = game.id ?? ""
     
     let ref = Firestore.firestore().collection("games").document(gameId)
     
     ref.getDocument { snapshot, _ in
     if let data = snapshot?.data(),
     (data["activePlayer"] as? String)?.isEmpty != false {
     let firstPlayer = game.players.first ?? ""
     ref.updateData(["activePlayer": firstPlayer])
     }
     }
     
     ref.addSnapshotListener { snapshot, _ in
     if let data = snapshot?.data(),
     let current = data["activePlayer"] as? String {
     activePlayer = current
     if let index = game.players.firstIndex(of: current) {
     playerTurnIndex = (index - (game.players.firstIndex(of: playerName) ?? 0) + totalPlayers) % totalPlayers
     }
     }
     }
     }
     */
    
    
    func observeActivePlayer() {
        guard let game = firestore.currentGame else { return }
        totalPlayers = game.players.count
        let gameId = game.id ?? ""
        
        let ref = Firestore.firestore().collection("games").document(gameId)
        
        // 🔁 Initial: Wenn kein aktiver Spieler gesetzt ist, nimm den ersten
        ref.getDocument { snapshot, _ in
            if let data = snapshot?.data(),
               (data["activePlayer"] as? String)?.isEmpty != false {
                let firstPlayer = game.players.first ?? ""
                ref.updateData(["activePlayer": firstPlayer])
            }
        }
        
        // 📡 Live-Listener
        ref.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data(),
                  let current = data["activePlayer"] as? String else { return }
            
            activePlayer = current
            
            if let myIndex = game.players.firstIndex(of: playerName),
               let currentIndex = game.players.firstIndex(of: current) {
                playerTurnIndex = (currentIndex - myIndex + game.players.count) % game.players.count
            }
            
            print("🎯 Aktiver Spieler laut Firestore: \(current)")
            print("🤖 Ich bin: \(playerName), mein TurnIndex: \(playerTurnIndex)")
        }
    }
    
    
    func showMessagePreview(_ message: String) {
        lastMessagePreview = message
        
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            lastMessagePreview = nil
        }
    }
    
    /*
    func observeGameOver() {
        guard let gameId = firestore.currentGame?.id else { return }
        
        let ref = Firestore.firestore().collection("games").document(gameId)
        
        ref.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data(),
                  let isOver = data["gameOver"] as? Bool,
                  isOver else { return }
            
            winnerName = data["winner"] as? String ?? "?"
            winnerPoints = data["winnerScore"] as? Int ?? 0
            showGameOverSheet = true
        }
    }
    
    func observeGameOver() { //aktueller als die oberer
        guard let gameId = firestore.currentGame?.id else { return }

        let ref = Firestore.firestore().collection("games").document(gameId)

        ref.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            let isOver = data["gameOver"] as? Bool ?? false

            if isOver && !showGameOverSheet && !didCloseRematchSheet {
                print("🏁 [observeGameOver] Spiel ist vorbei – GameOverSheet wird angezeigt")
                winnerName = data["winner"] as? String ?? "?"
                winnerPoints = data["winnerScore"] as? Int ?? 0
                showGameOverSheet = true
            }else if isOver && didCloseRematchSheet {
                print("🛑 [observeGameOver] Spiel ist vorbei, aber wurde schon für Rematch zurückgesetzt")
            }
        }
    }
     */
    func observeGameOver() {
        guard let gameId = firestore.currentGame?.id else { return }

        let ref = Firestore.firestore().collection("games").document(gameId)

        ref.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            let isOver = data["gameOver"] as? Bool ?? false
            let winner = data["winner"] as? String ?? "?"
            let winnerScore = data["winnerScore"] as? Int ?? 0

            print("👀 [observeGameOver] isOver=\(isOver), showGameOverSheet=\(showGameOverSheet), didCloseRematchSheet=\(didCloseRematchSheet)")

            if isOver && !showGameOverSheet {
                print("🏁 [observeGameOver] Spiel ist vorbei – GameOverSheet wird angezeigt (auch wenn didCloseRematchSheet true ist)")
                winnerName = winner
                winnerPoints = winnerScore
                showGameOverSheet = true
                didCloseRematchSheet = false
            }
        }
    }




    
    
    func advanceTurn() {
        guard let game = firestore.currentGame, let gameId = game.id else { return }
        if let index = game.players.firstIndex(of: activePlayer) {
            let nextIndex = (index + 1) % game.players.count
            let nextPlayer = game.players[nextIndex]
            let ref = Firestore.firestore().collection("games").document(gameId)
            ref.updateData(["activePlayer": nextPlayer])
        }
    }
    func listenForNewMessages(gameId: String) {
        Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("chat")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, _ in
                guard let doc = snapshot?.documents.first else { return }
                let data = doc.data()
                let sender = data["sender"] as? String ?? ""
                let text = data["text"] as? String ?? ""
                
                if sender != playerName {
                    showMessagePreview(text)
                }
            }
    }
    
    
    func checkForGameEnd() {
        guard let game = firestore.currentGame,
              let gameId = game.id else { return }
        
        Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("rounds")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                
                let grouped = Dictionary(grouping: docs, by: { $0["player"] as? String ?? "" })
                let requiredCategoryCount = upperSection.count + lowerSection.count
                //let requiredCategoryCount = 1

                
                // Nur beenden, wenn ALLE Spieler alle Runden gespielt haben
                let allPresent = Set(game.players).isSubset(of: Set(grouped.keys))
                let allFinished = grouped.values.allSatisfy { $0.count >= requiredCategoryCount }

                guard allPresent && allFinished else { return }

                
                var bestScore = Int.min
                var bestPlayers: [String] = []
                var coinDistribution: [String: Int] = [:]
                var scoreBonuses: [String: Int] = [:]
                
                let entryFee = game.einsatzCoins ?? 0
                let playerCount = game.players.count
                let totalPot = entryFee * playerCount
                let thresholds = game.extraModus == true ? firestore.rewardThresholdsErweitert : firestore.rewardThresholdsStandard
                
                // Score-Berechnung und Bonusvergabe
                for (player, entries) in grouped {
                    var scores: [String: Int] = [:]
                    for doc in entries {
                        if let cat = doc["category"] as? String,
                           let pts = doc["score"] as? Int {
                            scores[cat] = pts
                        }
                    }
                    
                    let upper = upperSection.map { scores[$0.0] ?? 0 }.reduce(0, +)
                    let lower = lowerSection.map { scores[$0] ?? 0 }.reduce(0, +)
                    let bonus = (upper >= (game.extraModus == true ? 84 : 63)) ? 35 : 0
                    let total = upper + lower + bonus
                    
                    firestore.endGame(for: player, finalScore: total)
                    
                    // Score-Bonus bestimmen
                    let bonusCoins = thresholds.first(where: { total > $0.score })?.coins ?? 0
                    scoreBonuses[player] = bonusCoins
                    
                    // Beste(r) Spieler
                    if total > bestScore {
                        bestScore = total
                        bestPlayers = [player]
                    } else if total == bestScore {
                        bestPlayers.append(player)
                    }
                }
                
                // Pot-Verteilung
                if bestPlayers.count > 1 {
                    let share = totalPot / bestPlayers.count
                    for player in bestPlayers {
                        coinDistribution[player] = share
                    }
                } else if let winner = bestPlayers.first {
                    coinDistribution[winner] = totalPot
                }
                
                // Speicherung in Firestore
                let ref = Firestore.firestore().collection("games").document(gameId)
                ref.updateData([
                    "gameOver": true,
                    "winner": bestPlayers.first ?? "",
                    "winnerScore": bestScore,
                    "coinDistribution": coinDistribution,
                    "scoreBonuses": scoreBonuses
                ])
                
                // Auszahlung an Spieler
                let usersRef = Firestore.firestore().collection("users")
                let allPlayers = Set(coinDistribution.keys).union(scoreBonuses.keys)
                
                for player in allPlayers {
                    let win = coinDistribution[player] ?? 0
                    let bonus = scoreBonuses[player] ?? 0
                    let totalCoins = win + bonus
                    guard totalCoins > 0 else { continue }
                    
                    usersRef.whereField("username", isEqualTo: player).getDocuments { snapshot, _ in
                        guard let doc = snapshot?.documents.first else { return }
                        let playerId = doc.documentID
                        firestore.addCoinsToPlayer(playerId: playerId, coins: totalCoins, reason: "Gewinn: \(win) + Bonus: \(bonus)")
                    }
                }
                
                print("✅ Spiel abgeschlossen mit Pot \(totalPot), Gewinner: \(bestPlayers.joined(separator: ", "))")
            }
    }
    
    
    
    
    
    
    
    
    
    
    func markPlayerReadyForRematch() {
        guard let gameId = firestore.currentGame?.id else { return }
        
        let ref = Firestore.firestore().collection("games").document(gameId)
        ref.updateData(["rematchReady.\(playerName)": true])
    }

    func observeRematchStatus() {
        guard let game = firestore.currentGame,
              let gameId = game.id else { return }

        let ref = Firestore.firestore().collection("games").document(gameId)

        ref.addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            if let rematchDict = data["rematchReady"] as? [String: Bool] {
                let readyCount = rematchDict.filter { $0.value }.count
                rematchReadyCount = readyCount
            }

            if let gameOver = data["gameOver"] as? Bool, gameOver == false {
                // Reset bei neuem Spiel
                if showGameOverSheet {
                    print("✅ [observeRematchStatus] gameOver == false und Sheet ist offen – schließen")
                    resetGameState()
                    showGameOverSheet = false
                    didCloseRematchSheet = true
                    isPlayerReady = false
                } else if !didCloseRematchSheet && winnerName != "" {
                    // Fallback nur auslösen, wenn winnerName bereits gesetzt war → dann aber sicher resetten
                    print("🛠️ [observeRematchStatus] Fallback-Reset nach 2s, warte auf mögliches Sheet")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if !showGameOverSheet {
                            print("🛠️ [observeRematchStatus] Fallback aktiv – kein Sheet nach 2s → Reset")
                            resetGameState()
                            didCloseRematchSheet = true
                            isPlayerReady = false
                        } else {
                            print("ℹ️ [observeRematchStatus] Sheet ist inzwischen sichtbar – kein Fallback nötig")
                        }
                    }
                } else {
                    print("⚠️ [observeRematchStatus] Kein Reset – warte auf GameOver oder Sheet")
                }
            }
        }
    }


    
    
    
    
    
    
    /*
    private func continueRematchCleanup(ref: DocumentReference, players: [String]) {
        let entryFee = einsatzCoins
        
        firestore.collectEntryFeeFromAllPlayers(entryFee: entryFee) { success, message in
            if success {
                ref.collection("rounds").getDocuments { snapshot, _ in
                    let allRounds = snapshot?.documents ?? []
                    for round in allRounds {
                        round.reference.delete()
                    }
                    print("🗑 [Rematch] Alte Runden gelöscht")
                    
                    // Firestore zurücksetzen
                    ref.updateData([
                        "rematchReady": FieldValue.delete(),
                        "gameOver": false,
                        "winner": FieldValue.delete(),
                        "winnerScore": FieldValue.delete(),
                        "activePlayer": players.first ?? "",
                        "coinDistribution": FieldValue.delete(),
                        "scoreBonuses": FieldValue.delete(),
                        "einsatzBezahlt": false,
                        "started": false
                    ]) { error in
                        if let error = error {
                            print("❌ Fehler beim Reset: \(error.localizedDescription)")
                        } else {
                            print("✅ [Rematch] Zurückgesetzt")
                        }
                    }
                    
                    // ❗ Spieler-Ready explizit zurücksetzen
                    for player in players {
                        ref.updateData([
                            "ready.\(player)": false
                        ])
                    }
                    
                    // Lokale Zustände
                    DispatchQueue.main.async {
                        self.resetGameState()
                        self.isPlayerReady = false
                        self.didCloseRematchSheet = false
                    }
                }
            } else {
                print("❌ Einsatz konnte nicht eingezogen werden: \(message ?? "Unbekannt")")
            }
        }
    }
     */
    private func continueRematchCleanup(ref: DocumentReference, players: [String]) {
        let entryFee = einsatzCoins

        firestore.collectEntryFeeFromAllPlayers(entryFee: entryFee) { success, message in
            if success {
                ref.collection("rounds").getDocuments { snapshot, _ in
                    let allRounds = snapshot?.documents ?? []
                    for round in allRounds {
                        round.reference.delete()
                    }
                    print("🗑 [Rematch] Alte Runden gelöscht")

                    // Firestore-Daten zurücksetzen
                    ref.updateData([
                        "rematchReady": FieldValue.delete(),
                        "gameOver": false,
                        "winner": FieldValue.delete(),
                        "winnerScore": FieldValue.delete(),
                        "activePlayer": players.first ?? "",
                        "coinDistribution": FieldValue.delete(),
                        "scoreBonuses": FieldValue.delete(),
                        "einsatzBezahlt": false,
                        "started": false
                    ]) { error in
                        if let error = error {
                            print("❌ Fehler beim Reset: \(error.localizedDescription)")
                        } else {
                            print("✅ [Rematch] Zurückgesetzt")
                        }
                    }

                    // ✅ Lokale Zustände
                    DispatchQueue.main.async {
                        self.resetGameState()
                        self.isPlayerReady = false
                        self.didCloseRematchSheet = false
                    }
                }
            } else {
                print("❌ Einsatz konnte nicht eingezogen werden: \(message ?? "Unbekannt")")
            }
        }
    }

    
    
    /*
     func resetGameState() {
     usedCategories = []
     categoryScores = [:]
     dice = Array(repeating: 0, count: 5)
     holds = Array(repeating: false, count: 5)
     rollsLeft = 3
     firstRollDone = false
     showGameOverSheet = false
     let count = extraModus ? 6 : 5
     dice = Array(repeating: 0, count: count)
     holds = Array(repeating: false, count: count)
     
     
     }
     }
     */
    func resetGameState() {
        print("🔄 [resetGameState] Lokaler Spielzustand wird zurückgesetzt")
        usedCategories = []
        categoryScores = [:]
        bonusCoinsEarned = 0
        coinChangeTotal = 0
        coinChangeDetails = []
        winnerName = ""
        winnerPoints = 0
        isPlayerReady = false
        didCloseRematchSheet = false

        let count = extraModus ? 6 : 5
        dice = Array(repeating: 0, count: count)
        holds = Array(repeating: false, count: count)
        rollsLeft = 3
        firstRollDone = false

        showGameOverSheet = false
        showDiceView = false
        showScoreboard = false
        showChat = false
        animateReady = false
        rematchReadyCount = 0
        countdown = nil
        countdownTimer?.invalidate()
        countdownTimer = nil

        activePlayer = ""
        playerTurnIndex = 0

        observeActivePlayer()
    }
}


struct ScoreCard: View {
    let title: String
    let items: [(String, String)]
    let scores: [String: Int]
    let total: Int
    var bonus: Int? = nil
    var extraModus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(items, id: \.0) { (name, symbol) in
                HStack {
                    Text("\(symbol) \(name)")
                    Spacer()
                    Text(scores[name]?.description ?? "–")
                        .foregroundColor(scores[name] != nil ? .green : .gray)
                }
            }

            Divider()

            HStack {
                Text("Gesamt")
                Spacer()
                Text("\(total)")
            }

            if let bonus = bonus {
                HStack {
                    Text("Bonus (\(extraModus ? "84" : "63")) +35")
                    Spacer()
                    Text(bonus > 0 ? "+35" : "noch \(extraModus ? 84 - total : 63 - total)")
                        .foregroundColor(bonus > 0 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct IconButton: View {
    let icon: String
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 30))
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
    }
}







// MARK: - DiceRollingView
import SwiftUI
import FirebaseFirestore
import AVFoundation
import FirebaseAuth

struct DiceRollingView: View {
    var playerName: String
    var firestore: FirestoreManager
    var usedCategories: Set<String>
    var usedScores: [String: Int]
    @Binding var dice: [Int]
    @Binding var holds: [Bool]
    @Binding var rollsLeft: Int
    @Binding var firstRollDone: Bool
    var selectedSkin: String
    var extraModus: Bool

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRolling = false
    @State private var displayedDice: [Int] = []

    var onRoundComplete: (String, Int) -> Void
    @State private var selectedOption: String = ""
    @State private var scoreMap: [String: Int] = [:]
    
    
    var options: [String] {
        var base = [
            "Nur Einser zählen", "Nur Zweier zählen", "Nur Dreier zählen",
            "Nur Vierer zählen", "Nur Fünfer zählen", "Nur Sechser zählen",
            "Dreierpasch", "Viererpasch", "Full House",
            "Kleine Straße", "Große Straße"
        ]
        if extraModus {
            base.append(contentsOf: [
                "1 Paar", "2 Paare", "3 Paare", "Zwei Drillinge"
            ])
        }
        base.append("Chance")
        base.append("Kniraffel")
        return base
    }
    
    
    

    var canSubmitRound: Bool {
        !selectedOption.isEmpty &&
        !usedCategories.contains(selectedOption) &&
        firstRollDone
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("🎲 Würfeln").font(.title)

            HStack {
                ForEach(0..<dice.count, id: \.self) { i in
                    VStack {
                        diceImage(for: displayedDice.indices.contains(i) ? displayedDice[i] : dice[i], skin: selectedSkin)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .padding(4)
                            .background(i < holds.count && holds[i] ? Color.green.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture {
                                if firstRollDone && i < holds.count {
                                    holds[i].toggle()
                                }
                            }

                        Text(i < holds.count && holds[i] && firstRollDone ? "Behalten" : "")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Text("Würfe übrig: \(rollsLeft)")

            Button("Würfeln") {
                guard !isRolling else { return }

                isRolling = true
                SoundEffectManager.shared.playButtonSound()

                let rollDuration = 0.6
                let rollInterval = 0.05
                var elapsed = 0.0

                Timer.scheduledTimer(withTimeInterval: rollInterval, repeats: true) { timer in
                    elapsed += rollInterval

                    for i in 0..<min(dice.count, holds.count) where !holds[i] {
                        displayedDice[i] = Int.random(in: 1...6)
                    }

                    if elapsed >= rollDuration {
                        timer.invalidate()
                        var changed = false
                        for i in 0..<min(dice.count, holds.count) where !holds[i] {
                            let newValue = Int.random(in: 1...6)
                            if dice[i] != newValue {
                                changed = true
                            }
                            dice[i] = newValue
                            displayedDice[i] = newValue // finale Anzeige
                        }

                        if changed {
                            rollsLeft -= 1
                            firstRollDone = true
                            updateScoreMap()
                            SoundEffectManager.shared.playDiceSound()
                        }

                        isRolling = false
                    }
                }
            }
            .disabled(rollsLeft == 0 || isRolling)
            .padding()
            .background((rollsLeft > 0 && !isRolling) ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)

            Divider()

            Text("Kategorie auswählen").font(.headline)

            Picker("Kategorie", selection: $selectedOption) {
                ForEach(options.filter { !usedCategories.contains($0) }, id: \.self) { option in
                    let value = scoreMap[option] ?? 0
                    Text("\(option) - \(value) Punkte")
                        .foregroundColor(.gray)
                }
            }
            .pickerStyle(WheelPickerStyle())

            Button("✅ Runde abschließen") {
                let score = scoreMap[selectedOption] ?? 0
                saveRound(score: score)

                if let uid = Auth.auth().currentUser?.uid {
                    let userRef = Firestore.firestore().collection("users").document(uid)
                    let fieldToUpdate = extraModus ? "totalScore_erweitert" : "totalScore_standard"

                    userRef.updateData([
                        fieldToUpdate: FieldValue.increment(Int64(score))
                    ]) { error in
                        if let error = error {
                            print("❌ Fehler beim Aktualisieren des Scores: \(error.localizedDescription)")
                        } else {
                            print("✅ \(fieldToUpdate) für User \(uid) um \(score) erhöht")
                            NotificationCenter.default.post(name: .gameDidUpdate, object: nil)
                        }
                    }
                } else {
                    print("❌ Kein eingeloggter User gefunden")
                }
                onRoundComplete(selectedOption, score)
            }
            .disabled(!canSubmitRound)
            .padding()
            .background(canSubmitRound ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .onAppear {
            displayedDice = dice
            updateScoreMap()
            let availableOptions = options.filter { !usedCategories.contains($0) }
            if selectedOption.isEmpty || usedCategories.contains(selectedOption) {
                selectedOption = availableOptions.first ?? ""
            }
        }
    }

    func updateScoreMap() {
        var tempMap: [String: Int] = [:]
        for option in options where !usedCategories.contains(option) {
            tempMap[option] = calculateScore(for: option)
        }
        scoreMap = tempMap
    }

    func diceImage(for value: Int, skin: String) -> Image {
        // Fallback gleich am Anfang
        guard (1...6).contains(value) else {
            return Image("dice_placeholder")
        }

        let fullImageName: String

        if skin == "skin_classic" {
            fullImageName = String(format: "würfel_%02d", value)
        } else if skin == "holo" {
            fullImageName = String(format: "holo_%02d", value)
        } else if skin == "gold" {
            fullImageName = String(format: "gold_%02d", value)
        } else if skin == "rot" {
            fullImageName = String(format: "rot_%02d", value)
        } else if skin == "holz" {
            fullImageName = String(format: "holz_%02d", value)
        } else if skin == "platin" {
            fullImageName = String(format: "platin_%02d", value)
        } else if skin == "kniraffel" {
            fullImageName = String(format: "kniraffel_%02d", value)
        }else if skin == "love" {
            fullImageName = String(format: "love_%02d", value)
        } else if skin == "duempeldorf" {
            fullImageName = String(format: "duempeldorf_%02d", value)
        } else {
            fullImageName = String(format: "%@_%02d", skin, value)
        }

        if UIImage(named: fullImageName) != nil {
            return Image(fullImageName)
        } else {
            return Image("dice_placeholder")
        }
    }





    func saveRound(score: Int) {
        guard let gameId = firestore.currentGame?.id else { return }
        let ref = Firestore.firestore().collection("games").document(gameId)
        let diceValues = dice.map(String.init).joined(separator: ",")
        let entry: [String: Any] = [
            "player": playerName,
            "dice": diceValues,
            "category": selectedOption,
            "score": score,
            "timestamp": Timestamp(date: Date())
        ]
        ref.collection("rounds").addDocument(data: entry)
    }

    func calculateScore(for category: String) -> Int {
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let total = dice.reduce(0, +)
        let unique = Set(dice).sorted()

        switch category {
        case "Nur Einser zählen": return dice.filter { $0 == 1 }.reduce(0, +)
        case "Nur Zweier zählen": return dice.filter { $0 == 2 }.reduce(0, +)
        case "Nur Dreier zählen": return dice.filter { $0 == 3 }.reduce(0, +)
        case "Nur Vierer zählen": return dice.filter { $0 == 4 }.reduce(0, +)
        case "Nur Fünfer zählen": return dice.filter { $0 == 5 }.reduce(0, +)
        case "Nur Sechser zählen": return dice.filter { $0 == 6 }.reduce(0, +)
        case "Dreierpasch": return counts.values.contains(where: { $0 >= 3 }) ? total : 0
        case "Viererpasch": return counts.values.contains(where: { $0 >= 4 }) ? total : 0
        case "Full House":
            let values = counts.values.sorted()
            if extraModus {
                return (values == [2, 4]) ? 35 : 0
            } else {
                return (values == [2, 3]) ? 25 : 0
            }
        case "Kleine Straße":
            return containsStraight(length: extraModus ? 5 : 4) ? (extraModus ? 35 : 30) : 0
        case "Große Straße":
            return containsStraight(length: extraModus ? 6 : 5) ? (extraModus ? 45 : 40) : 0
        case "Kniraffel":
            return counts.values.contains(extraModus ? 6 : 5) ? (extraModus ? 60 : 50) : 0
        case "Chance":
            return total
        case "1 Paar":
            let pairs = counts.filter { $0.value >= 2 }.keys
            if let best = pairs.max() {
                return best * 2
            }
            return 0
        case "2 Paare":
            let pairs = counts.filter { $0.value >= 2 }.keys.sorted(by: >)
            return pairs.count >= 2 ? pairs.prefix(2).map { $0 * 2 }.reduce(0, +) : 0
        case "3 Paare":
            let pairs = counts.filter { $0.value >= 2 }.keys.sorted(by: >)
            return pairs.count >= 3 ? pairs.prefix(3).map { $0 * 2 }.reduce(0, +) : 0
        case "Zwei Drillinge":
            let drillings = counts.filter { $0.value >= 3 }.keys
            return drillings.count >= 2 ? drillings.map { $0 * 3 }.reduce(0, +) : 0
        default:
            return 0
        }
    }

    func containsStraight(length: Int) -> Bool {
        let uniqueSorted = Set(dice).sorted()
        if extraModus {
            return length == 6 ? uniqueSorted == [1, 2, 3, 4, 5, 6] : hasStraight(in: uniqueSorted, requiredLength: 5)
        } else {
            return hasStraight(in: uniqueSorted, requiredLength: length)
        }
    }

    private func hasStraight(in sortedValues: [Int], requiredLength: Int) -> Bool {
        guard sortedValues.count >= requiredLength else { return false }
        var maxLength = 1
        var current = 1
        for i in 1..<sortedValues.count {
            if sortedValues[i] == sortedValues[i - 1] + 1 {
                current += 1
                if current >= requiredLength {
                    return true
                }
            } else {
                current = 1
            }
        }
        return false
    }
}


