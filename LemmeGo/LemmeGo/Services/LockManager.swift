import Foundation
import SwiftUI
import UIKit

class LockManager: ObservableObject {
    @Published var currentSession: LockSession?
    @Published var isLocked = false

    private var timer: Timer?
    private let sessionKey = "currentLockSession"

    init() {
        loadSession()
        if let session = currentSession, session.isActive {
            startLock()
        } else {
            currentSession = nil
            setAppIcon(to: nil)
        }
    }

    func startLockSession(chipId: String, duration: TimeInterval) {
        let session = LockSession(chipId: chipId, duration: duration)
        currentSession = session
        saveSession()
        startLock()
        setAppIcon(to: "AppIcon-Locked")
    }

    func endLockSession() {
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
