import SwiftUI

struct EmergencyUnlockSheet: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var emergencyTracker: EmergencyUnlockTracker
    @Environment(\.dismiss) var dismiss

    @State private var budgetExhausted = false

    var body: some View {
        ZStack {
            LockedBackground()

            VStack(spacing: 24) {
                // Warning header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Emergency Unlock")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("\(emergencyTracker.remainingUnlocks) uses remaining this week")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)

                // Warning message
                GlassCard(isDark: true) {
                    Text("Using emergency unlock defeats the purpose of focus time. Use only for genuine emergencies.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.body)
                }
                .padding(.horizontal, 24)

                if budgetExhausted {
                    Text("You have used all 5 emergency unlocks this week. They reset on Monday.")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Buttons
                HStack(spacing: 16) {
                    GlassButton(
                        title: "Cancel",
                        icon: "xmark",
                        action: { dismiss() },
                        isDark: false
                    )

                    GlassButton(
                        title: "Unlock",
                        icon: "lock.open.fill",
                        action: performEmergencyUnlock,
                        isDark: true
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func performEmergencyUnlock() {
        guard let session = lockManager.currentSession else {
            dismiss()
            return
        }

        let success = emergencyTracker.recordEmergencyUnlock(
            sessionId: session.id,
            reason: nil
        )

        if success {
            lockManager.endLockSession()
            dismiss()
        } else {
            // The budget ran out between opening this sheet and tapping Unlock. Without
            // this the button silently did nothing and the sheet just sat there.
            budgetExhausted = true
        }
    }
}
