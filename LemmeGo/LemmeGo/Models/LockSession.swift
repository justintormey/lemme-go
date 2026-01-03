import Foundation

struct LockSession: Codable, Identifiable {
    let id: UUID
    let chipId: String
    let startTime: Date
    let duration: TimeInterval
    var isRemoteActivated: Bool

    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }

    var isActive: Bool {
        Date() < endTime
    }

    var remainingTime: TimeInterval {
        max(0, endTime.timeIntervalSinceNow)
    }

    init(chipId: String, duration: TimeInterval, isRemoteActivated: Bool = false) {
        self.id = UUID()
        self.chipId = chipId
        self.startTime = Date()
        self.duration = duration
        self.isRemoteActivated = isRemoteActivated
    }

    // MARK: - Codable Migration Support
    enum CodingKeys: String, CodingKey {
        case id, chipId, startTime, duration, isRemoteActivated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        chipId = try container.decode(String.self, forKey: .chipId)
        startTime = try container.decode(Date.self, forKey: .startTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        // Migration: This property may not exist in older saved sessions
        isRemoteActivated = (try? container.decode(Bool.self, forKey: .isRemoteActivated)) ?? false
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
