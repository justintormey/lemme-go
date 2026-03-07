import Foundation
import FamilyControls
import ManagedSettings

@available(iOS 16.0, *)
class AppBlockingManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private let center = AuthorizationCenter.shared
    // Use a named ManagedSettingsStore for reliable persistence across app restarts.
    // The default (unnamed) store can behave inconsistently; a named store ensures
    // the shields survive process termination and relaunch.
    private let store = ManagedSettingsStore(named: .lemmego)

    init() {
        checkAuthorization()

        // Check again after a delay to ensure authorization status is fully loaded
        // This fixes an issue where authorization status may not be immediately available on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAuthorization()
        }
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch center.authorizationStatus {
        case .approved:
            isAuthorized = true
        case .denied:
            isAuthorized = false
            authorizationError = "Screen Time permission was denied. LemmeGo requires Screen Time access to function. Please enable it in Settings > Screen Time."
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                checkAuthorization()
            }
        } catch {
            await MainActor.run {
                authorizationError = "Failed to authorize: \(error.localizedDescription)"
                isAuthorized = false
            }
        }
    }

    // MARK: - App Blocking

    func blockSelectedApps(_ selection: FamilyActivitySelection) {
        // Always check authorization status before blocking (fixes race condition on app launch)
        checkAuthorization()

        guard isAuthorized else {
            authorizationError = "Not authorized for Screen Time. LemmeGo cannot function without this permission."
            print("❌ AppBlockingManager.blockSelectedApps: Not authorized")
            return
        }

        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        let webCount = selection.webDomainTokens.count

        print("🚫 AppBlockingManager.blockSelectedApps:")
        print("   Apps: \(appCount), Categories: \(catCount), Web domains: \(webCount)")

        if appCount == 0 && catCount == 0 && webCount == 0 {
            print("   ⚠️ Selection is empty — no shields will be applied")
            return
        }

        // Apply shields — set the tokens directly on the store's shield property.
        // ManagedSettingsStore persists these shields even if the app is terminated.
        if appCount > 0 {
            store.shield.applications = selection.applicationTokens
            print("   ✅ Set shield.applications (\(appCount) apps)")
        } else {
            store.shield.applications = nil
        }

        if catCount > 0 {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            print("   ✅ Set shield.applicationCategories (\(catCount) categories)")
        } else {
            store.shield.applicationCategories = nil
        }

        if webCount > 0 {
            store.shield.webDomains = selection.webDomainTokens
            print("   ✅ Set shield.webDomains (\(webCount) domains)")
        } else {
            store.shield.webDomains = nil
        }

        print("🚫 Shields applied successfully")
    }

    func unblockAllApps() {
        print("🔓 AppBlockingManager.unblockAllApps() called")
        // Clear all shields from the named store
        store.clearAllSettings()
        print("🔓 All settings cleared from named store!")
    }

    // MARK: - Diagnostics

    /// Returns true if the store currently has any shields applied
    var hasActiveShields: Bool {
        return store.shield.applications != nil ||
               store.shield.applicationCategories != nil ||
               store.shield.webDomains != nil
    }
}

// MARK: - Named Store

extension ManagedSettingsStore.Name {
    static let lemmego = ManagedSettingsStore.Name("LemmeGoShields")
}
