import SwiftUI

struct PlayerScoreDetailView: View {
    var playerName: String
    var scores: [String: Int]
    
    
    //@AppStorage("extraModus") private var extraModus = false //alt
    
    var extraModus: Bool


    let upperSection = [
        ("Nur Einser zählen", "⚀"),
        ("Nur Zweier zählen", "⚁"),
        ("Nur Dreier zählen", "⚂"),
        ("Nur Vierer zählen", "⚃"),
        ("Nur Fünfer zählen", "⚄"),
        ("Nur Sechser zählen", "⚅")
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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🧾 Übersicht für \(playerName)")
                        .font(.title2)
                        .bold()

                    GroupBox(label: Text("🟦 Oberer Teil")) {
                        ForEach(upperSection, id: \.0) { (title, symbol) in
                            HStack {
                                Text("\(symbol) \(title)")
                                Spacer()
                                Text("\(scores[title] ?? 0)")
                                    .foregroundColor(scores[title] != nil ? .green : .gray)
                            }
                        }
                    }

                    GroupBox(label: Text("⬛️ Unterer Teil")) {
                        ForEach(lowerSection, id: \.self) { title in
                            HStack {
                                Text(title)
                                Spacer()
                                Text("\(scores[title] ?? 0)")
                                    .foregroundColor(scores[title] != nil ? .green : .gray)
                            }
                        }
                    }

                    Divider()

                    let total = scores.values.reduce(0, +)
                    HStack {
                        Text("🔢 Gesamtsumme")
                            .bold()
                        Spacer()
                        Text("\(total)")
                            .bold()
                    }
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
