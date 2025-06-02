import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Charts




struct ProfileView: View {
    @State private var username: String = ""
    @State private var gamesPlayedStandard: Int = 0
    @State private var gamesPlayedErweitert: Int = 0
    @State private var totalScoreStandard: Int = 0
    @State private var totalScoreErweitert: Int = 0

    @State private var averageScoreStandard: Double = 0
    @State private var averageScoreErweitert: Double = 0
    @State private var isLoading = true
    @State private var scoreHistoryStandard: [ScoreEntry] = []
    @State private var scoreHistoryErweitert: [ScoreEntry] = []

    @State private var selectedStandardEntry: ScoreEntry? = nil
    @State private var selectedErweitertEntry: ScoreEntry? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("👤 Profil")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                if isLoading {
                    ProgressView("Lade Profil...")
                } else {
                    profileCard
                    statsGraph
                    scoreOverTimeGraph
                    Spacer()
                }
            }
            .padding()
        }
        .onAppear {
            loadUserProfile()
            loadScoreHistory { standardEntries, erweitertEntries in
                self.scoreHistoryStandard = standardEntries
                self.scoreHistoryErweitert = erweitertEntries
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameDidUpdate)) { _ in
            print("🔄 Empfange Update → lade Profil neu")
            loadUserProfile()
            loadScoreHistory { standardEntries, erweitertEntries in
                self.scoreHistoryStandard = standardEntries
                self.scoreHistoryErweitert = erweitertEntries
            }
        }


    }

    var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text(username.isEmpty ? "Nicht gesetzt" : username)
                        .font(.title2)
                        .bold()
                    Text("Kniraffel-Mitglied seit 2025")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Standard")
                        .font(.headline)
                    Text("\(gamesPlayedStandard) Spiele")
                    Text("Ø \(String(format: "%.1f", averageScoreStandard)) Punkte/Spiel")
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Erweitert")
                        .font(.headline)
                    Text("\(gamesPlayedErweitert) Spiele")
                    Text("Ø \(String(format: "%.1f", averageScoreErweitert)) Punkte/Spiel")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    var statsGraph: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Punktevergleich")
                .font(.headline)
                .padding(.bottom, 4)

            Chart {
                BarMark(
                    x: .value("Modus", "Standard"),
                    y: .value("Punkte", totalScoreStandard)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top) {
                    Text("\(totalScoreStandard)")
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(4)
                }

                BarMark(
                    x: .value("Modus", "Erweitert"),
                    y: .value("Punkte", totalScoreErweitert)
                )
                .foregroundStyle(.purple)
                .annotation(position: .top) {
                    Text("\(totalScoreErweitert)")
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .shadow(radius: 4)
        }
    }


    var scoreOverTimeGraph: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("📈 Spielverlauf über Zeit").font(.headline)

            if scoreHistoryStandard.isEmpty && scoreHistoryErweitert.isEmpty {
                Text("Keine Daten verfügbar")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                if !scoreHistoryStandard.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Standard-Modus").font(.subheadline)
                        Chart {
                            ForEach(Array(scoreHistoryStandard.enumerated()), id: \.element.id) { index, entry in
                                LineMark(
                                    x: .value("Spiel", index + 1),
                                    y: .value("Punkte", entry.score)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(.blue)

                                PointMark(
                                    x: .value("Spiel", index + 1),
                                    y: .value("Punkte", entry.score)
                                )
                                .symbolSize(40)
                            }

                            if let selected = selectedStandardEntry,
                               let selectedIndex = scoreHistoryStandard.firstIndex(where: { $0.id == selected.id }) {
                                PointMark(
                                    x: .value("Spiel", selectedIndex + 1),
                                    y: .value("Punkte", selected.score)
                                )
                                .symbolSize(100)
                                .foregroundStyle(.red)
                                .annotation(position: .top) {
                                    VStack(spacing: 4) {
                                        Text("\(selected.score) Punkte")
                                        Text(selected.date, style: .date)
                                    }
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)
                                }
                            }
                        }

                        
                        
                        .frame(height: 200)
                        .chartYAxis {
                            
                            AxisMarks(position: .leading)
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle().fill(Color.clear).contentShape(Rectangle())
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let location = value.location
                                                if let index: Int = proxy.value(atX: location.x) {
                                                    let clampedIndex = max(0, min(scoreHistoryStandard.count - 1, Int(round(Double(index) - 1))))
                                                    selectedStandardEntry = scoreHistoryStandard[clampedIndex]
                                                }
                                            }
                                    )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                if !scoreHistoryErweitert.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Erweiterter Modus").font(.subheadline)
                            Chart {
                                ForEach(Array(scoreHistoryErweitert.enumerated()), id: \.element.id) { index, entry in
                                    LineMark(
                                        x: .value("Spiel", index + 1),
                                        y: .value("Punkte", entry.score)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.purple)

                                    PointMark(
                                        x: .value("Spiel", index + 1),
                                        y: .value("Punkte", entry.score)
                                    )
                                    .symbolSize(40)
                                    .foregroundStyle(.purple)
                                }

                                if let selected = selectedErweitertEntry,
                                   let selectedIndex = scoreHistoryErweitert.firstIndex(where: { $0.id == selected.id }) {
                                    PointMark(
                                        x: .value("Spiel", selectedIndex + 1),
                                        y: .value("Punkte", selected.score)
                                    )
                                    .symbolSize(100)
                                    .foregroundStyle(.red)
                                    .annotation(position: .top) {
                                        VStack(spacing: 4) {
                                            Text("\(selected.score) Punkte")
                                            Text(selected.date, style: .date)
                                        }
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.white)
                                        .cornerRadius(6)
                                        .shadow(radius: 2)
                                    }
                                }
                            }
                            
                            
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                            
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle().fill(Color.clear).contentShape(Rectangle())
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let location = value.location
                                                if let index: Int = proxy.value(atX: location.x) {
                                                    let clampedIndex = max(0, min(scoreHistoryErweitert.count - 1, Int(round(Double(index) - 1))))
                                                    selectedErweitertEntry = scoreHistoryErweitert[clampedIndex]
                                                }
                                            }
                                    )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    func loadUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ Kein angemeldeter User")
            return
        }

        let userDoc = Firestore.firestore().collection("users").document(uid)
        userDoc.getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.username = data["username"] as? String ?? ""

                if let history = data["playerHistory"] as? [[String: Any]] {
                    let standardGames = history.filter { $0["modus"] as? String == "standard" }
                    let erweitertGames = history.filter { $0["modus"] as? String == "erweitert" }

                    self.gamesPlayedStandard = standardGames.count
                    self.gamesPlayedErweitert = erweitertGames.count

                    self.totalScoreStandard = standardGames.reduce(0) { $0 + ($1["score"] as? Int ?? 0) }
                    self.totalScoreErweitert = erweitertGames.reduce(0) { $0 + ($1["score"] as? Int ?? 0) }

                    self.averageScoreStandard = self.gamesPlayedStandard > 0 ? Double(self.totalScoreStandard) / Double(self.gamesPlayedStandard) : 0
                    self.averageScoreErweitert = self.gamesPlayedErweitert > 0 ? Double(self.totalScoreErweitert) / Double(self.gamesPlayedErweitert) : 0
                } else {
                    print("⚠️ Keine playerHistory gefunden oder leer")
                    self.gamesPlayedStandard = 0
                    self.gamesPlayedErweitert = 0
                    self.totalScoreStandard = 0
                    self.totalScoreErweitert = 0
                    self.averageScoreStandard = 0
                    self.averageScoreErweitert = 0
                }
            } else {
                print("❌ Fehler beim Laden: \(error?.localizedDescription ?? "Unbekannter Fehler")")
            }
            self.isLoading = false
        }
    }


    func loadScoreHistory(completion: @escaping ([ScoreEntry], [ScoreEntry]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ Kein angemeldeter User")
            completion([], [])
            return
        }

        let userDoc = Firestore.firestore().collection("users").document(uid)
        userDoc.getDocument { snapshot, error in
            var standardEntries: [ScoreEntry] = []
            var erweitertEntries: [ScoreEntry] = []

            if let data = snapshot?.data(),
               let history = data["playerHistory"] as? [[String: Any]] {

                for entry in history {
                    guard let timestamp = entry["date"] as? Timestamp,
                          let score = entry["score"] as? Int,
                          let modus = entry["modus"] as? String else { continue }

                    let scoreEntry = ScoreEntry(date: timestamp.dateValue(), score: score, modus: modus)

                    if modus == "standard" {
                        standardEntries.append(scoreEntry)
                    } else if modus == "erweitert" {
                        erweitertEntries.append(scoreEntry)
                    }
                }

                // Sortiere nach Datum (falls du es schön chronologisch haben willst)
                standardEntries.sort { $0.date < $1.date }
                erweitertEntries.sort { $0.date < $1.date }
            } else {
                print("⚠️ Keine playerHistory-Daten gefunden oder Fehler: \(error?.localizedDescription ?? "Unbekannt")")
            }

            completion(standardEntries, erweitertEntries)
        }
    }

}

struct ScoreEntry: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
    let modus: String
}
