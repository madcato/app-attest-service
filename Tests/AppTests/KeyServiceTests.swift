//
//  KeyServiceTests.swift
//  app-attest-service
//
//  Created by Daniel Vela on 22/11/25.
//

@testable import App
import VaporTesting
import Testing
import FluentSQL

@Suite("KeyService Tests")
struct KeyServiceTests {
  private func withApp(_ test: (Application) async throws -> ()) async throws {
    let app = try await Application.make(.testing)
    do {
      // Set up database for testing (using in-memory SQLite)
      app.databases.use(.sqlite(.memory), as: .sqlite)
      // Add the first migration
      app.migrations.add(CreateApiKeys())
      // Run migrations
      try await app.autoMigrate()
      try await test(app)
    }
    catch {
      try await app.asyncShutdown()
      throw error
    }
    try await app.asyncShutdown()
  }
  
  @Test("Assign a new key to a device")
  func testAssignNewKeyToDevice() async throws {
    try await withApp { app in
      // Create an available ApiKey
      let apiKey = ApiKey(grokKey: "test-grok-key", status: .available, dailySpendLimitUSD: 2.0, dailyRequestLimit: 500, totalSpentUSD: 0.0, totalRequests: 0)
      try await apiKey.save(on: app.db)
      
      // Assign key to device
      let deviceId = "test-device-123"
      let returnedKey = try await KeyService.assignKey(to: deviceId, on: app.db)
      
      // Verify the returned key matches
      #expect(returnedKey == "test-grok-key", "Returned key should match the assigned key")
      
      // Verify assignment exists
      let assignment = try await DeviceAssignment.query(on: app.db).filter(\.$deviceId == deviceId).with(\.$apiKey).first()
      #expect(assignment != nil, "DeviceAssignment should exist")
      #expect(assignment?.$apiKey.id == apiKey.id, "Assignment should link to the correct ApiKey")
      
      // Verify key status updated
      let updatedKey = try await ApiKey.find(apiKey.id, on: app.db)
      #expect(updatedKey?.status == .assigned, "ApiKey status should be assigned")
      #expect(updatedKey?.assignedAt != nil, "AssignedAt should be set")
    }
  }
  
  @Test("Assign existing key to the same device")
  func testAssignExistingKeyToSameDevice() async throws {
    try await withApp { app in
      // Create an available ApiKey and assign it initially
      let apiKey = ApiKey(grokKey: "test-grok-key", status: .available, dailySpendLimitUSD: 2.0, dailyRequestLimit: 500, totalSpentUSD: 0.0, totalRequests: 0)
      try await apiKey.save(on: app.db)
      let deviceId = "test-device-123"
      let initialReturnedKey = try await KeyService.assignKey(to: deviceId, on: app.db)
      
      // Call assignKey again for the same device
      let secondReturnedKey = try await KeyService.assignKey(to: deviceId, on: app.db)
      
      // Verify it's the same key
      #expect(secondReturnedKey == initialReturnedKey, "Should return the same key for the same device")
      
      // Verify only one assignment exists
      let assignments = try await DeviceAssignment.query(on: app.db).filter(\.$deviceId == deviceId).all()
      #expect(assignments.count == 1, "Only one assignment should exist for the device")
      
      // Verify key status remains assigned
      let updatedKey = try await ApiKey.find(apiKey.id, on: app.db)
      #expect(updatedKey?.status == .assigned, "ApiKey status should remain assigned")
    }
  }
  
  @Test("Fail to assign key when no available keys")
  func testAssignKeyNoAvailableKeys() async throws {
    try await withApp { app in
      let deviceId = "test-device-123"
      
      // Attempt to assign without any available keys
      await #expect(throws: Abort.self) {
        _ = try await KeyService.assignKey(to: deviceId, on: app.db)
      }
    }
  }
  
  @Test("Recycle inactive keys")
  func testRecycleInactiveKeys() async throws {
    try await withApp { app in
      // Create an assigned ApiKey with old lastActiveAt
      let ninetyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -91, to: Date())!
      let nineDaysAgo = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
      
      // Only the first one must be deleted
      let testData = [("test-grok-key-01", "test-device-123-01", ninetyOneDaysAgo),
                      ("test-grok-key-02", "test-device-123-02", nineDaysAgo),
                      ("test-grok-key-03", "test-device-123-03", nineDaysAgo)]
        
      var testApiKey: ApiKey? = nil
      
      for (grokKey, deviceId, lastActiveAt) in testData {
        
        
        let apiKey = ApiKey(grokKey: grokKey, status: .assigned, dailySpendLimitUSD: 2.0, dailyRequestLimit: 500, totalSpentUSD: 0.0, totalRequests: 0)
        apiKey.assignedAt = Date()
        apiKey.status = .assigned
        try await apiKey.save(on: app.db)
        
        // Create DeviceAssignment with old lastActiveAt
        let assignment = DeviceAssignment(deviceId: deviceId, apiKeyID: apiKey.id!, plan: .free)
        try await assignment.save(on: app.db)
        
        // Update lastActiveAt
        assignment.lastActiveAt = lastActiveAt
        try await assignment.save(on: app.db)
        
        if testApiKey == nil {
          testApiKey = apiKey
        }
      }
      // Recycle inactive keys
      try await KeyService.recycleInactiveKeys(on: app.db)
      
      // Verify key is recycled
      let recycledKey = try await ApiKey.find(testApiKey!.id, on: app.db)
      #expect(recycledKey?.status == .available, "Key status should be recycled to available")
      #expect(recycledKey?.assignedAt == nil, "AssignedAt should be cleared")
      #expect(recycledKey?.lastUsedAt == nil, "LastUsedAt should be cleared")
      
      // Verify there are still all created keys
      let allKeys = try await ApiKey.query(on: app.db).all()
      #expect(allKeys.count == testData.count)
      
      // Verify there are only one available key
      let availableKeys = try await ApiKey.query(on: app.db).filter(\.$status == .available).all()
      #expect(availableKeys.count == 1)
    }
  }
}

