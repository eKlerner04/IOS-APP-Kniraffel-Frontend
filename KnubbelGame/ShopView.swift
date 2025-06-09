import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DiceSkin: Identifiable {
    let id = UUID()
    let name: String
    let price: Int
    let previewImage: String
    let skinKey: String
}

let availableSkins = [
    DiceSkin(name: "🎲 Klassisch", price: 0, previewImage: "skin_classic", skinKey: "skin_classic"),
    DiceSkin(name: "✨ Holo", price: 50, previewImage: "holo_preview", skinKey: "holo"),
    DiceSkin(name: "👑 Gold", price: 150, previewImage: "gold_preview", skinKey: "gold"),
    DiceSkin(name: "🔴 Rot", price: 200, previewImage: "rot_preview", skinKey: "rot"),
    DiceSkin(name: "🪵 Holz", price: 300, previewImage: "holz_preview", skinKey: "holz"),
    DiceSkin(name: "💍 Platin", price: 300, previewImage: "platin_preview", skinKey: "platin"),
    DiceSkin(name: "🦒 Kniraffel", price: 1000, previewImage: "kniraffel_preview", skinKey: "kniraffel"),
    DiceSkin(name: "⚽️ Duempeldorf", price: 1000, previewImage: "duempeldorf_preview", skinKey: "duempeldorf"),
    DiceSkin(name: "❤️ Love", price: -1, previewImage: "love_preview", skinKey: "love")



]

struct ShopView: View {
    @State private var currentCoins: Int = 0
    @State private var purchasedSkins: [String] = []
    @State private var selectedSkin: String = "skin_classic"
    @State private var cart: [DiceSkin] = []
    @State private var errorMessage: String? = nil
    @State private var showInfo: Bool = false
    @State private var foodAmountInCart: Int = 0


    let firestoreManager = FirestoreManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("🛒 Würfel-Skin")
                    .font(.largeTitle)
                    .bold()

                Text("🏦 Deine Münzen: \(currentCoins)")
                    .font(.headline)
                

