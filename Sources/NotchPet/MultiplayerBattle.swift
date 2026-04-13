import Foundation
import Supabase
import Realtime

/// Syncs battle moves between two players via Supabase Realtime broadcast.
final class MultiplayerBattle {
    let battleId: String
    let isPlayer1: Bool
    private let supabase = SupabaseManager.shared
    private var channel: RealtimeChannelV2?
    private var broadcastSubscription: RealtimeSubscription?

    var onOpponentMoved: ((Int) -> Void)?

    init(battleId: String, isPlayer1: Bool) {
        self.battleId = battleId
        self.isPlayer1 = isPlayer1
    }

    func connect() async {
        let channel = supabase.client.channel("battle:\(battleId)")

        let broadcastStream = channel.broadcastStream(event: "move")

        let isP1 = self.isPlayer1
        Task { [weak self] in
            for await message in broadcastStream {
                if let moveIndex = message["payload"]?.objectValue?["moveIndex"]?.intValue,
                   let fromP1 = message["payload"]?.objectValue?["isPlayer1"]?.boolValue,
                   fromP1 != isP1 {
                    let callback = self?.onOpponentMoved
                    let idx = moveIndex
                    await MainActor.run {
                        callback?(idx)
                    }
                }
            }
        }

        try? await channel.subscribeWithError()
        self.channel = channel
    }

    func sendMove(index: Int) async {
        let payload: JSONObject = [
            "moveIndex": .integer(index),
            "isPlayer1": .bool(isPlayer1)
        ]
        await channel?.broadcast(event: "move", message: payload)
    }

    func reportResult(winnerId: String) async throws {
        let updateData = BattleUpdate(
            status: "finished",
            winnerId: winnerId,
            finishedAt: ISO8601DateFormatter().string(from: Date())
        )

        try await supabase.client
            .from("battles")
            .update(updateData)
            .eq("id", value: battleId)
            .execute()
    }

    func disconnect() async {
        await channel?.unsubscribe()
    }
}
