import SwiftUI
import FamilyControls

@available(iOS 16.0, *)
struct AppPickerView: View {
    @EnvironmentObject var lockManager: LockManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var blockedAppsStore: BlockedAppsStore
    @State private var isPresented = false
    
    init(lockManager: LockManager) {
        _blockedAppsStore = StateObject(wrappedValue: lockManager.getBlockedAppsStore())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                GlassBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Instruction card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("How it works")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }

                                Text("Select which apps and websites you want to block during focus sessions. These will be unavailable when your phone is locked with NFC.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 24)

                        // Selection summary
                        if blockedAppsStore.hasBlockedApps {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "checkmark.shield.fill")
                                            .foregroundColor(.green)
                                        Text("Blocked Items")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        if !blockedAppsStore.selection.applicationTokens.isEmpty {
                                            HStack {
                                                Image(systemName: "app.badge.fill")
                                                    .foregroundColor(.cyan)
                                                Text("\(blockedAppsStore.selection.applicationTokens.count) apps")
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                            .font(.subheadline)
                                        }

                                        if !blockedAppsStore.selection.categoryTokens.isEmpty {
                                            HStack {
                                                Image(systemName: "square.grid.2x2.fill")
                                                    .foregroundColor(.purple)
                                                Text("\(blockedAppsStore.selection.categoryTokens.count) categories")
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                            .font(.subheadline)
                                        }

                                        if !blockedAppsStore.selection.webDomainTokens.isEmpty {
                                            HStack {
                                                Image(systemName: "globe")
                                                    .foregroundColor(.orange)
                                                Text("\(blockedAppsStore.selection.webDomainTokens.count) websites")
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                            .font(.subheadline)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Select apps button
                        GlassButton(
                            title: blockedAppsStore.hasBlockedApps ? "Change Selection" : "Select Apps to Block",
                            icon: "hand.tap.fill",
                            action: { isPresented = true }
                        )
                        .padding(.horizontal, 24)

                        // Clear selection button
                        if blockedAppsStore.hasBlockedApps {
                            Button(action: clearSelection) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Clear All")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.red.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Block Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .familyActivityPicker(
            isPresented: $isPresented,
            selection: $blockedAppsStore.selection
        )
        .onChange(of: blockedAppsStore.selection) { _ in
            blockedAppsStore.saveSelection()
        }
    }
    
    private func clearSelection() {
        blockedAppsStore.selection = FamilyActivitySelection()
        blockedAppsStore.saveSelection()
    }
}
