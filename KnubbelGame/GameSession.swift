import Foundation
import FirebaseFirestore

struct GameSession: Codable, Identifiable {
    @DocumentID var id: String?
    var players: [String]
    var currentTurn: Int
    var dice: [Int]
    var isFinished: Bool
    var createdAt: Date
    var started: Bool
    var extraModus: Bool? // falls nicht vorhanden
    var host: String?
    var modus: String?
    var einsatzCoins: Int?  // optional für rückwärtskompatibel
    var ready: [String: Bool]? = nil
    var coinDistribution: [String: Int]? = nil
    var scoreBonuses: [String: Int]? // optional
    var einsatzBezahlt: Bool = false
    var rematchReady: [String: Bool]?

}
