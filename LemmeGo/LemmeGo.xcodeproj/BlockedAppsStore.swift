import Foundation
import FamilyControls

@available(iOS 16.0, *)
class BlockedAppsStore: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    
    private let selectionKey = "blockedAppsSelection"
    
    init() {
        loadSelection()
    }
    
    func saveSelection() {
        do {
            let encoded = try JSONEncoder().encode(selection)
            UserDefaults.standard.set(encoded, forKey: selectionKey)
            print("✅ Saved app selection")
        } catch {
            print("❌ Failed to save app selection: \(error.localizedDescription)")
        }
    }
    
    func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            print("ℹ️ No saved app selection found")
            return
        }
        
        do {
            selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            print("✅ Loaded app selection")
        } catch {
            print("❌ Failed to load app selection: \(error.localizedDescription)")
        }
    }
    
    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty || 
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }
}
