import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var chipStore: NFCChipStore
    @EnvironmentObject var emergencyTracker: EmergencyUnlockTracker

    @State private var currentTime = Date()
    @State private var pulse = false
    @State private var showingEmergencyUnlock = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Use NFCManager's isScanning instead of local state to prevent stuck UI
    private var isScanning: Bool {
        nfcManager.isScanning
    }

    var body: some View {
        ZStack {
            LockedBackground()

            VStack(spacing: 0) {
                Spacer()

                // Locked crystal icon
                ZStack {
                    // Pulsing glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.red.opacity(pulse ? 0.4 : 0.2),
                                    Color.purple.opacity(pulse ? 0.3 : 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: pulse ? 100 : 80
                            )
                        )
                        .frame(width: 180, height: 180)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.1, blue: 0.2),
                                    Color(red: 0.3, green: 0.05, blue: 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 45))
                                .foregroundColor(Color.red.opacity(0.9))
                        )
                        .shadow(color: .red.opacity(0.6), radius: 30)
                }
                .padding(.bottom, 20)

                Text("Phone Locked")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)

                Text("Avoid Distractions")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)

                Spacer()
                    .frame(height: 60)

                // Timer display
                if let session = lockManager.currentSession {
                    GlassCard(isDark: true) {
                        VStack(spacing: 20) {
                            if session.isUnlimited {
                                // Unlimited session display
                                HStack(spacing: 12) {
                                    Image(systemName: "infinity")
                                        .font(.title2)
                                        .foregroundColor(.cyan.opacity(0.8))
                                    Text("Unlimited Lock")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }

                                Text("∞")
                                    .font(.system(size: 80, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                    .shadow(color: .cyan.opacity(0.5), radius: 20)

                                Text("No automatic unlock")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 8)
                            } else {
                                // Timed session display
                                Text("Time Remaining")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))

                                Text(lockManager.formatTime(session.remainingTime))
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                    .id(currentTime) // Force refresh when currentTime updates

                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.2))
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.red, Color.purple, Color.orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(
                                                width: geometry.size.width * CGFloat(1.0 - (session.remainingTime / session.duration)),
                                                height: 8
                                            )
                                            .animation(.linear(duration: 1), value: currentTime)
                                    }
                                }
                                .frame(height: 8)
                            }

                            if let chip = chipStore.getChip(id: session.chipId) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.hexagonpath.fill")
                                        .font(.caption)
                                        .foregroundColor(.purple.opacity(0.8))
                                    Text("Locked with: \(chip.name)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.top, 8)
                            }

                            // Show indicator for remote locks
                            if session.isRemoteActivated {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue.opacity(0.8))
                                    Text("Remote Lock - NFC required to unlock")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Controls
                VStack(spacing: 20) {
                    GlassButton(
                        title: "Tap Tag to Unlock",
                        icon: "wave.3.right.circle.fill",
                        action: startUnlockScan,
                        isDark: true,
                        isDisabled: isScanning
                    )
                    .padding(.horizontal, 24)

                    // Emergency Unlock button
                    if emergencyTracker.canUseEmergencyUnlock {
                        GlassButton(
                            title: "Emergency Unlock (\(emergencyTracker.remainingUnlocks)/5)",
                            icon: "exclamationmark.triangle.fill",
                            action: { showingEmergencyUnlock = true },
                            isDark: true
                        )
                        .padding(.horizontal, 24)
                    }

                    if isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Hold phone near your tag...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            pulse = true
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .sheet(isPresented: $showingEmergencyUnlock) {
            EmergencyUnlockSheet()
                .environmentObject(lockManager)
                .environmentObject(emergencyTracker)
        }
    }

    private func startUnlockScan() {
        nfcManager.startScanning { chipId in
            handleUnlockChip(chipId)
        }
    }

    private func handleUnlockChip(_ chipId: String) {
        if let session = lockManager.currentSession, session.chipId == chipId {
            lockManager.endLockSession()
        } else if chipStore.isChipRegistered(id: chipId) {
            nfcManager.errorMessage = "Wrong tag! Use the tag that started this session."
        } else {
            nfcManager.errorMessage = "Unrecognized tag"
        }
    }
}
