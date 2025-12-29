import SwiftUI

@main
struct LemmeGoApp: App {
    @StateObject private var lockManager = LockManager()
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var chipStore = NFCChipStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lockManager)
                .environmentObject(nfcManager)
                .environmentObject(chipStore)
        }
    }
}
