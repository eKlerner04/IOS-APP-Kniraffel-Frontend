import SwiftUI
import FirebaseFirestore

struct LobbyView: View {
    @ObservedObject var firestore: FirestoreManager
    var playerName: String
    @Binding var isInGame: Bool

    @Environment(\.dismiss) var dismiss
    @AppStorage("extraModus") private var extraModus: Bool = false

    @State private var showModusSheet = false
    @State private var angezeigterModus: String = ""
    @State private var einsatzCheckMessage: String? = nil
    @State private var einsatzCheckSuccess: Bool = false
    @State private var currentCoins: Int = 0
    @State private var isReady: Bool = false
    @State private var countdown: Int? = nil
    @State private var countdownTimer: Timer? = nil

    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    var foregroundColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 30)

                if let game = firestore.currentGame {
                    VStack(spacing: 16) {
                        headerSection
                        coinInfoSection

                        RoundedRectangle(cornerRadius: 16)
                            .fill(foregroundColor.opacity(0.1))
                            .overlay(
                                VStack(spacing: 12) {
                                    modeSection(for: game)
                                    Divider().background(foregroundColor.opacity(0.4))
                                    Text("Spieler (\(game.players.count))")
                                        .font(.subheadline)
                                        .foregroundColor(foregroundColor)
                                    playersList(for: game)
                                }
                                .padding()
                            )
                            .frame(maxWidth: 350)

                        startButtonSection(for: game)

                        Button {
                            showModusSheet = true
                        } label: {
                            Text("⚙️ Spielmodus ändern")
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(foregroundColor.opacity(0.1))
                                .foregroundColor(foregroundColor)
                                .cornerRadius(10)
                        }
                        .frame(maxWidth: 250)
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView("Lade Lobby...")
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                }

                Spacer()
            }
        }
        .onAppear {
            if let modus = firestore.currentGame?.modus {
                angezeigterModus = modus
            }
        }
        .onChange(of: firestore.currentGame?.modus) { neuerModus in
            if let neuerModus = neuerModus {
                angezeigterModus = neuerModus
            }
        }
        .onChange(of: firestore.currentGame?.started) { started in
            if started == true {
                isInGame = true
            }
        }
        .onChange(of: firestore.currentGame?.ready) { _ in
            if let game = firestore.currentGame {
                let allReady = game.players.allSatisfy { game.ready?[$0] == true }
                if allReady {
                    startCountdown(for: game)
                } else {
                    cancelCountdown()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Label("Zurück", systemImage: "chevron.left")
                        .foregroundColor(foregroundColor)
                }
            }

            ToolbarItem(placement: .principal) {
                Text("LOBBY")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(foregroundColor)
            }
        }
        .sheet(isPresented: $showModusSheet) {
            ModusView()
                .environmentObject(firestore)
        }
    }

    var headerSection: some View {
        VStack {
            Text("CODE: \(firestore.currentGame?.id?.uppercased() ?? "UNBEKANNT")")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(foregroundColor)
                .padding(.top, 8)

            Button {
                if let code = firestore.currentGame?.id?.uppercased() {
                    UIPasteboard.general.string = code
                }
            } label: {
                Label("Code kopieren", systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .foregroundColor(foregroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(foregroundColor.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    var coinInfoSection: some View {
            if let userId = UserDefaults.standard.string(forKey: "userIdentifier") {
                return AnyView(
                    Text("🏦 Deine Münzen: **\(currentCoins)**")
                        .foregroundColor(foregroundColor)
                        .font(.subheadline)
                        .onAppear {
                            loadCurrentCoins(for: userId)
                        }
                )
            } else {
                return AnyView(EmptyView())
            }
        }

        func modeSection(for game: GameSession) -> some View {
            VStack(spacing: 4) {
                Text("🔧 Gespielt wird: **\(angezeigterModus.capitalized)**")
                    .foregroundColor(foregroundColor)
                    .font(.subheadline)

                if let einsatz = game.einsatzCoins {
                    Text("💰 Einsatz pro Spieler: **\(einsatz)** Münzen")
                        .foregroundColor(foregroundColor)
                        .font(.subheadline)

                    let pot = einsatz * (game.players.count)
                    Text("🏆 Aktueller Pot: **\(pot)** Münzen")
                        .foregroundColor(foregroundColor)
                        .font(.subheadline)

                    if let einsatzCheckMessage = einsatzCheckMessage {
                        Text(einsatzCheckMessage)
                            .font(.footnote)
                            .foregroundColor(einsatzCheckSuccess ? .green : .red)
                    }
                }
            }
        }

        func playersList(for game: GameSession) -> some View {
            VStack(spacing: 12) {
                let readyCount = Double(game.ready?.filter { $0.value == true }.count ?? 0)
                let totalCount = max(Double(game.players.count), 1)

                Text("✅ Bereit: \(Int(readyCount)) / \(Int(totalCount))")
                    .font(.headline)
                    .foregroundColor(.blue)

                ProgressView(value: readyCount, total: totalCount)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .padding(.horizontal)

                ForEach(game.players, id: \.self) { player in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(foregroundColor)
                        Text(player)
                            .foregroundColor(foregroundColor)
                            .bold()

                        Spacer()

                        if let readyDict = game.ready, readyDict[player] == true {
                            Text("✅")
                                .font(.title2)
                                .foregroundColor(.green)
                        } else {
                            Text("❌")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }


    func startButtonSection(for game: GameSession) -> some View {
            let allReady = game.players.allSatisfy { game.ready?[$0] == true }

            return VStack(spacing: 10) {
                if !game.started {
                    if let countdown = countdown {
                        Text("🎉 Alle bereit! Start in \(countdown)...")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else if allReady {
                        Text("🎉 Alle Spieler bereit!")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Text("⚠️ Warte, bis alle Spieler bereit sind...")
                            .foregroundColor(.orange)
                    }

                    Button(action: {
                        withAnimation(.spring()) {
                            isReady.toggle()
                            firestore.setPlayerReady(playerName: playerName, ready: isReady)
                        }
                    }) {
                        HStack {
                            Image(systemName: isReady ? "xmark.circle.fill" : "checkmark.circle.fill")
                            Text(isReady ? "Zurücknehmen" : "Bereit")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isReady ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: 300)
                }
            }
        }




    
    func startGameAutomatically(_ game: GameSession) {
        // Nur der Host darf das Spiel starten
        guard game.host == playerName else {
            print("⏳ Ich bin nicht der Host – warte auf Start durch \(game.host ?? "-")")
            return
        }

        let entryFee = game.einsatzCoins ?? 0

        if entryFee == 0 {
            firestore.startGame()
        } else {
            firestore.checkIfAllPlayersCanPay(entryFee: entryFee) { success, message in
                einsatzCheckMessage = message
                einsatzCheckSuccess = success

                if success {
                    firestore.startGame()
                } else {
                    print("❌ Nicht alle Spieler können zahlen: \(message ?? "Unbekannt")")
                }
            }
        }
    }



    
    func checkAndStartCountdown(game: GameSession) {
        let allReady = game.players.allSatisfy { game.ready?[$0] == true }
        if allReady && countdown == nil {
            startCountdown(for: game)
        } else if !allReady {
            cancelCountdown()
        }
    }

    func startCountdown(for game: GameSession) {
        if countdown != nil { return }  // schon laufend? Nicht doppelt starten

        countdown = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if let current = countdown, current > 1 {
                countdown = current - 1
            } else {
                timer.invalidate()
                countdownTimer = nil
                countdown = nil
                startGameAutomatically(game)
            }
        }
    }

    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = nil
    }



    // MARK: - Helpers

    func loadCurrentCoins(for userId: String) {
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
