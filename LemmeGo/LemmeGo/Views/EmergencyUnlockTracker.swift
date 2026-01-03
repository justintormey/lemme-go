import Foundation

struct EmergencyUnlockRecord: Codable {
    let timestamp: Date
    let sessionId: UUID
    let reason: String?
}

class EmergencyUnlockTracker: ObservableObject {
    @Published var weeklyUnlocks: [EmergencyUnlockRecord] = []

    private let unlockKey = "emergencyUnlocks"
    private let weeklyLimit = 5

    init() {
        loadUnlocks()
        cleanExpiredUnlocks()
    }

    var remainingUnlocks: Int {
        weeklyLimit - currentWeekUnlocks.count
    }

    var canUseEmergencyUnlock: Bool {
        remainingUnlocks > 0
    }

    var currentWeekUnlocks: [EmergencyUnlockRecord] {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        return weeklyUnlocks.filter { $0.timestamp >= weekStart }
    }

    func recordEmergencyUnlock(sessionId: UUID, reason: String?) -> Bool {
        guard canUseEmergencyUnlock else {
            return false
        }

        let record = EmergencyUnlockRecord(
            timestamp: Date(),
            sessionId: sessionId,
            reason: reason
        )

        weeklyUnlocks.append(record)
        saveUnlocks()

        return true
    }

    private func cleanExpiredUnlocks() {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklyUnlocks = weeklyUnlocks.filter { $0.timestamp >= oneWeekAgo }
        saveUnlocks()
    }

    private func saveUnlocks() {
        if let encoded = try? JSONEncoder().encode(weeklyUnlocks) {
            UserDefaults.standard.set(encoded, forKey: unlockKey)
        }
    }

    private func loadUnlocks() {
        if let data = UserDefaults.standard.data(forKey: unlockKey),
           let decoded = try? JSONDecoder().decode([EmergencyUnlockRecord].self, from: data) {
            weeklyUnlocks = decoded
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        // Get Monday 00:00:00 of current week
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let weekStart = self.date(from: components) else {
            return date
        }

        // Adjust to Monday (weekday 2 in Gregorian calendar)
        let weekday = self.component(.weekday, from: weekStart)
        let daysToAdd = weekday == 1 ? 1 : 2 - weekday

        return self.date(byAdding: .day, value: daysToAdd, to: weekStart) ?? weekStart
    }
}
