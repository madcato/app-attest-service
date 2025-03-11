import Foundation
import Logging
import OpenAPIRuntime
import OpenAPIVapor
import Vapor

struct Handler: APIProtocol {
    func getSecret(_ input: Operations.GetSecret.Input) async throws -> Operations.GetSecret.Output {
        return .ok(.init(body: .json(.init(secret: "Secret revealed!"))))
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