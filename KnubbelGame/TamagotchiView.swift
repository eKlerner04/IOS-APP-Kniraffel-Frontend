import SwiftUI
import FirebaseFirestore
import FirebaseAuth

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


struct TamagotchiView: View {
    @State private var tamagotchi: [String: Any] = [:]
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var userId = Auth.auth().currentUser?.uid ?? ""
    @State private var showNameInput = false
    @State private var newName = ""
    @State private var animateBounce = false
    @State private var floatUp = false
    @State private var inventoryCounts: [String: Int] = [:]
    @State private var isSleeping = false
    @State private var sleepEndTime: Date?
    @State private var showSleepAlert = false
    @State private var feedbackMessage: String?
    @State private var sleepTimer: Timer?
    @State private var remainingSleepTime: Int = 0
    @State private var displayedEnergyProgress: Int = 0
    @State private var countedGamesToday: Int = 0
    @State private var giraffeName: String = ""
    @State private var showInfoSheet = false
    @State private var showRewardSheet = false
    @State private var sleepCompleted = false







    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Lade deine Giraffe...")
                } else if !errorMessage.isEmpty {
                    Text("❗️\(errorMessage)").foregroundColor(.red)
                } else if showNameInput {
                    VStack(spacing: 12) {
                        Text("Gib deiner Giraffe einen Namen:").font(.headline)
                        TextField("Giraffenname", text: $newName)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        Button("✅ Speichern") {
                            saveNewTamagotchi()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 12) {
                        Text("Level: \(getStat("level"))")
                            .font(.headline)
                            .padding(.top)

                        let xp = tamagotchi["xp"] as? Int ?? 0
                        let level = tamagotchi["level"] as? Int ?? 1
                        let xpThresholds = [50, 65, 84, 109, 142, 185, 241, 313, 407, 530, 689, 896, 1164, 1514, 1968, 2559, 3327, 4325, 5622, 7309]
                        let nextXP = xpThresholds[safe: level - 1] ?? 100

                        UnifiedProgressBar(label: "XP", value: xp * 100 / nextXP)

                        Image(giraffeImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .scaleEffect(animateBounce ? 1.1 : 1.0)
                            .offset(y: floatUp ? -5 : 5)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: floatUp)
                            .onAppear { floatUp.toggle() }

                        ZStack(alignment: .bottomTrailing) {
                            Text("\(giraffeName)")
                                .font(.largeTitle)
                                .bold()
                                .padding(.trailing, 20)
                                .onTapGesture {
                                    newName = giraffeName
                                    showNameInput = true
                                }

                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .background(Color.white.opacity(0.8).clipShape(Circle()))
                                .offset(x: -4, y: -4)
                        }

                        UnifiedProgressBar(label: "Hunger", value: getStat("hunger"))
                        UnifiedProgressBar(label: "Laune", value: getStat("happiness"))
                        UnifiedProgressBar(
                            label: "Energie",
                            value: getStat("energy"),
                            target: isSleeping ? min(100, getStat("energy") + 40) : nil
                        )

                        let straw = inventoryCounts["stroh", default: 0]
                        Label("Stroh: \(straw)", systemImage: "leaf")
                            .font(.subheadline)
                            .foregroundColor(straw > 0 ? .brown : .gray)

                        Text("Heute gewertete Spiele: \(countedGamesToday)/5")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            if straw > 0 && getStat("hunger") < 100 && !isSleeping {
                                Button("🌾 Füttern") {
                                    feedWithStraw()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(getStat("hunger") >= 100)
                            } else if getStat("hunger") >= 100 {
                                Text("🍽️ Satt").foregroundColor(.green)
                            } else {
                                Text("🌾 Kein Futter").foregroundColor(.gray)
                            }

                            let energy = getStat("energy")
                            if isSleeping {
                                Button("🚫 Aufwachen") {
                                    cancelSleep()
                                }
                            } else {
                                Button("🛌 Schlafen") {
                                    if energy >= 100 {
                                        feedbackMessage = "⚡️ Giraffe ist voll ausgeruht!"
                                    } else if getStat("hunger") < 30 {
                                        showSleepAlert = true
                                    } else {
                                        feedbackMessage = "+\(min(100 - energy, 40)) Energie nach Schlaf"
                                        startSleeping()
                                    }
                                }
                                .disabled(energy >= 100 || getStat("hunger") < 30)
                            }
                        }

                        if showSleepAlert {
                            Text("😵 Zu hungrig zum Schlafen!")
                                .font(.caption).foregroundColor(.red)
                        }

                        if isSleeping {
                            Text("💤 Schlafzeit: \(remainingSleepTime / 60) Min \(remainingSleepTime % 60) Sek")
                                .font(.footnote).foregroundColor(.blue)
                        }

                        if let message = feedbackMessage {
                            Text(message)
                                .font(.caption).foregroundColor(.green)
                                .transition(.opacity)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { feedbackMessage = nil }
                                    }
                                }
                        }
                    }
                    .sheet(isPresented: $showInfoSheet) {
                        InfoSheetView()
                    }
                    .sheet(isPresented: $showRewardSheet) {
                        RewardPathView()
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showRewardSheet = true
                    } label: {
                        Image(systemName: "map.fill")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }

            .onAppear {
                loadOrCreateTamagotchi()
                loadInventory()
                listenToTamagotchiUpdates()
            }
        }
    }


    var giraffeImage: String {
        if isSleeping { return "KniraffelSleep" }
        let hunger = getStat("hunger")
        let energy = getStat("energy")
        let happiness = getStat("happiness")

        if hunger <= 0 { return "KniraffelDead" }
        else if hunger < 30 { return "KniraffelHungrig" }
        else if energy < 20 { return "KniraffelMüde" }
        else if happiness >= 90 { return "KniraffelHappy" }
        else if happiness >= 60 { return "KniraffelNeutral" }
        else { return "KniraffelSad" }
    }

    func getStat(_ key: String, default defaultValue: Int = 0) -> Int {
        tamagotchi[key] as? Int ?? defaultValue
    }

    func startSleeping() {
        isSleeping = true
        sleepCompleted = false // <—
        sleepEndTime = Date().addingTimeInterval(30 * 60)
        tamagotchi["sleepEnd"] = Timestamp(date: sleepEndTime!)
        FirestoreManager().updateTamagotchi(for: userId, data: tamagotchi)
        startSleepCountdown()
    }


    func cancelSleep() {
        isSleeping = false
        sleepEndTime = nil
        sleepTimer?.invalidate()
        sleepTimer = nil
        tamagotchi.removeValue(forKey: "sleepEnd")
        FirestoreManager().updateTamagotchi(for: userId, data: tamagotchi)
    }

    func finishSleeping() {
        guard isSleeping, !sleepCompleted else { return }
        sleepCompleted = true // ⛔️ Nur 1× ausführen
        isSleeping = false
        sleepEndTime = nil

        sleepTimer?.invalidate()
        sleepTimer = nil

        let currentEnergy = getStat("energy")
        guard currentEnergy < 100 else { return }

        let newEnergy = min(currentEnergy + 40, 100)
        FirestoreManager().updateTamagotchiField(for: userId, key: "energy", value: newEnergy)
        tamagotchi["energy"] = newEnergy

        gainXP(10, source: "sleep-finished")
    }





    func startSleepCountdown() {
        guard sleepTimer == nil else {
            return
        }

        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let end = sleepEndTime else { return }
            let remaining = Int(end.timeIntervalSinceNow)
            let sleepDuration = 30 * 60
            let totalGain = 40

            self.remainingSleepTime = max(0, remaining)

            let secondsSlept = sleepDuration - remaining
            let gainedEnergy = min(Int(Double(totalGain) * (Double(secondsSlept) / Double(sleepDuration))), totalGain)
            let baseEnergy = getStat("energy")
            self.displayedEnergyProgress = min(100, baseEnergy + gainedEnergy)

            if remaining <= 0 {
                sleepTimer?.invalidate()
                sleepTimer = nil
                finishSleeping()
            }
        }
    }





    func loadOrCreateTamagotchi() {
        isLoading = true

        FirestoreManager().fetchTamagotchi(for: userId) { data in
            if let data = data {
                self.tamagotchi = data
                self.giraffeName = data["name"] as? String ?? "Giraffe"

                // 💤 Schlaf-Logik prüfen
                if let timestamp = data["sleepEnd"] as? Timestamp {
                    let endDate = timestamp.dateValue()
                    self.sleepEndTime = endDate

                    if Date() < endDate {
                        self.isSleeping = true
                        self.startSleepCountdown()
                    } else {
                        self.isSleeping = false
                        self.sleepEndTime = nil
                    }
                } else {
                    self.isSleeping = false
                    self.sleepEndTime = nil
                }

                self.applyTimeDecay()
                self.updateHappinessWithDecayFromGames()
            } else {
                self.showNameInput = true
                self.isLoading = false
            }
        }
    }

   




    func loadInventory() {
        FirestoreManager().fetchInventory(for: userId) { items in
            self.inventoryCounts = items
        }
    }
    
    func saveNewTamagotchi() {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        FirestoreManager().updateTamagotchiField(for: userId, key: "name", value: cleanName)
        self.giraffeName = cleanName // 🔁 Name aktualisieren
        self.showNameInput = false
    }


    func changeStat(_ stat: String, by amount: Int) {
        let currentValue = getStat(stat)
        let newValue = min(100, currentValue + amount)
        FirestoreManager().updateTamagotchiField(for: userId, key: stat, value: newValue)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            animateBounce.toggle()
        }
    }
    func applyTimeDecay() {
        guard let lastUpdatedTimestamp = tamagotchi["lastUpdated"] as? Timestamp else { return }
        let lastDate = lastUpdatedTimestamp.dateValue()
        let now = Date()
        let elapsedMinutes = Int(now.timeIntervalSince(lastDate) / 60)

        let hungerLoss = (elapsedMinutes / 60) * 5
        let happinessLoss = (elapsedMinutes / 60) * 3
        let energyLoss = (elapsedMinutes / 60) * 2

        let newHunger = max(0, getStat("hunger") - hungerLoss)
        let newHappiness = max(0, getStat("happiness") - happinessLoss)
        let newEnergy = max(0, getStat("energy") - energyLoss)

        FirestoreManager().updateTamagotchiField(for: userId, key: "hunger", value: newHunger)
        FirestoreManager().updateTamagotchiField(for: userId, key: "happiness", value: newHappiness)
        FirestoreManager().updateTamagotchiField(for: userId, key: "energy", value: newEnergy)

        // Lokal aktualisieren, damit UI direkt korrekt ist
        tamagotchi["hunger"] = newHunger
        tamagotchi["happiness"] = newHappiness
        tamagotchi["energy"] = newEnergy
    }


    func updateHappinessWithDecayFromGames() {
        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let history = data["playerHistory"] as? [[String: Any]] else {
                self.isLoading = false
                return
            }

            let now = Date()
            let calendar = Calendar.current
            let twentyFourHoursAgo = now.addingTimeInterval(-24 * 60 * 60)

            // A) Spiele der letzten 24h (für Laune)
            let recentGames = history.filter {
                if let timestamp = $0["date"] as? Timestamp {
                    return timestamp.dateValue() >= twentyFourHoursAgo
                }
                return false
            }

            // B) Spiele vom HEUTIGEN KALENDERTAG (für Anzeige)
            let todayGames = history.filter {
                if let timestamp = $0["date"] as? Timestamp {
                    return calendar.isDateInToday(timestamp.dateValue())
                }
                return false
            }

            // Anzeige aktualisieren
            self.countedGamesToday = todayGames.count
            print("📅 Spiele heute: \(todayGames.count)")

            // Laune berechnen
            var totalHappiness = 0
            for entry in recentGames {
                if let timestamp = entry["date"] as? Timestamp {
                    let hoursAgo = now.timeIntervalSince(timestamp.dateValue()) / 3600
                    let decayFactor = max(0, 1.0 - (hoursAgo / 24.0))
                    totalHappiness += Int(Double(20) * decayFactor)
                }
            }

            totalHappiness = min(totalHappiness, 100)
            FirestoreManager().updateTamagotchiField(for: userId, key: "happiness", value: totalHappiness)

            // (Optional) XP-Bonus – auskommentiert, Fokus liegt auf Anzeige
            
            let lastBonusDate = (data["tamagotchi"] as? [String: Any])?["lastXPBonusDate"] as? Timestamp
            let bonusAlreadyGivenToday = lastBonusDate != nil && calendar.isDate(lastBonusDate!.dateValue(), inSameDayAs: now)

            if recentGames.count >= 5 && !bonusAlreadyGivenToday {
                gainXP(20, source: "bonus-5-spiele")
                FirestoreManager().updateTamagotchiField(for: userId, key: "lastXPBonusDate", value: Timestamp(date: Date()))
                print("🎁 XP-Bonus vergeben")
            } else {
                print("ℹ️ XP-Bonus heute bereits erhalten oder nicht genug Spiele")
            }
            

            self.isLoading = false
        }
    }






    func feedWithStraw() {
        guard !isSleeping else {
            feedbackMessage = "😴 Giraffe schläft gerade!"
            return
        }

        FirestoreManager().removeItemFromInventory(for: userId, item: "stroh") { success in
            if success {
                let currentHunger = getStat("hunger")
                guard currentHunger < 100 else { return }

                let newHunger = min(currentHunger + 20, 100)

                // 🔄 Direkt in der UI aktualisieren:
                tamagotchi["hunger"] = newHunger

                FirestoreManager().updateTamagotchiField(for: userId, key: "hunger", value: newHunger)
                feedbackMessage = "+20 Hunger (Stroh)"
                loadInventory()
                gainXP(5, source: "feedwithStraw")
                SoundEffectManager.shared.playButtonSound()
            } else {
                errorMessage = "❌ Kein Stroh verfügbar"
            }
        }
    }


    func gainXP(_ amount: Int, source: String = "unbekannt") {
        print("⚙️ gainXP aufgerufen: \(amount) XP [Quelle: \(source)]")

        let currentXP = tamagotchi["xp"] as? Int ?? 0
        var newXP = currentXP + amount
        var currentLevel = tamagotchi["level"] as? Int ?? 1

        let xpThresholds = [50, 65, 84, 109, 142, 185, 241, 313, 407, 530, 689, 896, 1164, 1514, 1968, 2559, 3327, 4325, 5622, 7309]

        while currentLevel - 1 < xpThresholds.count && newXP >= xpThresholds[currentLevel - 1] {
            newXP -= xpThresholds[currentLevel - 1]
            currentLevel += 1
            FirestoreManager().addCoinsToPlayer(playerId: userId, coins: 10)
            feedbackMessage = "🎉 Level Up! Deine Kniraffel ist jetzt Level \(currentLevel)"
        }

        FirestoreManager().updateTamagotchiField(for: userId, key: "xp", value: newXP)
        FirestoreManager().updateTamagotchiField(for: userId, key: "level", value: currentLevel)

        tamagotchi["xp"] = newXP
        tamagotchi["level"] = currentLevel
    }
    
    func listenToTamagotchiUpdates() {
        Firestore.firestore().collection("users").document(userId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let tamagotchiData = data["tamagotchi"] as? [String: Any] else { return }

                self.tamagotchi = tamagotchiData

                if let name = tamagotchiData["name"] as? String {
                    self.giraffeName = name
                }

                if let timestamp = tamagotchiData["sleepEnd"] as? Timestamp {
                    let endDate = timestamp.dateValue()
                    self.sleepEndTime = endDate
                    if Date() < endDate {
                        self.isSleeping = true
                        self.startSleepCountdown()
                    } else {
                        self.isSleeping = false
                        self.sleepEndTime = nil
                    }
                } else {
                    self.isSleeping = false
                    self.sleepEndTime = nil
                }
            }
    }



    

}

