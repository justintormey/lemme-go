import Foundation
import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings
import Combine
import UserNotifications

/// Why a lock session refused to start. Views render `message` verbatim.
enum LockStartFailure: String {
    case screenTimeNotAuthorized
    case invalidDuration
    case noAppsSelected
    case blockedAppsUnreadable

    var message: String {
        switch self {
        case .screenTimeNotAuthorized:
            return "Screen Time permission is required. Please enable it in Settings to use LemmeGo."
        case .invalidDuration:
            return "Set a lock duration first, or turn on Unlimited Duration."
        case .noAppsSelected:
            return "Choose at least one app to block before locking. Settings > Manage Blocked Apps."
        case .blockedAppsUnreadable:
            return "Your blocked-app list could not be read and needs to be set again. Settings > Manage Blocked Apps."
        }
    }
}

class LockManager: ObservableObject {
    @Published var currentSession: LockSession?
    @Published var isLocked = false
    /// Set whenever startLockSession/startRemoteLockSession returns false.
    @Published var lastStartFailure: LockStartFailure?

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

    /// Everything that must be true before a session is allowed to begin.
    ///
    /// Previously only Screen Time authorization was checked, so the app would happily
    /// commit to a full lock that enforced nothing: a zero-length session (which also
    /// crashed on `UNTimeIntervalNotificationTrigger`, whose interval must be > 0), or a
    /// session with no apps selected, which shows "Phone Locked" while blocking nothing.
    private func validateSessionStart(duration: TimeInterval, isUnlimited: Bool) -> LockStartFailure? {
        if !isUnlimited && duration < 1 {
            print("   ❌ Invalid duration: \(duration)s")
            return .invalidDuration
        }

        if #available(iOS 16.0, *) {
            guard let blockingManager = appBlockingManager, let store = blockedAppsStore else {
                return .screenTimeNotAuthorized
            }

            blockingManager.checkAuthorization()
            guard blockingManager.isAuthorized else {
                print("   ❌ Screen Time not authorized")
                return .screenTimeNotAuthorized
            }
            print("   ✅ Screen Time authorized")

            // Pick up any change made in the app picker since launch.
            store.reloadSelection()

            // Distinguish "the saved list could not be read" from "the user picked nothing".
            // Both leave hasBlockedApps false, but they need different messages and the
            // former must never be mistaken for an intentionally empty selection.
            if store.lastLoadFailed {
                print("   ❌ Blocked-app selection failed to load")
                return .blockedAppsUnreadable
            }
            guard store.hasBlockedApps else {
                print("   ❌ No apps selected to block")
                return .noAppsSelected
            }
        }

        return nil
    }

    /// Shared session start. `isRemote` distinguishes the "Lock Now" button from an NFC scan.
    private func beginSession(chipId: String, duration: TimeInterval, isUnlimited: Bool, isRemote: Bool) -> Bool {
        print("🔒 beginSession() called - \(isRemote ? "LOCK NOW" : "NFC LOCK")")
        print("   - chipId: \(chipId)")
        print("   - duration: \(duration)s")
        print("   - isUnlimited: \(isUnlimited)")

        if let failure = validateSessionStart(duration: duration, isUnlimited: isUnlimited) {
            lastStartFailure = failure
            return false
        }
        lastStartFailure = nil

        let session = LockSession(
            chipId: chipId,
            duration: duration,
            isRemoteActivated: isRemote,
            isUnlimited: isUnlimited
        )
        print("   📝 Created session: \(session.id)")
        currentSession = session
        saveSession()
        print("   💾 Session saved")
        startLock()
        print("   ⏰ Lock started (timer running)")

        // Shields first, so a shield failure is visible before the notification promises an unlock.
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            blockingManager.blockSelectedApps(store.selection)
            print("   🚫 Apps blocked (\(store.selection.applicationTokens.count) apps, \(store.selection.categoryTokens.count) categories)")
        }

        // Schedule unlock notification (skip for unlimited sessions, which have no end).
        if !isUnlimited {
            print("   🔔 Scheduling notification for \(duration)s")
            scheduleUnlockNotification(for: duration)
        } else {
            print("   ⏸️  Skipping notification (unlimited session)")
        }

        print("   ✅ beginSession() completed successfully")
        return true
    }

    func startLockSession(chipId: String, duration: TimeInterval, isUnlimited: Bool = false) -> Bool {
        beginSession(chipId: chipId, duration: duration, isUnlimited: isUnlimited, isRemote: false)
    }

    // Start a lock session without an NFC scan (remote activation).
    // Still requires a registered tag to unlock - hybrid approach.
    func startRemoteLockSession(chipId: String, duration: TimeInterval, isUnlimited: Bool = false) -> Bool {
        beginSession(chipId: chipId, duration: duration, isUnlimited: isUnlimited, isRemote: true)
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
        // Do NOT claim the apps are already unblocked. When this fires the app is usually
        // suspended, so no code has run to drop the shields yet; opening LemmeGo is what
        // actually clears them. See docs/QA-2026-09-02.md finding 2.
        content.body = "Your focus session has ended. Open LemmeGo to unblock your apps."
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
                // Deliberately does NOT end the session: that would make revoking Screen
                // Time a one-tap bypass of the commitment. Surface it instead so the lock
                // screen stops implying apps are still blocked.
                blockingManager.lastShieldResult = "⚠️ Screen Time access was turned off — apps are NOT blocked"
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
