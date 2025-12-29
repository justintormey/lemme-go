import Foundation

struct LockSession: Codable, Identifiable {
    let id: UUID
    let chipId: String
    let startTime: Date
    let duration: TimeInterval
    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }

    var isActive: Bool {
        Date() < endTime
    }

    var remainingTime: TimeInterval {
        max(0, endTime.timeIntervalSinceNow)
    }

    init(chipId: String, duration: TimeInterval) {
        self.id = UUID()
        self.chipId = chipId
        self.startTime = Date()
        self.duration = duration
    }
}

struct NFCChip: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    let registeredAt: Date

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.registeredAt = Date()
    }
}
