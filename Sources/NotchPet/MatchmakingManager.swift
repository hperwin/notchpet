import Foundation
import Supabase

final class MatchmakingManager {
    private let supabase = SupabaseManager.shared

    /// Ensure player exists in DB, create if not
    func ensurePlayer(party: [PokemonInstance]) async throws -> PlayerRecord {
        let id = Preferences.shared.playerId ?? UUID().uuidString
        Preferences.shared.playerId = id
        let name = Preferences.shared.playerName

        let entries = party.map { PartySnapshotEntry(pokemonId: $0.pokemonId, level: $0.level, moves: $0.moves) }
        let partyJSON = try JSONEncoder().encode(entries)
        let partyString = String(data: partyJSON, encoding: .utf8) ?? "[]"

        let upsertData = PlayerUpsert(
            id: id,
            displayName: name,
            partySnapshot: partyString,
            lastActive: ISO8601DateFormatter().string(from: Date())
        )

        let result: [PlayerRecord] = try await supabase.client
            .from("players")
            .upsert(upsertData)
            .select()
            .execute()
            .value

        guard let player = result.first else {
            throw MatchmakingError.playerCreationFailed
        }
        return player
    }

    /// Join matchmaking queue, poll for opponent
    func findMatch(player: PlayerRecord, party: [PokemonInstance]) async throws -> MatchFound {
        let entries = party.map { PartySnapshotEntry(pokemonId: $0.pokemonId, level: $0.level, moves: $0.moves) }
        let partyJSON = try JSONEncoder().encode(entries)
        let partyString = String(data: partyJSON, encoding: .utf8) ?? "[]"

        let queueData = QueueUpsert(
            playerId: player.id,
            eloRating: player.eloRating,
            partySnapshot: partyString
        )

        // Add to queue
        try await supabase.client
            .from("matchmaking_queue")
            .upsert(queueData)
            .execute()

        // Poll for match (every 2s, up to 30s)
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let candidates: [QueueEntry] = try await supabase.client
                .from("matchmaking_queue")
                .select()
                .neq("player_id", value: player.id)
                .gte("elo_rating", value: player.eloRating - 300)
                .lte("elo_rating", value: player.eloRating + 300)
                .order("queued_at")
                .limit(1)
                .execute()
                .value

            if let opponent = candidates.first {
                // Create battle
                let battleData = BattleInsert(
                    player1Id: player.id,
                    player2Id: opponent.playerId,
                    status: "active"
                )

                let battles: [BattleRecord] = try await supabase.client
                    .from("battles")
                    .insert(battleData)
                    .select()
                    .execute()
                    .value

                guard let battle = battles.first else { continue }

                // Remove both from queue
                try await supabase.client
                    .from("matchmaking_queue")
                    .delete()
                    .in("player_id", values: [player.id, opponent.playerId])
                    .execute()

                return MatchFound(
                    battleId: battle.id,
                    opponentId: opponent.playerId,
                    opponentParty: opponent.partySnapshot,
                    isPlayer1: true
                )
            }

            // Also check if someone created a battle with us
            let myBattles: [BattleRecord] = try await supabase.client
                .from("battles")
                .select()
                .eq("player2_id", value: player.id)
                .eq("status", value: "active")
                .limit(1)
                .execute()
                .value

            if let battle = myBattles.first {
                // Remove from queue
                try await supabase.client
                    .from("matchmaking_queue")
                    .delete()
                    .eq("player_id", value: player.id)
                    .execute()

                // Get opponent info
                let opponents: [QueueEntry] = try await supabase.client
                    .from("matchmaking_queue")
                    .select()
                    .eq("player_id", value: battle.player1Id ?? "")
                    .execute()
                    .value

                return MatchFound(
                    battleId: battle.id,
                    opponentId: battle.player1Id ?? "",
                    opponentParty: opponents.first?.partySnapshot ?? "[]",
                    isPlayer1: false
                )
            }
        }

        // Timeout — remove from queue
        try await supabase.client
            .from("matchmaking_queue")
            .delete()
            .eq("player_id", value: player.id)
            .execute()

