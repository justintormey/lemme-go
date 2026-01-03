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
            if session.isActive {
                // Session is still active - resume lock
                startLock()
            } else {
                // Session expired while app was closed - clean up properly!
                print("⚠️ Found expired session on app launch - cleaning up")
                endLockSession()
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

        // Check if session expired while app was backgrounded
        if let session = currentSession, !session.isActive {
            print("⚠️ Session expired while backgrounded - ending session")
            endLockSession()
        }
    }

    @objc private func handleAppDidEnterBackground() {
        print("📱 App entering background - session will continue")
        // Timer is automatically suspended by iOS
        // Session will be checked when app returns to foreground
    }

    func startLockSession(chipId: String, duration: TimeInterval) -> Bool {
        // Check Screen Time authorization before starting lock
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            // Always check current authorization status
            blockingManager.checkAuthorization()

            if !blockingManager.isAuthorized {
                // Permission was revoked - cannot lock
                return false
            }
        }

        let session = LockSession(chipId: chipId, duration: duration)
        currentSession = session
        saveSession()
        startLock()

        // Schedule unlock notification
        scheduleUnlockNotification(for: duration)

        // Block apps - this is REQUIRED functionality
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            if blockingManager.isAuthorized {
                // Use the user's selected apps from BlockedAppsStore
                if store.hasBlockedApps {
                    blockingManager.blockSelectedApps(store.selection)
                }
                // If no apps selected, user should configure in settings
            }
        }

        return true
    }

    // Start a lock session without NFC scan (remote activation)
    // Still requires NFC tag to unlock - hybrid approach
    func startRemoteLockSession(chipId: String, duration: TimeInterval) -> Bool {
        // Check Screen Time authorization
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            blockingManager.checkAuthorization()
            if !blockingManager.isAuthorized {
                return false
            }
        }

        // Create session with remote activation flag
        let session = LockSession(chipId: chipId, duration: duration, isRemoteActivated: true)
        currentSession = session
        saveSession()
        startLock()

        // Schedule unlock notification
        scheduleUnlockNotification(for: duration)

        // Block apps using Screen Time API
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager, let store = blockedAppsStore {
            if blockingManager.isAuthorized && store.hasBlockedApps {
                blockingManager.blockSelectedApps(store.selection)
            }
        }

        return true
    }

    func endLockSession() {
        // Cancel notification since session ended
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Unblock apps
        if #available(iOS 16.0, *), let blockingManager = appBlockingManager {
            blockingManager.unblockAllApps()
        }

        currentSession = nil
        isLocked = false
        timer?.invalidate()
        timer = nil
        clearSession()
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
        isLocked = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if let session = self.currentSession {
                if !session.isActive {
                    self.endLockSession()
                }
            }
        }
        // Add timer to common run loop mode so it fires during scrolling and other UI interactions
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
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
