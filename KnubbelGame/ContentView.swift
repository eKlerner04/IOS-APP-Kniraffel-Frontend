import SwiftUI
import FirebaseFirestore

extension Notification.Name {
    static let showUsernameSetup = Notification.Name("showUsernameSetup")
}


struct ContentView: View {
    @StateObject var firestore = FirestoreManager()
    @State private var showTamagotchiView = false

    @State private var gameCode: String = ""
    @State private var showLobby = false
    @State private var isInGame = false
    @State private var showSettingsSheet = false
    @State private var finalName: String = ""
    @State private var topPlayers: [(name: String, score: Int)] = []
    @State private var showExtended = false
    @State private var showProfileSheet = false
    @State private var showUsernameSetup = false
    @State private var currentUserId: String = ""
    @AppStorage("playerName") private var playerName: String = ""
    @State private var tempName: String = ""
    @State private var playedGamesStandard: Int = 0
    @State private var playedGamesErweitert: Int = 0
    @State private var topUserScores: [(name: String, average: Double)] = []
    @State private var showForceUpdateAlert = false
    @State private var requiredVersion = ""
    @State private var currentCoins: Int = 0
    @State private var showShop = false
    @State private var showDebugTestView = false
    @State private var showMultiDebug = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("🎲 Kniraffel 🦒")
                                .font(.system(size: 34, weight: .bold))
                            Text("Let’s roll and score big!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundColor(.yellow)
                            Text("Münzen: \(currentCoins)")
                                .font(.headline)
                                .bold()
                        }

                        .padding(.top, 30)

                        VStack(spacing: 12) {

                            TextField("Lobby-Code (nur zum Beitreten)", text: $gameCode)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled(true)
                        }
                        .padding(.horizontal)

