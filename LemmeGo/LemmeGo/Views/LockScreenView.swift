import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var chipStore: NFCChipStore

    @State private var isScanning = false
    @State private var showEmergencyConfirm = false
    @State private var currentTime = Date()
    @State private var pulse = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                Text("Stay focused")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)

                Spacer()
                    .frame(height: 60)

                // Timer display
                if let session = lockManager.currentSession {
                    GlassCard(isDark: true) {
                        VStack(spacing: 20) {
                            Text("Time Remaining")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            Text(lockManager.formatTime(session.remainingTime))
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()

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
                                }
                            }
                            .frame(height: 8)

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
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Controls
                VStack(spacing: 20) {
                    GlassButton(
                        title: "Tap Chip to Unlock",
                        icon: "wave.3.right.circle.fill",
                        action: startUnlockScan,
                        isDark: true,
                        isDisabled: isScanning
                    )
                    .padding(.horizontal, 24)

                    if isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Hold phone near your chip...")
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

                    Button(action: { showEmergencyConfirm = true }) {
                        Text("Emergency Unlock")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .underline()
                            .padding()
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
        .alert("Emergency Unlock", isPresented: $showEmergencyConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Unlock Now", role: .destructive) {
                lockManager.endLockSession()
            }
        } message: {
            Text("Are you sure you want to end this focus session early? This defeats the purpose of the lock.")
        }
    }

    private func startUnlockScan() {
        isScanning = true
        nfcManager.startScanning { chipId in
            handleUnlockChip(chipId)
        }
    }

    private func handleUnlockChip(_ chipId: String) {
        isScanning = false

        if let session = lockManager.currentSession, session.chipId == chipId {
            lockManager.endLockSession()
        } else if chipStore.isChipRegistered(id: chipId) {
            nfcManager.errorMessage = "Wrong chip! Use the chip that started this session."
        } else {
            nfcManager.errorMessage = "Unrecognized chip"
        }
    }
}
