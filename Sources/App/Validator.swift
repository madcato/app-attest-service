import AppAttest

enum Validator {
    /// Parameters `attestation` and `challenge` are expected to be base64 encoded strings.
    static func isValid(attestation: String, challenge: String, keyId: String) -> Bool {
        guard let attestation = attestation.data(using: .utf8),
            let challenge = challenge.data(using: .utf8),
            let keyId = keyId.data(using: .utf8) else {
                print("Invalid data encoding in validator.swift")
                return false
            }
            // Construct the attestation request and app ID,
            // which are simple structs
            let request = AppAttest.AttestationRequest(attestation: attestation, keyID: keyId)
            let appID = AppAttest.AppID(teamID: "83Z139DVZ2", bundleID: "com.example.myapp")

            // Verify the attestation
            do {
                let result = try AppAttest.verifyAttestation(challenge: challenge, request: request, appID: appID)
            } catch {
                // Handle the error
                print("Attestation verification failed: \(error)")
                return false
            }
        // If we reach this point, the attestation is valid.
        return true
    }
}

// Sample client code
// let service = DCAppAttestService.shared
//         service.generateKey { keyId, error in
//             guard error == nil else {
//                 print("Failed to generate key: \(error!)")
//                 return false
//             }
//             let challenge = challenge.data(using: .utf8)!
//             let hash = Data(SHA256.hash(data: challenge))
//             service.attest(keyId: keyId!, challenge: challenge) { attestationData, error in
//                 guard error == nil else {
//                     print("Failed to attest: \(error!)")
//                     return false
//                 }
//             }
//         }