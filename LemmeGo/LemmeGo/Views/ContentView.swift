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
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("LemmeGo")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Focus Mode with NFC")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 15) {
                    Text("Lock Duration")
                        .font(.headline)

                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(durations, id: \.self) { duration in
                            Text(formatDuration(duration))
                                .tag(duration)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)

                Button(action: startNFCScan) {
                    HStack {
                        Image(systemName: "wave.3.right")
                        Text("Tap NFC Chip to Lock")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .disabled(isScanning)

                if isScanning {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("Hold phone near NFC chip...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Text("Registered Chips: \(chipStore.registeredChips.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(chipStore.registeredChips) { chip in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                            Text(chip.name)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
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
            return "\(hours)h \(minutes)m"
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
        NavigationView {
            List {
                Section(header: Text("Registered NFC Chips")) {
                    if chipStore.registeredChips.isEmpty {
                        Text("No chips registered")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(chipStore.registeredChips) { chip in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(chip.name)
                                    .font(.headline)
                                Text("ID: \(chip.id.prefix(16))...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteChips)
                    }
                }

                Section {
                    Button(action: startRegisteringScan) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Register New Chip")
                        }
                    }
                    .disabled(isScanning)

                    if isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 5)
                            Text("Scanning for chip...")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
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

    private func deleteChips(at offsets: IndexSet) {
        for index in offsets {
            let chip = chipStore.registeredChips[index]
            chipStore.deleteChip(id: chip.id)
        }
    }
}
