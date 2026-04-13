import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let url = URL(string: "https://parxkphysbvvvkiekkfu.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhcnhrcGh5c2J2dnZraWVra2Z1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDA4MDgsImV4cCI6MjA5MTY3NjgwOH0.GA0xKRHtLTBT35r-trv-YT4BPCqRjwhEprPoRJhjazA"
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    /// Generate a short 6-character friend code from a player UUID.
    static func friendCode(from playerId: String) -> String {
        let clean = playerId.replacingOccurrences(of: "-", with: "")
        return String(clean.prefix(6)).uppercased()
    }
}

// MARK: - Data Models

struct PlayerRecord: Codable {
    let id: String
    let displayName: String
    let eloRating: Int
    let wins: Int
    let losses: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case eloRating = "elo_rating"
        case wins, losses
    }
}

struct PartySnapshotEntry: Codable {
    let pokemonId: String
    let level: Int
    let moves: [String]
}

struct PlayerUpsert: Codable {
    let id: String
    let displayName: String
    let partySnapshot: String
    let lastActive: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case partySnapshot = "party_snapshot"
        case lastActive = "last_active"
    }
}

struct QueueUpsert: Codable {
    let playerId: String
    let eloRating: Int
    let partySnapshot: String

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case eloRating = "elo_rating"
        case partySnapshot = "party_snapshot"
    }
}

struct QueueEntry: Codable {
    let playerId: String
    let eloRating: Int
    let partySnapshot: String

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case eloRating = "elo_rating"
        case partySnapshot = "party_snapshot"
    }
}

struct BattleInsert: Codable {
    let player1Id: String
    let player2Id: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case status
    }
}

struct FriendBattleInsert: Codable {
    let player1Id: String
    let player2Id: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case status
    }
}

struct BattleStatusUpdate: Codable {
    let player2Id: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case player2Id = "player2_id"
        case status
    }
}

struct BattleRecord: Codable {
    let id: String
    let player1Id: String?
    let player2Id: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case status
    }
}

struct BattleUpdate: Codable {
    let status: String
    let winnerId: String
    let finishedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case winnerId = "winner_id"
        case finishedAt = "finished_at"
    }
}

struct ELOUpdate: Codable {
    let eloRating: Int
    let wins: Int
    let losses: Int

    enum CodingKeys: String, CodingKey {
        case eloRating = "elo_rating"
        case wins, losses
    }
}
