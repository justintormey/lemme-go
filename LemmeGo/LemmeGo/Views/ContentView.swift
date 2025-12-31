import SwiftUI
import FamilyControls

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

    // Use NFCManager's isScanning to prevent stuck UI
    private var isScanning: Bool {
        nfcManager.isScanning
    }

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
                Spacer()
                    .frame(height: 60)

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

                    Text("Phone Unlocked")
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
                        title: "Tap Tag to Lock",
                        icon: "wave.3.right.circle.fill",
                        action: startNFCScan,
                        isDisabled: isScanning
                    )
                    .padding(.horizontal, 24)

                    // Settings button
                    GlassButton(
                        title: "Settings",
                        icon: "gearshape.fill",
                        action: { showingSettings = true },
                        isDisabled: false
                    )
                    .padding(.horizontal, 24)

                    if isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Hold phone near tag...")
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

                    if let error = nfcManager.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: nfcManager.errorMessage) { error in
            // Clear error message after 5 seconds
            if error != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    nfcManager.errorMessage = nil
                }
            }
        }
    }

    private func startNFCScan() {
        nfcManager.startScanning { chipId in
            handleChipDetected(chipId)
        }
    }

    private func handleChipDetected(_ chipId: String) {
        if chipStore.isChipRegistered(id: chipId) {
            let success = lockManager.startLockSession(chipId: chipId, duration: selectedDuration)
            if !success {
                nfcManager.errorMessage = "Screen Time permission is required. Please enable it in Settings to use LemmeGo."
            }
        } else {
            nfcManager.errorMessage = "This tag is not registered. Please register it first in Settings."
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
    @EnvironmentObject var lockManager: LockManager
    @Environment(\.dismiss) var dismiss

    @State private var showingNameAlert = false
    @State private var newChipId: String?
    @State private var chipName = ""
    @State private var showingAppPicker = false
    @State private var permissionCheckTimer: Timer?

    // Use NFCManager's isScanning to prevent stuck UI
    private var isScanning: Bool {
        nfcManager.isScanning
    }

    var body: some View {
        NavigationView {
            ZStack {
                GlassBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Screen Time Permission Card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: lockManager.isScreenTimeAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                        .foregroundColor(lockManager.isScreenTimeAuthorized ? .green : .orange)
                                    Text("Screen Time Access")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Text(lockManager.isScreenTimeAuthorized 
                                    ? "App blocking is enabled" 
                                    : "Required for blocking apps during lock sessions")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if !lockManager.isScreenTimeAuthorized {
                                    Button {
                                        Task {
                                            await lockManager.requestScreenTimeAuthorization()
                                        }
                                    } label: {
                                        Text("Enable Screen Time")
                                            .font(.subheadline.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Blocked Apps Section
                        if #available(iOS 16.0, *) {
                            if lockManager.isScreenTimeAuthorized {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "hand.raised.fill")
                                                .foregroundColor(.blue)
                                            Text("Blocked Apps")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("Choose which apps to block during focus sessions")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Button {
                                            showingAppPicker = true
                                        } label: {
                                            Text("Manage Blocked Apps")
                                                .font(.subheadline.bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Registered chips section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Registered Tags")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            if chipStore.registeredChips.isEmpty {
                                GlassCard {
                                    Text("No tags registered")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 24)
                            } else {
                                List {
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
                                        .padding(.vertical, 4)
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.2))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                                .padding(.vertical, 4)
                                        )
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                chipStore.deleteChip(id: chip.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                                .frame(height: CGFloat(chipStore.registeredChips.count * 70))
                                .padding(.horizontal, 24)
                            }
                        }

                        // Add chip button
                        GlassButton(
                            title: "Register New Tag",
                            icon: "plus.circle.fill",
                            action: startRegisteringScan,
                            isDisabled: isScanning
                        )
                        .padding(.horizontal, 24)

                        if isScanning {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Scanning for tag...")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            refreshPermissions()
            // Check permissions every 2 seconds while settings is open
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refreshPermissions()
            }
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
        .onChange(of: showingAppPicker) { _ in
            // Refresh permissions when app picker is dismissed
            if !showingAppPicker {
                refreshPermissions()
            }
        }
        .alert("Name Your Tag", isPresented: $showingNameAlert) {
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
            Text("Give your NFC tag a memorable name")
        }
        .sheet(isPresented: $showingAppPicker) {
            if #available(iOS 16.0, *) {
                AppPickerView(lockManager: lockManager)
                    .environmentObject(lockManager)
            }
        }
    }

    private func startRegisteringScan() {
        nfcManager.startScanning { chipId in
            handleChipScanned(chipId)
        }
    }

    private func handleChipScanned(_ chipId: String) {
        if chipStore.isChipRegistered(id: chipId) {
            nfcManager.errorMessage = "This tag is already registered!"
        } else {
            newChipId = chipId
            chipName = "Tag \(chipStore.registeredChips.count + 1)"
            showingNameAlert = true
        }
    }

    private func refreshPermissions() {
        if #available(iOS 16.0, *), let appBlockingManager = lockManager.appBlockingManager {
            appBlockingManager.checkAuthorization()
        }
    }
}
