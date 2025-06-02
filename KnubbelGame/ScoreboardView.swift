import SwiftUI
import FirebaseFirestore

// Hilfsstruktur, um String als Identifiable zu verwenden
struct IdentifiableString: Identifiable, Hashable {
    let id: String
}

struct ScoreboardView: View {
    var firestore: FirestoreManager
    @State private var selectedPlayer: IdentifiableString? = nil
    @State private var playerScores: [String: [String: Int]] = [:]
    @State private var extraModus: Bool = false

    let upperSection = [
        "Nur Einser zählen", "Nur Zweier zählen", "Nur Dreier zählen",
        "Nur Vierer zählen", "Nur Fünfer zählen", "Nur Sechser zählen"
    ]

    let extendedCategories = [
        "1 Paar", "2 Paare", "3 Paare", "Zwei Drillinge"
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playerScores.keys), id: \.self) { player in
                    Button(action: {
                        selectedPlayer = IdentifiableString(id: player)
                    }) {
                        HStack {
                            Text(player)
                            Spacer()
                            let score = totalScore(for: player)
                            Text("\(score) Punkte")
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Punktetabelle")
            .onAppear {
                if let modus = firestore.currentGame?.modus {
                    extraModus = (modus == "erweitert")
                }
                fetchScores()
            }
            .sheet(item: $selectedPlayer) { identifiable in
                PlayerScoreDetailView(
                    playerName: identifiable.id,
                    scores: playerScores[identifiable.id] ?? [:],
                    extraModus: extraModus
                )
            }
        }
    }

    func fetchScores() {
        guard let gameId = firestore.currentGame?.id else { return }

        let ref = Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("rounds")

        ref.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }

            var scores: [String: [String: Int]] = [:]

            for doc in documents {
                let data = doc.data()
                guard let player = data["player"] as? String,
                      let category = data["category"] as? String,
                      let score = data["score"] as? Int else { continue }

                scores[player, default: [:]][category] = score
            }

            playerScores = scores
        }
    }

    func totalScore(for player: String) -> Int {
        let scores = playerScores[player] ?? [:]

        let upperScore = upperSection.map { scores[$0] ?? 0 }.reduce(0, +)
        let lowerScore = lowerSection.map { scores[$0] ?? 0 }.reduce(0, +)
        let bonus = upperScore >= (extraModus ? 108 : 63) ? 35 : 0

        return upperScore + bonus + lowerScore
    }
}
