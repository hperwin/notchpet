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

    /// 6-char friend code from UUID
    static func friendCode(from id: String) -> String {
        String(id.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }
}
