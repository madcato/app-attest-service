//
//  AppAttestClient.swift
//  AppAttestClientDemo
//
//  Created by Daniel Vela on 12/3/25.
//

import CryptoKit
import Foundation
import DeviceCheck
import OpenAPIRuntime
import OpenAPIURLSession
import KeychainSwift

class AppAttestTester {
  func downloadSecret(keyName: String? = nil) async throws -> String {
    let client = Client(serverURL: URL(string: "https://tesla.codebenderai.click" /*"http://tesla.local:44947"*/)!, transport: URLSessionTransport(), middlewares: [AuthenticationMiddleware(authorizationHeaderFieldValue: "Bearer hFDp2PH5/MfrbasANQYGmSoWrTtqDtbt8jR4+2Z1Gog=")])
    let response = try await client.getSecret(.init())  // Get challenge for app-attest-service
    switch response {
    case .ok(let okResponse):
      switch okResponse.body {
      case .json(let challengeInput):
        let challenge = challengeInput.challenge
        let (attestation, keyId) = try await makeAttestation(challenge: challenge)
        let secret = try await send(attestation: attestation, challenge: challenge, keyId: keyId, with: client)
        if let keyName = keyName {
          // Store the secret in Keychain
          let keychain = KeychainSwift()
          keychain.set(secret, forKey: keyName)
        }
        return secret
      }
    case .undocumented(statusCode: let statusCode, let payload):
      print(payload)
      fatalError("undocumented status code: \(statusCode)")
    }
  }
  
  private func makeAttestation(challenge: String) async throws -> (String, String) {
    let keyId = try await DCAppAttestService.shared.generateKey()
    let hash = Data(SHA256.hash(data: Data(base64Encoded: challenge)!))
    let attestKey = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash).base64EncodedString()
    return (attestKey, keyId)
  }
  
  private func send(attestation: String, challenge: String, keyId: String, with client: Client) async throws -> String {
    let response = try await client.postSecret(body: .json(.init(challenge: challenge, attestation: attestation, keyId: keyId)))
    switch response {
    case .ok(let okResponse):
      switch okResponse.body {
      case .json(let secretInput):
        return secretInput.secret
      }
    case .undocumented(statusCode: let statusCode, _):
      fatalError("undocumented status code: \(statusCode)")
    }
  }
}

import HTTPTypes

/// A client middleware that injects a value into the `Authorization` header field of the request.
struct AuthenticationMiddleware {

    /// The value for the `Authorization` header field.
    private let value: String

    /// Creates a new middleware.
    /// - Parameter value: The value for the `Authorization` header field.
    init(authorizationHeaderFieldValue value: String) { self.value = value }
}

extension AuthenticationMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        // Adds the `Authorization` header field with the provided value.
        request.headerFields[.authorization] = value
        return try await next(request, body, baseURL)
    }
}


// To read from Keychain
func getSecretFromKeychain() -> String? {
    let keychain = KeychainSwift()
    return keychain.get("app_secret")
}
