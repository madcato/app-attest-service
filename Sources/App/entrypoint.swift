import Foundation
//import Logging
import OpenAPIRuntime
import OpenAPIVapor
import Vapor
import Crypto

var validChallenges: [String] = []

struct Handler: APIProtocol {


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
        return .ok(.init(body: .json(.init(secret: "secret revealed!"))))
    }
}


@main struct Entrypoint {
    static func main() async throws {
        let app = Vapor.Application()
        app.http.server.configuration.port = 44947
        let transport = VaporTransport(routesBuilder: app)
        let handler = Handler()
        try handler.registerHandlers(on: transport, serverURL: Servers.Server1.url())
        try await app.execute()
    }
}