                Button(action: { showInfo.toggle() }) {
                    Label("Wie bekomme ich Münzen?", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Stepper("🌾 Futter: \(foodAmountInCart)", value: $foodAmountInCart, in: 0...99)
                    Spacer()
                    Text("\(foodAmountInCart * 5) Münzen")
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)



                if showInfo {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("💡 Münzen verdienen")
                                .font(.title3)
                                .bold()
                                .padding(.bottom, 4)

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "trophy.fill").foregroundColor(.yellow)
                                Text("💰 Spiele mit Einsatz: Der Gewinner erhält den Pot aus allen Einsätzen!")
                                    .font(.body)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "star.fill").foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Bonusmünzen für hohe Scores (Standard-Modus):")
                                        .font(.body)
                                    ForEach(firestoreManager.bonusInfoLines(for: false), id: \.self) { line in
                                        Text(line).font(.caption).foregroundColor(.gray)
                                    }
                                }
                            }

                            Text("👉 Tipp: Im erweiterten Modus gelten noch höhere Bonus-Schwellen!")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .transition(.opacity)
                    }
                }

                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                List(availableSkins) { skin in
                    HStack {
                        Image(skin.previewImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading) {
                            Text(skin.name)
                                .font(.headline)
                            if purchasedSkins.contains(skin.skinKey) || skin.price == 0 {
                                Text("Freigeschaltet")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("\(skin.price) Münzen")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        if purchasedSkins.contains(skin.skinKey) || skin.price == 0 {
                            SkinSelectButton(isActive: selectedSkin == skin.skinKey) {
                                selectSkin(skin: skin)
                            }
                        } else if skin.price > 0 {
                            Button(action: {
                                toggleCart(skin: skin)
                            }) {
                                Text(cart.contains(where: { $0.id == skin.id }) ? "Entfernen" : "In Warenkorb")
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Text("🔒 Nur durch Freischalten")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !cart.isEmpty || foodAmountInCart > 0 {
                    VStack(spacing: 10) {
                        Text("🛍️ Warenkorb")
                            .font(.headline)

                        ForEach(cart) { skin in
                            Text("• \(skin.name) – \(skin.price) Münzen")
                        }

                        if foodAmountInCart > 0 {
                            Text("• 🌾 Futter × \(foodAmountInCart) – \(foodAmountInCart * 5) Münzen")
                        }

                        let totalCost = cart.map { $0.price }.reduce(0, +) + (foodAmountInCart * 5)

                        Text("Gesamt: \(totalCost) Münzen")
                            .bold()

                        Button("✅ Kaufen") {
                            buyCart(totalCost: totalCost)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }


                Spacer()
            }
            .padding()
            .navigationTitle("Shop")
            .onAppear {
                loadUserData()
            }
            .animation(.easeInOut, value: showInfo)
        }
    }

    func loadUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(userId)

        userRef.getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.currentCoins = data["coins"] as? Int ?? 0
                self.purchasedSkins = data["purchasedSkins"] as? [String] ?? []
                self.selectedSkin = data["selectedSkin"] as? String ?? "skin_classic"
                print("✅ User-Daten geladen: Coins=\(self.currentCoins)")
            } else if let error = error {
                print("❌ Fehler beim Laden der User-Daten: \(error.localizedDescription)")
            }
        }
    }
    
    func buyFood() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        if currentCoins < 10 {
            errorMessage = "❌ Nicht genug Münzen für Futter."
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        userRef.updateData([
            "coins": FieldValue.increment(Int64(-5))
        ]) { error in
            if let error = error {
                errorMessage = "❌ Fehler beim Bezahlen: \(error.localizedDescription)"
            } else {
                FirestoreManager().addItemToInventory(for: userId, item: "stroh")
                currentCoins -= 5
                errorMessage = nil
            }
        }
    }


    func toggleCart(skin: DiceSkin) {
        if let index = cart.firstIndex(where: { $0.id == skin.id }) {
            cart.remove(at: index)
        } else {
            cart.append(skin)
        }
    }

    func buyCart(totalCost: Int) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let skinIds = cart.filter { $0.price > 0 }.map { $0.skinKey }


        if totalCost > currentCoins {
            let missing = totalCost - currentCoins
            errorMessage = "❌ Nicht genug Münzen! Dir fehlen noch \(missing) Münzen."
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        var updatedPurchased = purchasedSkins + skinIds

        userRef.updateData([
            "coins": currentCoins - totalCost,
            "purchasedSkins": updatedPurchased
        ]) { error in
            if let error = error {
                errorMessage = "❌ Fehler beim Kauf: \(error.localizedDescription)"
            } else {
                self.currentCoins -= totalCost
                self.purchasedSkins = updatedPurchased
                self.cart = []
                self.errorMessage = nil

                if foodAmountInCart > 0 {
                    for _ in 0..<foodAmountInCart {
                        firestoreManager.addItemToInventory(for: userId, item: "stroh")
                    }
                    foodAmountInCart = 0
                }
            }
        }
    }


    func selectSkin(skin: DiceSkin) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = Firestore.firestore().collection("users").document(userId)

        userRef.updateData([
            "selectedSkin": skin.skinKey
        ]) { error in
            if let error = error {
                print("❌ Fehler beim Aktivieren: \(error.localizedDescription)")
                errorMessage = "❌ Fehler beim Aktivieren: \(error.localizedDescription)"
            } else {
                print("✅ Skin aktiviert")
                self.selectedSkin = skin.skinKey
                self.errorMessage = nil
            }
        }
    }
}

struct SkinSelectButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isActive ? "Aktiv" : "Auswählen")
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isActive ? Color.green : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: isActive ? Color.green.opacity(0.6) : Color.blue.opacity(0.6), radius: 4, x: 0, y: 2)
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }
}
