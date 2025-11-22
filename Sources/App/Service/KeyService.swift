import Fluent
import Vapor

struct KeyService {
    static func assignKey(to deviceId: String, on db: Database) async throws -> String {
        // Check if device already has a key
        if let existing = try await DeviceAssignment.query(on: db)
            .filter(\.$deviceId == deviceId)
            .with(\.$apiKey)
            .first() {
            return existing.apiKey.grokKey
        }
        
        // Assign new key
        guard let availableKey = try await ApiKey.nextAvailable(on: db) else {
            throw Abort(.notFound, reason: "No available keys")
        }
        
        let assignment = DeviceAssignment(deviceId: deviceId, apiKeyID: availableKey.id!)
        try await assignment.save(on: db)
        
        availableKey.status = .assigned
        availableKey.assignedAt = Date()
        try await availableKey.save(on: db)
        
        return availableKey.grokKey
    }
    
    static func recycleInactiveKeys(on db: Database) async throws {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let inactiveKeys = try await ApiKey.query(on: db)
            .join(DeviceAssignment.self, on: \ApiKey.$id == \DeviceAssignment.$apiKey.$id)
            .filter(DeviceAssignment.self, \.$lastActiveAt < ninetyDaysAgo)
            .filter(\.$status == .assigned)
            .all()
        
        for key in inactiveKeys {
            key.status = .available
            key.assignedAt = nil
            key.lastUsedAt = nil
            try await key.save(on: db)
        }
    }
}
