import SwiftUI
import FirebaseFirestore

struct ChatMessage: Identifiable {
    var id: String
    var sender: String
    var text: String
    var timestamp: Date

}


struct ChatView: View {
    let gameId: String
    let playerName: String

    @State private var newMessage = ""
    @State private var messages: [ChatMessage] = []

        
    var onNewMessage: ((ChatMessage) -> Void)? = nil

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            HStack {
                                if message.sender == playerName {
                                    Spacer()
                                    Text("🧍‍♂️ \(message.text)")
                                        .padding(8)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(10)
                                } else {
                                    Text("👤 \(message.sender): \(message.text)")
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(10)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            HStack {
                TextField("Nachricht...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Senden") {
                    sendMessage()
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .onAppear(perform: listenToMessages)
    }

    func sendMessage() {
        let ref = Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("chatMessages")
            .document()

        let data: [String: Any] = [
            "sender": playerName,
            "text": newMessage.trimmingCharacters(in: .whitespaces),
            "timestamp": Timestamp(date: Date())
        ]
        ref.setData(data)
        newMessage = ""
    }

    func listenToMessages() {
        Firestore.firestore()
            .collection("games")
            .document(gameId)
            .collection("chatMessages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }

                let newMessages = docs.map { doc in
                    ChatMessage(
                        id: doc.documentID,
                        sender: doc["sender"] as? String ?? "?",
                        text: doc["text"] as? String ?? "",
                        timestamp: (doc["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                messages = newMessages
            }
    }


}
