import Foundation

class NFCChipStore: ObservableObject {
    @Published var registeredChips: [NFCChip] = []

    private let chipsKey = "registeredNFCChips"

    init() {
        loadChips()
    }

    func registerChip(id: String, name: String) {
        let chip = NFCChip(id: id, name: name)
        registeredChips.append(chip)
        saveChips()
    }

    func isChipRegistered(id: String) -> Bool {
        registeredChips.contains { $0.id == id }
    }

    func getChip(id: String) -> NFCChip? {
        registeredChips.first { $0.id == id }
    }

    func deleteChip(id: String) {
        registeredChips.removeAll { $0.id == id }
        saveChips()
    }

    func updateChipName(id: String, newName: String) {
        if let index = registeredChips.firstIndex(where: { $0.id == id }) {
            registeredChips[index].name = newName
            saveChips()
        }
    }

    private func saveChips() {
        if let encoded = try? JSONEncoder().encode(registeredChips) {
            UserDefaults.standard.set(encoded, forKey: chipsKey)
        }
    }

    private func loadChips() {
        if let data = UserDefaults.standard.data(forKey: chipsKey),
           let chips = try? JSONDecoder().decode([NFCChip].self, from: data) {
            registeredChips = chips
        }
    }
}