struct ProgressBar: View {
    let label: String
    let value: Int

    var barColor: Color {
        if label == "Laune" {
            if value >= 80 { return .green }
            else if value >= 50 { return .yellow }
            else { return .red }
        }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(label): \(value)%")
            ProgressView(value: Float(value), total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: barColor))
        }
    }
}


struct EnergyProgressBar: View {
    let current: Int       // z. B. 60
    let target: Int        // z. B. 100
    var body: some View {
        VStack(alignment: .leading) {
            Text("Energie: \(current)%")
            ZStack(alignment: .leading) {
                // Hintergrundbalken
                RoundedRectangle(cornerRadius: 6)
                    .frame(height: 12)
                    .foregroundColor(Color(.systemGray5))

                // Aktueller Energie-Balken (blau)
                RoundedRectangle(cornerRadius: 6)
                    .frame(width: CGFloat(current) / 100 * 200, height: 12)
                    .foregroundColor(.blue)

                // Erwarteter Gesamtwert nach Schlaf (grün)
                if target > current {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: CGFloat(target) / 100 * 200, height: 12)
                        .foregroundColor(.green)
                        .opacity(0.4)
                }
            }
            .frame(width: 200)
        }
    }
}

struct UnifiedProgressBar: View {
    let label: String
    let value: Int          // aktueller Wert (0–100)
    var target: Int? = nil  // optional: geplanter Zielwert (z. B. für Schlaf)
    
