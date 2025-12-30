import Foundation
import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings

// MARK: - Blocked Apps Store (iOS 16+)
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
            print("✅ Saved app selection")
        } catch {
            print("❌ Failed to save app selection: \(error.localizedDescription)")
        }
    }
    
    func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            print("ℹ️ No saved app selection found")
            return
        }
        
        do {
            selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            print("✅ Loaded app selection")
        } catch {
            print("❌ Failed to load app selection: \(error.localizedDescription)")
        }
    }
    
    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty || 
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }
}

// MARK: - App Blocking Manager (iOS 16+)
@available(iOS 16.0, *)
class AppBlockingManager: ObservableObject {
    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    @Published var isAuthorized = false
    
    // Reference to the blocked apps store
    weak var blockedAppsStore: BlockedAppsStore?
    
    init() {
        updateAuthorizationStatus()
    }
    
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
        
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
            print("  • Blocking \(selection.applicationTokens.count) apps")
        }
        
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            print("  • Blocking \(selection.categoryTokens.count) categories")
        }
        
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
            print("  • Blocking \(selection.webDomainTokens.count) web domains")
        }
        
        print("✅ App blocking enabled")
    }
    
    func unblockAllApps() {
        print("🔓 Unblocking all apps...")
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        print("✅ App blocking disabled")
    }
}

// MARK: - Lock Manager
class LockManager: ObservableObject {
    @Published var currentSession: LockSession?
    @Published var isLocked = false

    private var timer: Timer?
    private let sessionKey = "currentLockSession"

    // App blocking manager (only available on iOS 16+)
    @available(iOS 16.0, *)
    private lazy var appBlockingManager: AppBlockingManager = {
        let manager = AppBlockingManager()
        manager.blockedAppsStore = blockedAppsStore
        return manager
    }()
    
    // Blocked apps store (only available on iOS 16+)
    @available(iOS 16.0, *)
    private lazy var blockedAppsStore = BlockedAppsStore()

    init() {
        loadSession()
        if let session = currentSession, session.isActive {
            startLock()
        } else {
            currentSession = nil
            setAppIcon(to: nil)
        }
        
        // Request Screen Time authorization on launch
        Task {
            await requestScreenTimeAuthorization()
        }
    }

    func startLockSession(chipId: String, duration: TimeInterval) {
        let session = LockSession(chipId: chipId, duration: duration)
        currentSession = session
        saveSession()
        startLock()
        setAppIcon(to: "AppIcon-Locked")

        // Enable app blocking if available and authorized
        if #available(iOS 16.0, *) {
            if appBlockingManager.isAuthorized {
                appBlockingManager.blockSelectedApps()
            }
        }
    }

    func endLockSession() {
        // Unblock apps first
        if #available(iOS 16.0, *) {
            appBlockingManager.unblockAllApps()
        }

        currentSession = nil
        isLocked = false
        timer?.invalidate()
        timer = nil
        clearSession()
        setAppIcon(to: nil)
    }

    private func startLock() {
        isLocked = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if let session = self.currentSession {
                if !session.isActive {
                    self.endLockSession()
                }
            }
        }
    }

    // Request Screen Time authorization
    func requestScreenTimeAuthorization() async {
        if #available(iOS 16.0, *) {
            await appBlockingManager.requestAuthorization()
        }
    }

    // Check if Screen Time is authorized
    var isScreenTimeAuthorized: Bool {
        if #available(iOS 16.0, *) {
            return appBlockingManager.isAuthorized
        }
        return false
    }
    
    // Get the blocked apps store (iOS 16+)
    @available(iOS 16.0, *)
    func getBlockedAppsStore() -> BlockedAppsStore {
        return blockedAppsStore
    }

    private func setAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error setting app icon: \(error.localizedDescription)")
            }
        }
    }

    private func saveSession() {
        if let session = currentSession,
           let encoded = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(encoded, forKey: sessionKey)
        }
    }

    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(LockSession.self, from: data) {
            currentSession = session
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
