import Foundation
import FamilyControls

@available(iOS 16.0, *)
class BlockedAppsStore: ObservableObject {
    @Published var selection = FamilyActivitySelection()

    private let selectionKey = "blockedAppsSelection_plist"
    private let legacySelectionKey = "blockedAppsSelection"

    init() {
        loadSelection()
    }

    func saveSelection() {
        do {
            // Use PropertyListEncoder — Apple's opaque token types (ApplicationToken,
            // CategoryToken, WebDomainToken) use NSKeyedArchiver internally and do not
            // round-trip reliably through JSONEncoder's Base64 encoding.
            let encoded = try PropertyListEncoder().encode(selection)
            UserDefaults.standard.set(encoded, forKey: selectionKey)
            print("💾 BlockedAppsStore: Saved selection — \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")
        } catch {
            print("❌ BlockedAppsStore: Failed to save selection — \(error.localizedDescription)")
        }
    }

    func loadSelection() {
        // Try the current plist key first
        if let data = UserDefaults.standard.data(forKey: selectionKey) {
            do {
                selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
                print("📂 BlockedAppsStore: Loaded selection — \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")
                return
            } catch {
                print("❌ BlockedAppsStore: Failed to decode plist selection — \(error.localizedDescription)")
            }
        }

        // Migrate from legacy JSON key if present
        if let data = UserDefaults.standard.data(forKey: legacySelectionKey) {
            do {
                selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
                print("📂 BlockedAppsStore: Migrated legacy JSON selection — \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")
                // Re-save with plist encoder and remove legacy key
                saveSelection()
                UserDefaults.standard.removeObject(forKey: legacySelectionKey)
                return
            } catch {
                print("❌ BlockedAppsStore: Failed to decode legacy JSON selection — \(error.localizedDescription)")
                // Remove corrupted legacy data
                UserDefaults.standard.removeObject(forKey: legacySelectionKey)
            }
        }

        print("📂 BlockedAppsStore: No saved selection found in UserDefaults")
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
