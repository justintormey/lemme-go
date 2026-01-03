import SwiftUI
import UserNotifications

@main
struct LemmeGoApp: App {
    @StateObject private var lockManager = LockManager()
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var chipStore = NFCChipStore()
    @StateObject private var emergencyTracker = EmergencyUnlockTracker()

    init() {
        // Request notification permissions for session end alerts
        requestNotificationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lockManager)
                .environmentObject(nfcManager)
                .environmentObject(chipStore)
                .environmentObject(emergencyTracker)
        }
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("⚠️ Notification permissions denied by user")
            }
        }
    }
}
