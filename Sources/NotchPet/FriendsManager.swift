import Foundation
import Supabase

// MARK: - Codable Models

struct PlayerRecord: Codable {
    let id: String
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct PlayerUpsert: Encodable {
    let id: String
    let displayName: String
    let lastActive: String
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case lastActive = "last_active"
    }
}

struct FriendRecord: Codable {
    let id: String
    let userId: String
    let friendId: String
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
    }
}

struct FriendInsert: Encodable {
    let userId: String
    let friendId: String
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case friendId = "friend_id"
    }
}

struct GiftRecord: Codable {
    let id: String
    let fromId: String
    let toId: String
    let fromName: String
    let treats: String
    let opened: Bool
    enum CodingKeys: String, CodingKey {
        case id
        case fromId = "from_id"
        case toId = "to_id"
        case fromName = "from_name"
        case treats, opened
    }
}

struct GiftInsert: Encodable {
    let fromId: String
    let toId: String
    let fromName: String
    let treats: String
    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case toId = "to_id"
        case fromName = "from_name"
        case treats
    }
}

struct GiftUpdate: Encodable {
    let opened: Bool
}

struct FriendRequestRecord: Codable {
    let id: String
    let fromId: String
    let toCode: String
    let fromName: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case id
        case fromId = "from_id"
        case toCode = "to_code"
        case fromName = "from_name"
        case status
    }
}

struct FriendRequestInsert: Encodable {
    let fromId: String
    let toCode: String
    let fromName: String
    enum CodingKeys: String, CodingKey {
        case fromId = "from_id"
        case toCode = "to_code"
        case fromName = "from_name"
    }
}

struct FriendRequestUpdate: Encodable {
    let status: String
}

// MARK: - Friend Info (for display)

struct FriendInfo {
    let playerId: String
    let displayName: String
    let friendCode: String
}

// MARK: - FriendsManager

final class FriendsManager {
    private let supabase = SupabaseManager.shared

    /// Ensure local player exists in Supabase
    func ensurePlayer() async throws -> PlayerRecord {
        let id = Preferences.shared.playerId ?? UUID().uuidString
        Preferences.shared.playerId = id
        let name = Preferences.shared.playerName

        let results: [PlayerRecord] = try await supabase.client
            .from("players")
            .upsert(PlayerUpsert(
                id: id,
                displayName: name,
                lastActive: ISO8601DateFormatter().string(from: Date())
            ))
            .select()
            .execute()
            .value

        return results.first ?? PlayerRecord(id: id, displayName: name)
    }

    /// Send a friend request by friend code
    func sendFriendRequest(toCode: String) async throws {
        guard let myId = Preferences.shared.playerId else { return }
        let myName = Preferences.shared.playerName

        try await supabase.client
            .from("friend_requests")
            .insert(FriendRequestInsert(
                fromId: myId,
                toCode: toCode.uppercased(),
                fromName: myName
            ))
            .execute()
    }

    /// Check for pending friend requests to me
    func checkIncomingRequests() async throws -> [FriendRequestRecord] {
        guard let myId = Preferences.shared.playerId else { return [] }
        let myCode = SupabaseManager.friendCode(from: myId)

        let requests: [FriendRequestRecord] = try await supabase.client
            .from("friend_requests")
            .select()
            .eq("to_code", value: myCode)
            .eq("status", value: "pending")
            .execute()
            .value

        return requests
    }

    /// Accept a friend request -- creates bidirectional friendship
    func acceptRequest(_ request: FriendRequestRecord) async throws {
        guard let myId = Preferences.shared.playerId else { return }

        // Create both directions
        try await supabase.client
            .from("friends")
            .insert(FriendInsert(userId: myId, friendId: request.fromId))
            .execute()

        try await supabase.client
            .from("friends")
            .insert(FriendInsert(userId: request.fromId, friendId: myId))
            .execute()

        // Mark request as accepted
        try await supabase.client
            .from("friend_requests")
            .update(FriendRequestUpdate(status: "accepted"))
            .eq("id", value: request.id)
            .execute()
    }

    /// Load my friends list
    func loadFriends() async throws -> [FriendInfo] {
        guard let myId = Preferences.shared.playerId else { return [] }

        let friendRecords: [FriendRecord] = try await supabase.client
            .from("friends")
            .select()
            .eq("user_id", value: myId)
            .execute()
            .value

        var friends: [FriendInfo] = []
        for record in friendRecords {
            let players: [PlayerRecord] = try await supabase.client
                .from("players")
                .select()
                .eq("id", value: record.friendId)
                .execute()
                .value

            if let player = players.first {
                friends.append(FriendInfo(
                    playerId: player.id,
                    displayName: player.displayName,
                    friendCode: SupabaseManager.friendCode(from: player.id)
                ))
            }
        }

        return friends
    }

    /// Send a gift (random berries) to a friend
    func sendGift(toFriendId: String) async throws {
        guard let myId = Preferences.shared.playerId else { return }
        let myName = Preferences.shared.playerName

        // Pick 3-5 random berries
        let allBerries = ["oran-berry", "sitrus-berry", "razz-berry", "cheri-berry",
                          "pecha-berry", "rawst-berry", "leppa-berry", "lum-berry"]
        let count = Int.random(in: 3...5)
        let picked = (0..<count).map { _ in allBerries.randomElement()! }
        let treatsJSON = try JSONEncoder().encode(picked)
        let treatsString = String(data: treatsJSON, encoding: .utf8) ?? "[]"

        try await supabase.client
            .from("gifts")
            .insert(GiftInsert(
                fromId: myId,
                toId: toFriendId,
                fromName: myName,
                treats: treatsString
            ))
            .execute()
    }

    /// Check for unopened gifts
    func checkGifts() async throws -> [GiftRecord] {
        guard let myId = Preferences.shared.playerId else { return [] }

        let gifts: [GiftRecord] = try await supabase.client
            .from("gifts")
            .select()
            .eq("to_id", value: myId)
            .eq("opened", value: false)
            .execute()
            .value

        return gifts
    }

    /// Mark a gift as opened
    func openGift(_ giftId: String) async throws {
        try await supabase.client
            .from("gifts")
            .update(GiftUpdate(opened: true))
            .eq("id", value: giftId)
            .execute()
    }
}