        throw MatchmakingError.timeout
    }

    func cancelSearch(playerId: String) async throws {
        try await supabase.client
            .from("matchmaking_queue")
            .delete()
            .eq("player_id", value: playerId)
            .execute()
    }

    // MARK: - Friend Battles

    /// Create a battle room and wait for a friend to join using your friend code.
    func createFriendBattle(player: PlayerRecord) async throws -> String {
        let battles: [BattleRecord] = try await supabase.client
            .from("battles")
            .insert(FriendBattleInsert(
                player1Id: player.id,
                player2Id: nil,
                status: "waiting_friend"
            ))
            .select()
            .execute()
            .value

        guard let battle = battles.first else {
            throw MatchmakingError.playerCreationFailed
        }
        return battle.id
    }

    /// Join a friend's battle using their friend code.
    func joinFriendBattle(player: PlayerRecord, friendCode: String) async throws -> MatchFound {
        let waiting: [BattleRecord] = try await supabase.client
            .from("battles")
            .select()
            .eq("status", value: "waiting_friend")
            .execute()
            .value

        // Find the battle whose player1 ID matches the friend code
        guard let battle = waiting.first(where: { record in
            guard let p1Id = record.player1Id else { return false }
            let code = SupabaseManager.friendCode(from: p1Id)
            return code == friendCode.uppercased()
        }) else {
            throw MatchmakingError.noOpponent
        }

        // Update the battle to add player2 and set active
        try await supabase.client
            .from("battles")
            .update(BattleStatusUpdate(player2Id: player.id, status: "active"))
            .eq("id", value: battle.id)
            .execute()

        return MatchFound(
            battleId: battle.id,
            opponentId: battle.player1Id ?? "",
            opponentParty: "",
            isPlayer1: false
        )
    }

    /// Poll for a friend to join your battle room.
    func waitForFriend(battleId: String) async throws -> MatchFound {
        for _ in 0..<30 { // 60 seconds total (2s intervals)
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let battles: [BattleRecord] = try await supabase.client
                .from("battles")
                .select()
                .eq("id", value: battleId)
                .eq("status", value: "active")
                .execute()
                .value

            if let battle = battles.first, battle.player2Id != nil {
                return MatchFound(
                    battleId: battle.id,
                    opponentId: battle.player2Id ?? "",
                    opponentParty: "",
                    isPlayer1: true
                )
            }
        }

        // Cleanup the stale waiting battle
        try await supabase.client
            .from("battles")
            .delete()
            .eq("id", value: battleId)
            .execute()

        throw MatchmakingError.timeout
    }

    /// Cancel a pending friend battle.
    func cancelFriendBattle(battleId: String) async throws {
        try await supabase.client
            .from("battles")
            .delete()
            .eq("id", value: battleId)
            .execute()
    }

    /// Update ELO after battle
    func updateELO(playerId: String, opponentELO: Int, won: Bool) async throws {
        let players: [PlayerRecord] = try await supabase.client
            .from("players")
            .select()
            .eq("id", value: playerId)
            .execute()
            .value

        guard let player = players.first else { return }

        let expected = 1.0 / (1.0 + pow(10.0, Double(opponentELO - player.eloRating) / 400.0))
        let score = won ? 1.0 : 0.0
        let newELO = Int(Double(player.eloRating) + 32.0 * (score - expected))
        let newWins = player.wins + (won ? 1 : 0)
        let newLosses = player.losses + (won ? 0 : 1)

        let updateData = ELOUpdate(
            eloRating: newELO,
            wins: newWins,
            losses: newLosses
        )

        try await supabase.client
            .from("players")
            .update(updateData)
            .eq("id", value: playerId)
            .execute()
    }
}

struct MatchFound {
    let battleId: String
    let opponentId: String
    let opponentParty: String
    let isPlayer1: Bool
}

enum MatchmakingError: Error {
    case timeout
    case playerCreationFailed
    case noOpponent
}