    var baseColor: Color {
        switch label {
        case "Hunger": return .orange
        case "Laune":
            if value >= 80 { return .green }
            else if value >= 50 { return .yellow }
            else { return .red }
        case "Energie": return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(value)%")
                .font(.caption)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .frame(height: 12)
                    .foregroundColor(Color(.systemGray5))

                // Optionaler Zielwert (z. B. Schlaf)
                if let target, target > value {
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: CGFloat(target) / 100 * 200, height: 12)
                        .foregroundColor(baseColor.opacity(0.3))
                }

                // Aktueller Wert
                RoundedRectangle(cornerRadius: 6)
                    .frame(width: CGFloat(value) / 100 * 200, height: 12)
                    .foregroundColor(baseColor)
            }
            .frame(width: 200)
        }
    }
}
import SwiftUI

struct InfoSheetView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Kniraffel-Hilfe")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)

                    ForEach(infoSections, id: \.title) { section in
                        InfoCard(title: section.title, items: section.items)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InfoCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.title3.bold())
                Spacer()
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                        .padding(.top, 2)
                    Text(item)
                        .font(.callout)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

let infoSections: [(title: String, items: [String])] = [
    ("🌾 Füttern", [
        "Füttere deine Giraffe mit Stroh, um den Hunger zu senken.",
        "Ist sie satt (100 %), kann sie nicht mehr gefüttert werden.",
        "Du bekommst 5 XP pro Fütterung."
    ]),
    ("🛌 Schlafen", [
        "Schlaf regeneriert bis zu 40 Energiepunkte.",
        "Nur möglich, wenn Hunger > 30 % und Energie < 100 %.",
        "Gibt dir 10 XP nach dem Schlafen."
    ]),
    ("🎮 Spielen", [
        "Jedes gespielte Match erhöht deine Laune.",
        "Maximal 5 Spiele pro Tag werden gewertet.",
        "5 Spiele in 24 Stunden bringen zusätzlich 20 XP."
    ]),
    ("🏆 Level & XP", [
        "Du brauchst XP, um Level aufzusteigen.",
        "Jede Stufe braucht mehr XP als die vorherige.",
        "Bei jedem Level-Up bekommst du Münzen automatisch.",
        "Belohnungen kannst du im Belohnungspfad extra abholen."
    ]),
    ("💰 Münzen", [
        "Du bekommst Münzen durch Level-Ups.",
        "Nutze sie, um Skins, Stroh oder weitere Inhalte im Shop zu kaufen."
    ]),
    ("⏳ Zeitlicher Ablauf", [
        "Alle Werte verringern sich automatisch über Zeit – auch wenn du nicht spielst.",
        "• Hunger: alle 60 Minuten → -5 Punkte",
        "• Laune: alle 60 Minuten → -3 Punkte",
        "• Energie: alle 60 Minuten → -2 Punkte",
        "Halte deine Giraffe regelmäßig in Schuss, um sie glücklich zu halten!"
    ])
]


