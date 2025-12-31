import SwiftUI

struct SetupView: View {
    @EnvironmentObject var chipStore: NFCChipStore
    @EnvironmentObject var nfcManager: NFCManager

    @State private var showingNameAlert = false
    @State private var scannedChipId: String?
    @State private var chipName = ""

    // Use NFCManager's isScanning to prevent stuck UI
    private var isScanning: Bool {
        nfcManager.isScanning
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 15) {
                Image(systemName: "wave.3.forward.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)

                Text("Welcome to LemmeGo")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Focus better with NFC-powered phone locking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 15) {
                SetupStep(number: 1, text: "Get an NFC tag")
                SetupStep(number: 2, text: "Tap the button below to scan it")
                SetupStep(number: 3, text: "Use it to lock your phone anytime")
            }
            .padding()

            Spacer()

            VStack(spacing: 15) {
                Button(action: startScanning) {
                    HStack {
                        Image(systemName: "wave.3.right")
                        Text("Register Your First Tag")
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
                        Text("Hold your phone near the NFC tag...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = nfcManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .padding()
        .alert("Name Your Tag", isPresented: $showingNameAlert) {
            TextField("e.g., Work Focus", text: $chipName)
            Button("Cancel", role: .cancel) {
                scannedChipId = nil
                chipName = ""
            }
            Button("Save") {
                if let chipId = scannedChipId, !chipName.isEmpty {
                    chipStore.registerChip(id: chipId, name: chipName)
                }
                scannedChipId = nil
                chipName = ""
            }
        } message: {
            Text("Give your NFC tag a memorable name")
        }
    }

    private func startScanning() {
        nfcManager.startScanning { chipId in
            handleChipScanned(chipId)
        }
    }

    private func handleChipScanned(_ chipId: String) {
        scannedChipId = chipId
        chipName = "My Focus Tag"
        showingNameAlert = true
    }
}

struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Text(text)
                .font(.body)
        }
    }
}
