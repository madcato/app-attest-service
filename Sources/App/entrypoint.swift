import Foundation
import Logging
import OpenAPIRuntime
import OpenAPIVapor
import Vapor
import Crypto
import Fluent
import FluentSQLiteDriver

struct LoggerMiddleware: Middleware {
  func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
    print("Request: \(request.method) \(request.url.string)")
    let future = next.respond(to: request)
    return future.always { result in
      switch result {
      case .success(let response):
        print("Response: Status \(response.status.code)")
      case .failure(let error):
        print("Error: \(error.localizedDescription)")
      }
    }
  }
}

// Optional: Simple rate limiting middleware (tracks requests per IP in memory; replace with a proper package for production)
final class RateLimitMiddleware: Middleware {
  private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
  private let maxRequestsPerMinute = 7  // Adjust as needed
  
  func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
    let ip = request.remoteAddress?.ipAddress ?? "unknown"
    let now = Date()
    
    if let (count, resetTime) = requestCounts[ip] {
      if now > resetTime {
        requestCounts[ip] = (1, now.addingTimeInterval(60))
      } else if count >= maxRequestsPerMinute {
        return request.eventLoop.makeFailedFuture(Abort(.tooManyRequests))
      } else {
        requestCounts[ip] = (count + 1, resetTime)
      }
    } else {
      requestCounts[ip] = (1, now.addingTimeInterval(60))
    }
    
    return next.respond(to: request)
  }
}

nonisolated(unsafe) var validChallenges: [String] = []

final class Handler: APIProtocol {
  let db: Database
  
  init(db: Database) {
    self.db = db
  }
  
  internal
  
  func getSecret(_ input: Operations.GetSecret.Input) async throws -> Operations.GetSecret.Output {
    let challenge = Data(AES.GCM.Nonce()).base64EncodedString()
    validChallenges.append(challenge)
    return .ok(.init(body: .json(.init(challenge: challenge))))
  }
  
  func postSecret(_ input: Operations.PostSecret.Input) async throws -> Operations.PostSecret.Output {
    let body: Components.Schemas.CompletedChallenge
    switch input.body {
    case .json(let json): body = json
    }
    
    // Check if the challenge is valid
    let challenge = body.challenge
    
    guard validChallenges.contains(challenge) else {
      return .badRequest(Operations.PostSecret.Output.BadRequest())
    }
    // Remove the challenge from the list
    validChallenges.removeAll(where: { $0 == challenge })
    
    // Validate the challenge attestation
    let attestation = body.attestation
    /// FOR TESTING
    if attestation == "mockAttestationBase64" {
      return .ok(.init(body: .json(.init(secret: "{\"grok_api_key\":\"test-grok-key\",\"grok_api_public_key\":\"mockPublicKey\""))))
    }
    /// END FOR TESTING
    let keyId = body.keyId
    guard Validator.isValid(attestation: attestation, challenge: challenge, keyId: keyId) else {
      return .unauthorized(Operations.PostSecret.Output.Unauthorized())
    }
    
    // Access the database and assign an API key for the device (keyId as deviceId)
    let deviceId = body.deviceId
    let assignedKey = try await KeyService.assignKey(to: deviceId, on: db)

    // Return the assigned API key as the secret
    return .ok(.init(body: .json(.init(secret: assignedKey))))
  }
}

@main struct Entrypoint {
  static func main() async throws {
    print("TeamID: \(Validator.teamId)")
    print("BundleID: \(Validator.bundleId)")

    
    let app = try await Vapor.Application.make()
    app.http.server.configuration.port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "") ?? 44947
    app.http.server.configuration.hostname = ProcessInfo.processInfo.environment["SERVER_HOST"] ?? "0.0.0.0"
    // Add middleware (order matters: earlier middleware runs first)
    app.middleware.use(LoggerMiddleware())  // Your existing logger
    app.middleware.use(RateLimitMiddleware())  // Optional: Basic rate limiting
    
    // database
    // ... after app = try await Vapor.Application.make()
    let sqliteFileName = (ProcessInfo.processInfo.environment["APP_DATA"] ?? "./") + "keys.db"
    let sqliteDirectory = (sqliteFileName as NSString).deletingLastPathComponent
    if !sqliteDirectory.isEmpty {
      try FileManager.default.createDirectory(atPath: sqliteDirectory, withIntermediateDirectories: true)
    }
    app.databases.use(.sqlite(.file(sqliteFileName)), as: .sqlite)  // Or PostgreSQL config
    app.migrations.add(CreateApiKeys())  // Define a migration for your key model
    try await app.autoMigrate()

    
    let transport = VaporTransport(routesBuilder: app)
    let handler = Handler(db: app.db)
    try handler.registerHandlers(on: transport, serverURL: Servers.Server1.url())
    try await app.execute()
  }
}
