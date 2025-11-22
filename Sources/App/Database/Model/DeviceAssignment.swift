import Fluent
import Vapor

final class DeviceAssignment: Model {
    static let schema = "device_assignments"
    
    @ID(custom: .id, generatedBy: .database)
    var id: Int?
    
    @Field(key: "device_id")
    var deviceId: String
    
    @Parent(key: "api_key_id")
    var apiKey: ApiKey
    
    @Field(key: "plan")
    var plan: Plan
    
    @Timestamp(key: "assigned_at", on: .create)
    var assignedAt: Date?
    
    @Timestamp(key: "last_active_at", on: .update)
    var lastActiveAt: Date?
    
    @OptionalField(key: "revenuecat_user_id")
    var revenuecatUserId: String?
    
    @OptionalField(key: "subscription_expires_at")
    var subscriptionExpiresAt: Date?
    
    init() {}
    
    init(id: Int? = nil, deviceId: String, apiKeyID: Int, plan: Plan = .free) {
        self.id = id
        self.deviceId = deviceId
        self.$apiKey.id = apiKeyID
        self.plan = plan
    }
    
    enum Plan: String, Codable {
        case free, paid, trial, grandfathered
    }
}
