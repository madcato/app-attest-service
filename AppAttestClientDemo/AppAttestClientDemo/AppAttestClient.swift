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

class AppAttestTester {
  func downloadSecret() async throws -> String {
    let client = Client(serverURL: URL(string: "http://mac-mini.local:44947")!, transport: URLSessionTransport())
    let response = try await client.getSecret(.init())  // Get challenge for app-attest-service
    switch response {
    case .ok(let okResponse):
      switch okResponse.body {
      case .json(let challengeInput):
        let challenge = challengeInput.challenge
        let (attestation, keyId) = try await makeAttestation(challenge: challenge)
        let secret = try await send(attestation: attestation, challenge: challenge, keyId: keyId, with: client)
        return secret
      }
    case .undocumented(statusCode: let statusCode, _):
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
