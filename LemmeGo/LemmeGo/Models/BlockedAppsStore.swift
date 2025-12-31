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
        } catch {
            // Failed to save - selection will not persist
        }
    }

    func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            // No saved selection - will use empty selection
            return
        }

        do {
            selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            // Failed to load - will use empty selection
        }
    }
    
    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty || 
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }
}