                        if let error = firestore.joinError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            Button(action: {
                                handleCreateLobby()
                            }) {
                                Label("Neue Lobby erstellen", systemImage: "wrench.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(color: .green))

                            Button(action: {
                                handleJoinLobby()
                            }) {
                                Label("Lobby beitreten", systemImage: "link")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(color: .blue))
                            
                            Button(action: {
                                showShop = true
                            }) {
                                Label("Zum Shop", systemImage: "cart.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(color: .yellow))
                            
                            
                            Button(action: {
                                showProfileSheet = true
                            }) {
                                Label("Profil", systemImage: "person.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(OutlinedButtonStyle())
                            


                            HStack(spacing: 16) {
                                Button(action: {
                                    showTamagotchiView = true
                                }) {
                                    Image("KniraffelKopf")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .padding(8)

                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    showSettingsSheet = true
                                }) {
                                    Image(systemName: "gear")
                                        .font(.title2)
                                        .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            
                            

                        }
                        .padding(.horizontal)

                        Picker("Modus", selection: $showExtended) {
                            Text("Standard").tag(false)
                            Text("Erweitert").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: showExtended) { _ in
                            loadHighscores()
                            loadTopUserScores()
                        }

                        GroupBox(label: Text("🌍 Weltrangliste – Top 5")) {
                            HighscoreList(entries: topPlayers.map { ($0.name, "\($0.score) Punkte") })
                        }
                        .padding(.horizontal)

                        GroupBox(label: Text("⭐ User-Topliste (\(showExtended ? "Erweitert" : "Standard"))")) {
                            HighscoreList(entries: topUserScores.map { ($0.name, "Ø \(String(format: "%.1f", $0.average)) Punkte/Spiel") })
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationDestination(isPresented: $showLobby) {
                LobbyView(firestore: firestore, playerName: finalName, isInGame: $isInGame)
            }
            .navigationDestination(isPresented: $isInGame) {
                GameView(playerName: finalName, firestore: firestore)
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileView()
            }
            .sheet(isPresented: $showTamagotchiView) {
                TamagotchiView()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .sheet(isPresented: $showShop) {
                ShopView()
            }
            .sheet(isPresented: $showDebugTestView) {
                DebugTestView()
            }
            .sheet(isPresented: $showMultiDebug) {
                MultiPlayerDebugView()
            }



            .onAppear {
                firestore.resetJoinStatus()
                loadHighscores()
                loadTopUserScores()
                loadUsernameIfNeeded()
                loadPlayedGames()
                checkForForcedUpdate()
                loadCurrentCoins()
            }
            .onReceive(NotificationCenter.default.publisher(for: .gameDidUpdate)) { _ in
                print("🔄 Empfange Update → lade Coins neu")
                loadCurrentCoins()
            }

            .sheet(isPresented: $showForceUpdateAlert) {
                VStack(spacing: 20) {
                    Text("🚨 Update erforderlich")
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)

                    Text("Bitte aktualisiere die App auf Version \(requiredVersion), um weiterzuspielen.")
                        .multilineTextAlignment(.center)
                        .padding()

                    Button(action: {
                        if let url = URL(string: "https://apps.apple.com/de/app/kniraffel/id6746126607?l=en-GB") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Update öffnen")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    

                    Spacer()
                }
                .padding()
                .presentationDetents([.medium, .large]) // nur wenn du SwiftUI sheets moderner nutzen willst
                .interactiveDismissDisabled(true)
            }

            .onChange(of: firestore.joinSuccessful) { success in
                if success {
                    showLobby = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showUsernameSetup)) { notification in
                if let uid = notification.object as? String {
                    self.currentUserId = uid
                    self.showUsernameSetup = true
                }
            }



            .onReceive(NotificationCenter.default.publisher(for: .showUsernameSetup)) { notification in
                if let uid = notification.object as? String {
                    self.currentUserId = uid
                    self.showUsernameSetup = true
                }
            }
            .sheet(isPresented: $showUsernameSetup) {
                UsernameSetupView(uid: currentUserId) {
                    self.showUsernameSetup = false
                }
            }
        }
    }

    // MARK: - Helper Views + Styles

    struct FilledButtonStyle: ButtonStyle {
        var color: Color
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding()
                .background(color.opacity(configuration.isPressed ? 0.7 : 1))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    struct OutlinedButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding()
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
        }
    }

    struct HighscoreList: View {
        let entries: [(String, String)]
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                if entries.isEmpty {
                    Text("Lade Daten ...")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Text("#\(index + 1)").bold()
                            Text(entry.0)
                            Spacer()
                            Text(entry.1)
                                .bold()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Button Actions

    private func handleCreateLobby() {
        finalName = playerName
        firestore.createNewGame(playerName: finalName)
        showLobby = true
    }

    private func handleJoinLobby() {
        finalName = playerName
        let code = gameCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !code.isEmpty else {
            firestore.joinError = "Bitte gib einen gültigen Code ein."
            firestore.joinSuccessful = false
            return
        }

        firestore.checkIfGameIsJoinableManual(gameId: code) { canJoin, message in
            if canJoin {
                firestore.joinGame(gameId: code, playerName: finalName)
            } else {
                firestore.joinError = message ?? "Beitritt nicht möglich."
                firestore.joinSuccessful = false
            }
        }
    }


    // ... (deine bestehenden Funktionen: loadHighscores, loadTopUserScores, loadUsernameIfNeeded) ...
    func loadHighscores() {
        let filter = showExtended ? "erweitert" : "standard"
        Firestore.firestore().collection("highscores")
            .whereField("modus", isEqualTo: filter)
            .order(by: "score", descending: true)
            .limit(to: 5)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Fehler beim Laden: \(error.localizedDescription)")
                }
                guard let documents = snapshot?.documents else {
                    print("⚠️ Keine Dokumente gefunden")
                    return
                }
                topPlayers = documents.compactMap {
                    let data = $0.data()
                    guard let name = data["playerName"] as? String,
                          let score = data["score"] as? Int else { return nil }
                    return (name, score)
                }
            }
    }
    
    func loadCurrentCoins() {
        if let userId = UserDefaults.standard.string(forKey: "userIdentifier") {
            let db = Firestore.firestore()
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    self.currentCoins = data["coins"] as? Int ?? 0
                    print("💰 Aktuelle Münzen geladen: \(self.currentCoins)")
                } else if let error = error {
                    print("❌ Fehler beim Laden der Münzen: \(error.localizedDescription)")
                }
            }
        }
    }

    func loadPlayedGames() {
        if let userId = UserDefaults.standard.string(forKey: "userIdentifier") {
            let db = Firestore.firestore()
            db.collection("users").document(userId).getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    playedGamesStandard = data["playedGames_standard"] as? Int ?? 0
                    playedGamesErweitert = data["playedGames_erweitert"] as? Int ?? 0
                    print("✅ Gespielte Spiele geladen: Standard=\(playedGamesStandard), Erweitert=\(playedGamesErweitert)")
                } else if let error = error {
                    print("❌ Fehler beim Laden der gespielten Spiele: \(error.localizedDescription)")
                }
            }
        }
    }
    func checkForForcedUpdate() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        print("📱 Aktuelle App-Version: \(currentVersion)")
        
        let ref = Firestore.firestore().collection("appConfig").document("current")
        ref.getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let minVersion = data["minVersion"] as? String {
                if isVersion(currentVersion, lessThan: minVersion) {
                    requiredVersion = minVersion
                    showForceUpdateAlert = true
                }
            } else {
                print("❌ Fehler beim Laden der Mindestversion: \(error?.localizedDescription ?? "Unbekannt")")
            }
        }
    }

        
        func isVersion(_ current: String, lessThan required: String) -> Bool {
            let currentParts = current.split(separator: ".").compactMap { Int($0) }
            let requiredParts = required.split(separator: ".").compactMap { Int($0) }
            
            for i in 0..<max(currentParts.count, requiredParts.count) {
                let currentPart = i < currentParts.count ? currentParts[i] : 0
                let requiredPart = i < requiredParts.count ? requiredParts[i] : 0
                if currentPart < requiredPart { return true }
                if currentPart > requiredPart { return false }
            }
            return false
        }


