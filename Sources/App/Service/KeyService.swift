import Fluent
import FluentSQL
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
      .filter(DeviceAssignment.self, \DeviceAssignment.$lastActiveAt, .lessThan, .some(ninetyDaysAgo))
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

extension Date {
    
    // 1. Unix timestamp como Double (exactamente lo que guardas en SQLite)
    var unixTimestamp: Double {
        self.timeIntervalSince1970   // ← esto es lo que quieres para tu columna REAL
    }
    
    // 2. Unix timestamp como String con milisegundos (ej: "1763808863.7487311")
    var unixTimestampString: String {
        String(format: "%.06f", self.timeIntervalSince1970)
    }
    
    // 3. Fecha legible en formato ISO 8601 (muy recomendado para debug y APIs)
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
    
    // 4. Fecha legible en tu zona horaria (ej: España, México, Argentina, etc.)
    var localString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
    
    // 5. Formato personalizado (el que más se usa en apps)
    var yyyyMMdd_HHmmss: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current   // o TimeZone(secondsFromGMT: 0) para UTC
        return formatter.string(from: self)
    }
}
