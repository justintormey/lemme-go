import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var chipStore: NFCChipStore

    @State private var isScanning = false
    @State private var showEmergencyConfirm = false
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Phone Locked")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Stay focused")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }

                if let session = lockManager.currentSession {
                    VStack(spacing: 15) {
                        Text("Time Remaining")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Text(lockManager.formatTime(session.remainingTime))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        ProgressView(value: 1.0 - (session.remainingTime / session.duration))
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .padding(.horizontal, 40)
                    }

                    if let chip = chipStore.getChip(id: session.chipId) {
                        Text("Locked with: \(chip.name)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                VStack(spacing: 20) {
                    Button(action: startUnlockScan) {
                        HStack {
                            Image(systemName: "wave.3.right")
                            Text("Tap Chip to Unlock")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(15)
                    }
                    .disabled(isScanning)

                    if isScanning {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                            Text("Hold phone near your chip...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Button(action: { showEmergencyConfirm = true }) {
                        Text("Emergency Unlock")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .underline()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
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
