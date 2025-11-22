//
//  DatabaseTests.swift
//  app-attest-service
//
//  Created by Daniel Vela on 22/11/25.
//

@testable import App
import VaporTesting
import Testing
import FluentSQL

@Suite("Database Tests")
struct DatabaseTests {
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
  
  @Test("Test Initial Database with First Migration")
  func testInitialMigration() async throws {
    try await withApp { app in
      guard let database = app.db as? SQLDatabase else {
        fatalError("Invalid database testing setup")
      }
      // Check if the api_keys table exists using raw SQL (SQLite-specific)
      let apiKeysTableCount = try await database.raw("SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name='\(unsafeRaw: ApiKey.schema)'").first()?.decode(
        column: "count",
        as: Int.self
      ) ?? -1
      #expect(apiKeysTableCount > 0, "api_keys table should exist after running CreateApiKeys migration")
      
      // Check if the device_assignments table exists
      let deviceAssignmentsTableCount = try await database.raw("SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name='\(unsafeRaw: DeviceAssignment.schema)'").first()?.decode(
        column: "count",
        as: Int.self
      ) ?? -1
      #expect(deviceAssignmentsTableCount > 0, "device_assignments table should exist after running CreateApiKeys migration")
      
      // Check if the next_available_key view exists
      let viewCount = try await database.raw("SELECT COUNT(*) as count FROM sqlite_master WHERE type='view' AND name='next_available_key'").first()?.decode(column: "count", as: Int.self) ?? -1
      #expect(viewCount > 0, "next_available_key view should exist after running CreateApiKeys migration")
      
      // Optional: Verify we can create and query a basic ApiKey (ensures table structure is correct)
      let testKey = ApiKey(grokKey: "test-key-123", status: .available, dailySpendLimitUSD: 1.0, dailyRequestLimit: 100, totalSpentUSD: 0.0, totalRequests: 0)
      try await testKey.save(on: app.db)
      let fetchedKey = try await ApiKey.find(testKey.id, on: app.db)
      #expect(fetchedKey != nil, "Should be able to save and retrieve an ApiKey")
      #expect(fetchedKey?.grokKey == "test-key-123", "Retrieved ApiKey should match the saved one")
    }
  }
  
  @Test("Test Assign a New Key to a New Device")
  func testAssignNewKey() async throws {
    try await withApp { app in
      // Create an available ApiKey
      let apiKey = ApiKey(grokKey: "test-grok-key", status: .available, dailySpendLimitUSD: 2.0, dailyRequestLimit: 500, totalSpentUSD: 0.0, totalRequests: 0)
      try await apiKey.save(on: app.db)
      
      // Simulate assigning the key to a new device
      let deviceId = "test-device-123"
      guard let availableKey = try await ApiKey.nextAvailable(on: app.db) else {
        Issue.record("No available key found")
        return
      }
      #expect(availableKey.id == apiKey.id, "The available key should be the one we created")
      
      // Create the DeviceAssignment
      let assignment = DeviceAssignment(deviceId: deviceId, apiKeyID: availableKey.id!, plan: .free)
      try await assignment.save(on: app.db)
      
      // Update the ApiKey status to assigned and set assigned_at
      availableKey.status = .assigned
      availableKey.assignedAt = Date()
      try await availableKey.save(on: app.db)
      
      // Verify the assignment
      let fetchedAssignment = try await DeviceAssignment.query(on: app.db).filter(\.$deviceId == deviceId).first()
      #expect(fetchedAssignment != nil, "DeviceAssignment should exist for the new device")
      #expect(fetchedAssignment?.$apiKey.id == apiKey.id, "Assignment should link to the correct ApiKey")
      #expect(fetchedAssignment?.plan == .free, "Plan should be free")
      
      // Verify the key status is now assigned
      let updatedKey = try await ApiKey.find(apiKey.id, on: app.db)
      #expect(updatedKey?.status == .assigned, "ApiKey status should be assigned")
      #expect(updatedKey?.assignedAt != nil, "AssignedAt should be set")
      
      // Verify no more available keys (since this one is assigned)
      let nextAvailable = try await ApiKey.nextAvailable(on: app.db)
      #expect(nextAvailable == nil, "No more available keys after assignment")
    }
  }
  
  @Test("Test Assign the Same Key to the Same Device")
  func testAssignSameKeyToSameDevice() async throws {
    try await withApp { app in
      // Create an available ApiKey
      let apiKey = ApiKey(grokKey: "test-grok-key", status: .available, dailySpendLimitUSD: 2.0, dailyRequestLimit: 500, totalSpentUSD: 0.0, totalRequests: 0)
      try await apiKey.save(on: app.db)
      
      // Assign the key to a device (initial assignment)
      let deviceId = "test-device-123"
      guard let availableKey = try await ApiKey.nextAvailable(on: app.db) else {
        Issue.record("No available key found")
        return
      }
      let initialAssignment = DeviceAssignment(deviceId: deviceId, apiKeyID: availableKey.id!, plan: .free)
      try await initialAssignment.save(on: app.db)
      availableKey.status = .assigned
      availableKey.assignedAt = Date()
      try await availableKey.save(on: app.db)
      
      // Record the initial state
      let initialAssignmentsCount = try await DeviceAssignment.query(on: app.db).count()
      let initialAvailableKeysCount = try await ApiKey.query(on: app.db).filter(\.$status == .available).count()
      
      // Simulate "asking" for a key again for the same device (should return the existing assignment)
      // Check if device already has an assignment
      if let existingAssignment = try await DeviceAssignment.query(on: app.db).filter(\.$deviceId == deviceId).first() {
        // Return the existing key (do not create new assignment or change status)
        let returnedKey = existingAssignment.$apiKey
        try await returnedKey.load(on: app.db)
        
        // Verify it's the same key
        #expect(returnedKey.id == apiKey.id, "Should return the already assigned key")
        #expect(returnedKey.value?.status == .assigned, "Key status should remain assigned")
        
        // Verify no new assignment was created
        let finalAssignmentsCount = try await DeviceAssignment.query(on: app.db).count()
        #expect(finalAssignmentsCount == initialAssignmentsCount, "No new assignment should be created")
        
        // Verify available keys count unchanged (no new key assigned)
        let finalAvailableKeysCount = try await ApiKey.query(on: app.db).filter(\.$status == .available).count()
        #expect(finalAvailableKeysCount == initialAvailableKeysCount, "Available keys count should remain the same")
      } else {
        Issue.record("Expected existing assignment for device")
      }
    }
  }
}
