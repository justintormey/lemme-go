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
    /// Monday 00:00:00 of the week containing `date`.
    ///
    /// Deliberately does NOT use `.weekOfYear` components: `date(from:)` anchors the
    /// week on the calendar's locale-dependent `firstWeekday`, which is Sunday in
    /// en_US. That made a Sunday resolve to the FOLLOWING Monday, handing the user a
    /// second full emergency-unlock budget every Sunday. Counting back from the date's
    /// own weekday is locale-independent, and stepping in whole days from `startOfDay`
    /// keeps it correct across DST transitions.
    func startOfWeek(for date: Date) -> Date {
        let dayStart = self.startOfDay(for: date)
        // Gregorian weekday: 1 = Sunday ... 7 = Saturday.
        // Days elapsed since Monday: Mon(2)->0, Tue(3)->1 ... Sat(7)->5, Sun(1)->6.
        let weekday = self.component(.weekday, from: dayStart)
        let daysSinceMonday = (weekday + 5) % 7

        return self.date(byAdding: .day, value: -daysSinceMonday, to: dayStart) ?? dayStart
    }
}