struct RewardPathView: View {
    @Environment(\.dismiss) var dismiss
    @State private var collected: [Int] = []
    @State private var level: Int = 1
    @State private var loading = true

    let userId = Auth.auth().currentUser?.uid ?? ""

    enum Reward: Identifiable {
        case coins(amount: Int)
        case skin(name: String)

        var id: String {
            switch self {
            case .coins(let amount): return "coins_\(amount)"
            case .skin(let name): return "skin_\(name)"
            }
        }

        var description: String {
            switch self {
            case .coins(let amount): return "💰 \(amount) Münzen"
            case .skin(let name): return "🎨 Skin: \(name.capitalized)"
            }
        }

        var icon: String {
            switch self {
            case .coins: return "bitcoinsign.circle.fill"
            case .skin: return "paintpalette.fill"
            }
        }

        var color: Color {
            switch self {
            case .coins: return .yellow
            case .skin: return .purple
            }
        }
    }

    let rewards: [Reward] = Array(1...20).map { lvl in
        if lvl == 20 {
            return .skin(name: "love")
        } else {
            return .coins(amount: 10 + (lvl - 1) * 5)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Belohnungspfad")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .padding(.horizontal)

                    ForEach(1...rewards.count, id: \.self) { lvl in
                        let reward = rewards[lvl - 1]
                        let isAvailable = lvl <= level
                        let isCollected = collected.contains(lvl)

                        HStack(spacing: 16) {
                            Image(systemName: reward.icon)
                                .foregroundColor(reward.color)
                                .font(.system(size: 30))
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Level \(lvl)")
                                    .font(.headline)
                                Text(reward.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isAvailable {
                                if isCollected {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                } else {
                                    Button("Abholen") {
                                        collectReward(for: lvl, reward: reward)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            } else {
                                Text("🔒")
                                    .font(.title2)
                                    .opacity(0.3)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Belohnungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear { loadStatus() }
        }
    }

    func loadStatus() {
        Firestore.firestore().collection("users").document(userId).getDocument { snap, error in
            let data = snap?.data() ?? [:]
            if let tamagotchi = data["tamagotchi"] as? [String: Any],
               let lvl = tamagotchi["level"] as? Int {
                self.level = lvl
            } else {
                self.level = 1
            }

            self.collected = data["collectedRewards"] as? [Int] ?? []
            self.loading = false
        }
    }

    func collectReward(for lvl: Int, reward: Reward) {
        switch reward {
        case .coins(let amount):
            FirestoreManager().addCoinsToPlayer(playerId: userId, coins: amount)
        case .skin(let name):
            FirestoreManager().addSkinToPlayer(playerId: userId, skin: name)
        }

        collected.append(lvl)
        Firestore.firestore().collection("users").document(userId)
            .updateData(["collectedRewards": collected])
    }
}
