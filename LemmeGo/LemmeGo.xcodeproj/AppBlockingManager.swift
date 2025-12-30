import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

@available(iOS 16.0, *)
class AppBlockingManager: ObservableObject {
    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    @Published var isAuthorized = false
    
    // Reference to the blocked apps store
    weak var blockedAppsStore: BlockedAppsStore?
    
    init() {
        // Check initial authorization status
        updateAuthorizationStatus()
    }
    
    /// Request authorization to use Screen Time API
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await MainActor.run {
                updateAuthorizationStatus()
            }
        } catch {
            print("Failed to request Screen Time authorization: \(error.localizedDescription)")
            await MainActor.run {
                updateAuthorizationStatus()
            }
        }
    }
    
    /// Update the authorization status
    private func updateAuthorizationStatus() {
        switch center.authorizationStatus {
        case .approved:
            isAuthorized = true
            print("✅ Screen Time authorized")
        case .denied:
            isAuthorized = false
            print("❌ Screen Time denied")
        case .notDetermined:
            isAuthorized = false
            print("⚠️ Screen Time not determined")
        @unknown default:
            isAuthorized = false
            print("❓ Screen Time unknown status")
        }
    }
    
    /// Block the apps selected by the user
    func blockSelectedApps() {
        guard isAuthorized else {
            print("❌ Cannot block apps: Not authorized")
            return
        }
        
        guard let selection = blockedAppsStore?.selection else {
            print("⚠️ No blocked apps store available")
            return
        }
        
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("⚠️ No apps selected to block")
            return
        }
        
        print("🔒 Blocking selected apps and categories...")
        
        // Apply shields to selected apps
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
            print("  • Blocking \(selection.applicationTokens.count) apps")
        }
        
        // Apply shields to selected categories
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            print("  • Blocking \(selection.categoryTokens.count) categories")
        }
        
        // Apply shields to selected web domains
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
            print("  • Blocking \(selection.webDomainTokens.count) web domains")
        }
        
        print("✅ App blocking enabled")
    }
    
    /// Block all apps except the specified bundle identifiers (legacy method)
    @available(*, deprecated, message: "Use blockSelectedApps() instead")
    func blockAllApps(except allowedBundles: [String]) {
        blockSelectedApps()
    }
    
    /// Unblock all apps
    func unblockAllApps() {
        print("🔓 Unblocking all apps...")
        
        // Clear all shields - this works even without authorization
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        
        print("✅ App blocking disabled")
    }
}