    func loadTopUserScores() {
        Firestore.firestore().collection("users")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Fehler beim Laden der User-Topliste: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ Keine User-Dokumente gefunden")
                    return
                }

                var userAverages: [(name: String, average: Double)] = []

                for doc in documents {
                    let data = doc.data()
                    guard let username = data["username"] as? String,
                          let history = data["playerHistory"] as? [[String: Any]] else { continue }

                    let filteredHistory = history.filter { ($0["modus"] as? String) == (showExtended ? "erweitert" : "standard") }
                    let totalScore = filteredHistory.reduce(0) { $0 + ($1["score"] as? Int ?? 0) }
                    let gamesPlayed = filteredHistory.count
                    let average = gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : 0.0

                    userAverages.append((username, average))
                }

                topUserScores = userAverages.sorted { $0.average > $1.average }.prefix(5).map { $0 }
            }
    }

    func loadUsernameIfNeeded() {
        if playerName.isEmpty {
            if let userId = UserDefaults.standard.string(forKey: "userIdentifier") {
                let db = Firestore.firestore()
                db.collection("users").document(userId).getDocument { snapshot, error in
                    if let data = snapshot?.data(), let username = data["username"] as? String {
                        playerName = username
                        print("✅ Username aus Firestore nachgeladen: \(username)")
                    } else {
                        print("⚠️ Kein Username gefunden oder Fehler: \(error?.localizedDescription ?? "Unbekannt")")
                    }
                }
            } else {
                print("⚠️ Kein userIdentifier in UserDefaults gefunden")
            }
        } else {
            print("✅ Lokaler playerName gefunden: \(playerName)")
        }
    }
}




// MARK: - FirestoreManager Erweiterung
extension FirestoreManager {
    var isGameStarted: Bool {
        currentGame?.started == true
    }

    func resetJoinStatus() {
        joinError = nil
        joinSuccessful = false
    }

    func checkIfGameIsJoinableManual(gameId: String, completion: @escaping (Bool, String?) -> Void) {
        let ref = Firestore.firestore().collection("games").document(gameId)
        ref.getDocument { snapshot, error in
            if let data = snapshot?.data() {
                if let started = data["started"] as? Bool, started == true {
                    completion(false, "⚠️ Das Spiel wurde bereits gestartet. Kein Beitritt mehr möglich.")
                } else {
                    completion(true, nil)
                }
            } else {
                completion(false, "Lobby nicht gefunden.")
            }
        }
    }
}

