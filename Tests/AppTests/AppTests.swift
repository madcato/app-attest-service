@testable import App
import VaporTesting
import Testing
import FluentSQL
import OpenAPIRuntime
import OpenAPIVapor

@Suite("App Tests")
struct AppTests {
  private func withApp(_ test: (Application) async throws -> ()) async throws {
    let app = try await Application.make(.testing)
    do {
      
      app.middleware.use(RateLimitMiddleware())  // Optional: Basic rate limiting
      
      // Set up database for testing (using in-memory SQLite)
      app.databases.use(.sqlite(.memory), as: .sqlite)
      // Add migrations
      app.migrations.add(CreateApiKeys())
      // Run migrations
      try await app.autoMigrate()
      
      // Set up OpenAPI handlers
      let transport = VaporTransport(routesBuilder: app)
      let handler = Handler(db: app.db)
      try handler.registerHandlers(on: transport, serverURL: Servers.Server1.url())
      
      // Uncomment if needed: try await configure(app)
      try await test(app)
    }
    catch {
      try await app.asyncShutdown()
      throw error
    }
    try await app.asyncShutdown()
  }
  
  @Test("GET /secret returns a challenge")
  func testGetSecretReturnsChallenge() async throws {
    try await withApp { app in
      try await app.testing().test(.GET, "secret", afterResponse: { res async in
        #expect(res.status == .ok)
        // Assuming the response is JSON with a challenge field
        let body = try? res.content.decode(Components.Schemas.Challenge.self)
        #expect(!(body?.challenge.isEmpty ?? false), "Challenge should not be empty")
      })
    }
  }
  
  @Test("POST /secret with valid attestation returns secret")
  func testPostSecretValidAttestation() async throws {
    try await withApp { app in
      // First, get a challenge
      var challenge: String = ""
      try await app.testing().test(.GET, "secret", afterResponse: { res async in
        let body = try? res.content.decode(Components.Schemas.Challenge.self)
        challenge = body?.challenge ?? "BAD DATA"
      })
      
      // Create a mock valid attestation (in real tests, you'd use actual AppAttest, but for simplicity, assume validator passes)
      // Note: For full testing, you'd need to mock Validator or use real attestation data
      let attestation = "mockAttestationBase64"
      let keyId = "mockKeyIdBase64"
      let deviceId = "test-device-123"
      
      // Create an available API key in DB
      let apiKey = ApiKey(grokKey: "test-grok-key", status: .available, dailySpendLimitUSD: 1.0, dailyRequestLimit: 100, totalSpentUSD: 0.0, totalRequests: 0)
      try await apiKey.save(on: app.db)
      
      // Mock Validator to return true (in a real test, integrate actual validation or mock it)
      // Since Validator uses AppAttest, for unit tests, you might need to patch or use test doubles
      
      try await app.testing().test(.POST, "secret", beforeRequest: { req in
        try req.content.encode(["challenge": challenge, "attestation": attestation, "keyId": keyId, "deviceId": deviceId])
      }, afterResponse: { res async in
        #expect(res.status == .ok)
        let body = try? res.content.decode(Components.Schemas.Secret.self)
        #expect(body?.secret.contains("test-grok-key") ?? false, "Secret should contain the assigned key")
      })
    }
  }
  
  @Test("POST /secret with invalid challenge fails")
  func testPostSecretInvalidChallenge() async throws {
    try await withApp { app in
      let invalidChallenge = "invalidChallenge"
      let attestation = "mockAttestation"
      let keyId = "mockKeyId"
      let deviceId = "test-device"
      
      try await app.testing().test(.POST, "secret", beforeRequest: { req in
        try req.content.encode(["challenge": invalidChallenge, "attestation": attestation, "keyId": keyId, "deviceId": deviceId])
      }, afterResponse: { res async in
        #expect(res.status == .badRequest)
      })
    }
  }
  
  @Test("POST /secret with no available keys fails")
  func testPostSecretNoAvailableKeys() async throws {
    try await withApp { app in
      // Get a valid challenge
      var challenge: String = ""
      try await app.testing().test(.GET, "secret", afterResponse: { res async in
        let body = try? res.content.decode(Components.Schemas.Challenge.self)
        challenge = body?.challenge ?? "BAD CHALLENGE"
      })
      
      let attestation = "mockAttestation"
      let keyId = "mockKeyId"
      let deviceId = "test-device"
      
      // No keys in DB, so should fail
      try await app.testing().test(.POST, "secret", beforeRequest: { req in
        try req.content.encode(["challenge": challenge, "attestation": attestation, "keyId": keyId, "deviceId": deviceId])
      }, afterResponse: { res async in
        #expect(res.status == .unauthorized)
      })
    }
  }
  
  // Additional test: Test rate limiting (if middleware is active)
  @Test("Rate limiting blocks excessive requests")
  func testRateLimiting() async throws {
    try await withApp { app in
      // Assuming RateLimitMiddleware is added (as in entrypoint.swift)
      // Make maxRequestsPerMinute + 1 requests
      for i in 0...8 {  // 7 is the limit in RateLimitMiddleware
        try await app.testing().test(.GET, "secret", afterResponse: { res in
          if i < 7 {
            #expect(res.status == .ok)
          } else {
            #expect(res.status == .tooManyRequests)
          }
        })
      }
    }
  }
}
