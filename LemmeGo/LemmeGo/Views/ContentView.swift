import SwiftUI

struct ContentView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var chipStore: NFCChipStore

    var body: some View {
        Group {
            if lockManager.isLocked {
                LockScreenView()
            } else if chipStore.registeredChips.isEmpty {
                SetupView()
            } else {
                MainView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var lockManager: LockManager
    @EnvironmentObject var nfcManager: NFCManager
    @EnvironmentObject var chipStore: NFCChipStore

    @State private var selectedDuration: TimeInterval = 3600
    @State private var showingSettings = false
    @State private var isScanning = false

    let durations: [TimeInterval] = [
        900,    // 15 min
        1800,   // 30 min
        3600,   // 1 hour
        7200,   // 2 hours
        14400,  // 4 hours
        28800   // 8 hours
    ]

    var body: some View {
        ZStack {
            AnimatedMeshGradient()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("LemmeGo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                Spacer()

                // Main content
                VStack(spacing: 30) {
                    // Crystal icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.cyan.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.5), radius: 20)
                    }

                    Text("Focus Mode")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4)

                    // Duration card
                    GlassCard {
                        VStack(spacing: 16) {
                            Text("Lock Duration")
                                .font(.headline)
                                .foregroundColor(.white)

                            Picker("Duration", selection: $selectedDuration) {
                                ForEach(durations, id: \.self) { duration in
                                    Text(formatDuration(duration))
                                        .tag(duration)
                                        .foregroundColor(.white)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                    }
                    .padding(.horizontal, 24)

                    // NFC scan button
                    GlassButton(
                        title: "Tap NFC to Lock",
                        icon: "wave.3.right.circle.fill",
                        action: startNFCScan,
                        isDisabled: isScanning
                    )
                    .padding(.horizontal, 24)

                    if isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Hold phone near chip...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }

                Spacer()

                // Registered chips
                if !chipStore.registeredChips.isEmpty {
                    VStack(spacing: 12) {
                        Text("Registered Chips")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(chipStore.registeredChips) { chip in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle.hexagonpath.fill")
                                            .font(.caption)
                                            .foregroundColor(.cyan)
                                        Text(chip.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func startNFCScan() {
        isScanning = true
        nfcManager.startScanning { chipId in
            handleChipDetected(chipId)
        }
    }

    private func handleChipDetected(_ chipId: String) {
        isScanning = false

        if chipStore.isChipRegistered(id: chipId) {
            lockManager.startLockSession(chipId: chipId, duration: selectedDuration)
        } else {
            nfcManager.errorMessage = "This chip is not registered. Please register it first in Settings."
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes > 0 ? "\(minutes)m" : "")"
        } else {
            return "\(minutes)m"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var chipStore: NFCChipStore
    @EnvironmentObject var nfcManager: NFCManager
    @Environment(\.dismiss) var dismiss

    @State private var isScanning = false
    @State private var showingNameAlert = false
    @State private var newChipId: String?
    @State private var chipName = ""

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 30)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 30)

                ScrollView {
                    VStack(spacing: 20) {
                        // Registered chips section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Registered NFC Chips")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                if chipStore.registeredChips.isEmpty {
                                    Text("No chips registered")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                } else {
                                    ForEach(chipStore.registeredChips) { chip in
                                        HStack {
                                            Image(systemName: "circle.hexagonpath.fill")
                                                .foregroundColor(.cyan)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(chip.name)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.white)
                                                Text("ID: \(chip.id.prefix(16))...")
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Add chip button
                        GlassButton(
                            title: "Register New Chip",
                            icon: "plus.circle.fill",
                            action: startRegisteringScan,
                            isDisabled: isScanning
                        )
                        .padding(.horizontal, 24)

                        if isScanning {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Scanning for chip...")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding()
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                        }

                        // About section
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("About")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                HStack {
                                    Text("App Version")
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Text("1.0")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .alert("Name Your Chip", isPresented: $showingNameAlert) {
            TextField("e.g., Work Focus", text: $chipName)
            Button("Cancel", role: .cancel) {
                newChipId = nil
                chipName = ""
            }
            Button("Save") {
                if let chipId = newChipId, !chipName.isEmpty {
                    chipStore.registerChip(id: chipId, name: chipName)
                }
                newChipId = nil
                chipName = ""
            }
        } message: {
            Text("Give your NFC chip a memorable name")
        }
    }

    private func startRegisteringScan() {
        isScanning = true
        nfcManager.startScanning { chipId in
            handleChipScanned(chipId)
        }
    }

    private func handleChipScanned(_ chipId: String) {
        isScanning = false

        if chipStore.isChipRegistered(id: chipId) {
            nfcManager.errorMessage = "This chip is already registered!"
        } else {
            newChipId = chipId
            chipName = "Chip \(chipStore.registeredChips.count + 1)"
            showingNameAlert = true
        }
    }
}
