import Fluent
import Vapor

final class ApiKey: Model, Content {
    static let schema = "api_keys"
    
    @ID(custom: .id, generatedBy: .database)  // AUTOINCREMENT
    var id: Int?
    
    @Field(key: "grok_key")
    var grokKey: String
    
    @Field(key: "status")
    var status: Status
    
    @Field(key: "daily_spend_limit_usd")
    var dailySpendLimitUSD: Double
    
    @Field(key: "daily_request_limit")
    var dailyRequestLimit: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @OptionalField(key: "assigned_at")
    var assignedAt: Date?
    
    @OptionalField(key: "last_used_at")
    var lastUsedAt: Date?
    
    @OptionalField(key: "revoked_at")
    var revokedAt: Date?
    
    @Field(key: "total_spent_usd")
    var totalSpentUSD: Double
    
    @Field(key: "total_requests")
    var totalRequests: Int
    
    // Relationship to DeviceAssignment (one-to-one)
    @OptionalChild(for: \.$apiKey)
    var deviceAssignment: DeviceAssignment?
    
    init() {}
    
    init(id: Int? = nil, grokKey: String, status: Status = .available, dailySpendLimitUSD: Double = 3.0, dailyRequestLimit: Int = 1000, totalSpentUSD: Double = 0.0, totalRequests: Int = 0) {
        self.id = id
        self.grokKey = grokKey
        self.status = status
        self.dailySpendLimitUSD = dailySpendLimitUSD
        self.dailyRequestLimit = dailyRequestLimit
        self.totalSpentUSD = totalSpentUSD
        self.totalRequests = totalRequests
    }
    
    enum Status: String, Codable {
        case available, assigned, revoked, burned
    }
}

extension ApiKey {
    // Helper to find the next available key
    static func nextAvailable(on db: Database) async throws -> ApiKey? {
        try await ApiKey.query(on: db)
            .filter(\.$status == .available)
            .sort(\.$id)
            .first()
    }
}
