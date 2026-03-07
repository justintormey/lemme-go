import Foundation
import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings
import Combine
import UserNotifications

class LockManager: ObservableObject {
    @Published var currentSession: LockSession?
    @Published var isLocked = false

    private var timer: Timer?
    private let sessionKey = "currentLockSession"

    // Make appBlockingManager internal so SettingsView can access it for permission checks
    @available(iOS 16.0, *)
    var appBlockingManager: AppBlockingManager?
    private var blockedAppsStore: BlockedAppsStore?
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🔧 LockManager init() called")

        // Initialize app blocking manager on iOS 16+
        if #available(iOS 16.0, *) {
            let manager = AppBlockingManager()
            appBlockingManager = manager
            blockedAppsStore = BlockedAppsStore()

            // Subscribe to AppBlockingManager's isAuthorized changes to trigger LockManager updates
            manager.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        }

        loadSession()
        if let session = currentSession {
            let now = Date()
            let endTime = session.endTime
            let isActive = session.isActive

            print("📊 Session found:")
            print("   - Start: \(session.startTime)")
            print("   - End: \(endTime)")
            print("   - Now: \(now)")
            print("   - IsActive: \(isActive)")
            print("   - Remaining: \(session.remainingTime)s")

            if session.isActive {
                // Session is still active - resume lock AND re-apply shields.
                // Shields may have been lost if the app was terminated.
                print("✅ Session still active - resuming lock and re-applying shields")
                startLock()
                reapplyShields()
            } else {
                // Session expired while app was closed - clean up properly!
                print("⚠️ Found expired session on app launch - cleaning up")
                endLockSession(isManualUnlock: false)  // Let notification fire (if not already fired)
            }
        } else {
            print("📊 No existing session found")
            // No active session — make sure shields are cleared (defensive cleanup)
            if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
                if blockingManager.hasActiveShields {
                    print("⚠️ Found stale shields with no active session — clearing")
                    blockingManager.unblockAllApps()
                }
            }
        }

        // Monitor app lifecycle events
        setupLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        timer = nil
    }

    private func setupLifecycleObservers() {
        // Check session when app comes to foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // Optional: Log when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleAppWillEnterForeground() {
        print("📱 App entering foreground - checking session status")

        if let session = currentSession {
            if !session.isActive {
                // Session expired while app was backgrounded
                print("⚠️ Session expired while backgrounded - ending session")
                endLockSession(isManualUnlock: false)  // Let notification fire (if not already fired)
            } else {
                // Session still active — re-apply shields in case they were lost
                // (iOS can clear ManagedSettings when the app is suspended for a long time)
                print("✅ Session still active — re-applying shields on foreground")
                reapplyShields()
            }
        }
    }

    @objc private func handleAppDidEnterBackground() {
        print("📱 App entering background - session will continue")
        // Timer is automatically suspended by iOS
        // Session will be checked when app returns to foreground
    }

    func startLockSession(chipId: String, duration: TimeInterval, isUnlimited: Bool = false) -> Bool {
        print("🔒 startLockSession() called - NFC LOCK")
        print("   - chipId: \(chipId)")
        print("   - duration: \(duration)s")
        print("   - isUnlimited: \(isUnlimited)")

        // Check Screen Time authorization before starting lock
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            // Always check current authorization status
            blockingManager.checkAuthorization()

            if !blockingManager.isAuthorized {
                print("   ❌ Screen Time not authorized")
                // Permission was revoked - cannot lock
                return false
            }
            print("   ✅ Screen Time authorized")
        }

        let session = LockSession(chipId: chipId, duration: duration, isUnlimited: isUnlimited)
        print("   📝 Created session: \(session.id)")
        currentSession = session
        saveSession()
        print("   💾 Session saved")
        startLock()
        print("   ⏰ Lock started (timer running)")

        // Schedule unlock notification (skip for unlimited sessions)
        if !isUnlimited {
            print("   🔔 Scheduling notification for \(duration)s")
            scheduleUnlockNotification(for: duration)
        } else {
            print("   ⏸️  Skipping notification (unlimited session)")
        }

        // Block apps - this is REQUIRED functionality.
        // Always reload the selection from UserDefaults to pick up any changes
        // the user made in the app picker since the app launched.
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            if blockingManager.isAuthorized {
                // Reload from UserDefaults to get the latest selection
                store.reloadSelection()
                if store.hasBlockedApps {
                    blockingManager.blockSelectedApps(store.selection)
                    print("   🚫 Apps blocked (\(store.selection.applicationTokens.count) apps, \(store.selection.categoryTokens.count) categories)")
                } else {
                    print("   ⚠️ No apps selected to block — user should configure in Settings")
                }
            } else {
                print("   ⚠️ Not authorized to block apps")
            }
        }

        print("   ✅ startLockSession() completed successfully")
        return true
    }

    // Start a lock session without NFC scan (remote activation)
    // Still requires NFC tag to unlock - hybrid approach
    func startRemoteLockSession(chipId: String, duration: TimeInterval, isUnlimited: Bool = false) -> Bool {
        print("🔒 startRemoteLockSession() called - LOCK NOW")
        print("   - chipId: \(chipId)")
        print("   - duration: \(duration)s")
        print("   - isUnlimited: \(isUnlimited)")

        // Check Screen Time authorization
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            blockingManager.checkAuthorization()
            if !blockingManager.isAuthorized {
                print("   ❌ Screen Time not authorized")
                return false
            }
            print("   ✅ Screen Time authorized")
        }

        // Create session with remote activation flag
        let session = LockSession(chipId: chipId, duration: duration, isRemoteActivated: true, isUnlimited: isUnlimited)
        print("   📝 Created session: \(session.id)")
        currentSession = session
        saveSession()
        print("   💾 Session saved")
        startLock()
        print("   ⏰ Lock started (timer running)")

        // Schedule unlock notification (skip for unlimited sessions)
        if !isUnlimited {
            print("   🔔 Scheduling notification for \(duration)s")
            scheduleUnlockNotification(for: duration)
        } else {
            print("   ⏸️  Skipping notification (unlimited session)")
        }

        // Block apps using Screen Time API.
        // Always reload the selection from UserDefaults to pick up any changes
        // the user made in the app picker since the app launched.
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            if blockingManager.isAuthorized {
                // Reload from UserDefaults to get the latest selection
                store.reloadSelection()
                if store.hasBlockedApps {
                    blockingManager.blockSelectedApps(store.selection)
                    print("   🚫 Apps blocked (\(store.selection.applicationTokens.count) apps, \(store.selection.categoryTokens.count) categories)")
                } else {
                    print("   ⚠️ No apps selected to block — user should configure in Settings")
                }
            } else {
                print("   ⚠️ Not authorized to block apps")
            }
        }

        print("   ✅ startRemoteLockSession() completed successfully")
        return true
    }

    func endLockSession(isManualUnlock: Bool = true) {
        print("🔓 endLockSession() called (manual: \(isManualUnlock))")

        // Only cancel notification for manual unlocks (NFC/emergency)
        // For automatic timer unlocks, let the notification fire
        if isManualUnlock {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            print("   ✅ Cancelled pending notifications (manual unlock)")
        } else {
            print("   ⏰ Keeping notification (automatic unlock - will fire)")
        }

        // Unblock apps
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            print("   🔓 Calling unblockAllApps()")
            blockingManager.unblockAllApps()
            print("   ✅ unblockAllApps() completed")
        } else {
            print("   ⚠️ AppBlockingManager not available")
        }

        currentSession = nil
        isLocked = false
        timer?.invalidate()
        timer = nil
        clearSession()
        print("   ✅ Session cleared, isLocked = false")
    }

    private func scheduleUnlockNotification(for duration: TimeInterval) {
        // Cancel any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "LemmeGo"
        content.body = "Your focus session has ended. Apps are now unlocked!"
        content.sound = .default
        content.categoryIdentifier = "UNLOCK"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: duration,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "session-unlock",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Unlock notification scheduled for \(duration) seconds")
            }
        }
    }

    private func startLock() {
        print("⏰ startLock() - Setting up timer")
        isLocked = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if let session = self.currentSession {
                if !session.isActive {
                    print("⏰ Timer detected session expired - auto-unlocking")
                    self.endLockSession(isManualUnlock: false)  // Let notification fire
                }
            }
        }
        // Add timer to common run loop mode so it fires during scrolling and other UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
            print("⏰ Timer created and added to RunLoop")
        } else {
            print("❌ Failed to create timer!")
        }
    }

    // MARK: - Shield Re-application

    /// Re-apply shields from the persisted BlockedAppsStore selection.
    /// Called on app resume/restart to ensure shields survive process termination.
    private func reapplyShields() {
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            blockingManager.checkAuthorization()
            guard blockingManager.isAuthorized else {
                print("⚠️ reapplyShields: Not authorized — cannot re-apply")
                return
            }
            // Always reload from UserDefaults to get the latest
            store.reloadSelection()
            if store.hasBlockedApps {
                blockingManager.blockSelectedApps(store.selection)
                print("🔄 reapplyShields: Shields re-applied (\(store.selection.applicationTokens.count) apps, \(store.selection.categoryTokens.count) categories)")
            } else {
                print("⚠️ reapplyShields: No apps in BlockedAppsStore — nothing to apply")
            }
        }
    }

    // Request Screen Time authorization - REQUIRED for app to function
    func requestScreenTimeAuthorization() async {
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            await blockingManager.requestAuthorization()
        }
    }

    // Check if Screen Time is authorized - REQUIRED for app to function
    var isScreenTimeAuthorized: Bool {
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            return blockingManager.isAuthorized
        }
        return false
    }

    // Get authorization error message if any
    var screenTimeError: String? {
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            return blockingManager.authorizationError
        }
        return "Screen Time API not available on this iOS version"
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

    // Get the blocked apps store
    @available(iOS 16.0, *)
    func getBlockedAppsStore() -> BlockedAppsStore {
        if let store = blockedAppsStore {
            return store
        }
        let store = BlockedAppsStore()
        blockedAppsStore = store
        return store
    }
}
