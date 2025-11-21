import Foundation
import Logging
import OpenAPIRuntime
import OpenAPIVapor
import Vapor
import Crypto

var validChallenges: [String] = []

struct LoggerMiddleware: Middleware {
  func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
    print("Request: \(request.method.rawValue) \(request.url.string)")
    return next.respond(to: request)
  }
}

// Optional: Simple rate limiting middleware (tracks requests per IP in memory; replace with a proper package for production)
class RateLimitMiddleware: Middleware {
  private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
  private let maxRequestsPerMinute = 10  // Adjust as needed
  
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

struct Handler: APIProtocol {
  
  static let secret = ProcessInfo.processInfo.environment["SECRET"] ?? "SECRET enviroment variable not found"
  
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
      throw Abort(.unauthorized)
    }
    // Remove the challenge from the list
    validChallenges.removeAll(where: { $0 == challenge })
    
    // Validate the challenge attestation
    let attestation = body.attestation
    let keyId = body.keyId
    guard Validator.isValid(attestation: attestation, challenge: challenge, keyId: keyId) else {
      throw Abort(.unauthorized)
    }
    
    // Return the secret
    return .ok(.init(body: .json(.init(secret: Handler.secret))))
  }
}

struct Config: Codable {
  let port: Int
  let hostname: String
}

@main struct Entrypoint {
  static func main() async throws {
    // Load configuration from config.json
    let configURL = URL(fileURLWithPath: "config.json")
    let configData = try Data(contentsOf: configURL)
    let config = try JSONDecoder().decode(Config.self, from: configData)
    
    let app = try await Vapor.Application.make()
    app.http.server.configuration.port = config.port
    app.http.server.configuration.hostname = config.hostname
    
    // Add middleware (order matters: earlier middleware runs first)
    app.middleware.use(LoggerMiddleware())  // Your existing logger
    app.middleware.use(RateLimitMiddleware())  // Optional: Basic rate limiting
    
    let transport = VaporTransport(routesBuilder: app)
    let handler = Handler()
    try handler.registerHandlers(on: transport, serverURL: Servers.Server1.url())
    try await app.execute()
  }
}
