import Foundation
import FamilyControls

@available(iOS 16.0, *)
class BlockedAppsStore: ObservableObject {
    @Published var selection = FamilyActivitySelection()

    private let selectionKey = "blockedAppsSelection"

    init() {
        loadSelection()
    }

    func saveSelection() {
        do {
            let encoded = try JSONEncoder().encode(selection)
            UserDefaults.standard.set(encoded, forKey: selectionKey)
            print("💾 BlockedAppsStore: Saved selection — \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")
        } catch {
            print("❌ BlockedAppsStore: Failed to save selection — \(error.localizedDescription)")
        }
    }

    func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            print("📂 BlockedAppsStore: No saved selection found in UserDefaults")
            return
        }

        do {
            selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            print("📂 BlockedAppsStore: Loaded selection — \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")
        } catch {
            print("❌ BlockedAppsStore: Failed to decode selection — \(error.localizedDescription)")
        }
    }

    /// Reload the selection from UserDefaults to pick up any changes made since init.
    /// Call this before applying shields to ensure we have the latest user selection.
    func reloadSelection() {
        print("🔄 BlockedAppsStore: Reloading selection from UserDefaults")
        loadSelection()
    }

    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }
}
