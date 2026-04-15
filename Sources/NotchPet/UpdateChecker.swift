import Foundation
import AppKit

final class UpdateChecker {
    static let currentVersion = "1.1.0"
    private static let versionURL = "https://raw.githubusercontent.com/hperwin/notchpet/main/VERSION"

    var onUpdateAvailable: ((String) -> Void)?  // passes the new version string

    /// Check GitHub for a newer version. Call on app launch.
    func checkForUpdate() {
        guard let url = URL(string: Self.versionURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let remoteVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            else { return }

            if remoteVersion != Self.currentVersion {
                DispatchQueue.main.async {
                    self?.onUpdateAvailable?(remoteVersion)
                }
            }
        }.resume()
    }
}
