//
//  AppAttestClientDemoTests.swift
//  AppAttestClientDemoTests
//
//  Created by Daniel Vela on 12/3/25.
//

import XCTest
import DeviceCheck
@testable import AppAttestClientDemo

final class AppAttestClientDemoTests: XCTestCase {
  
  var appAttestTester: AppAttestTester!
  
  override func setUpWithError() throws {
    appAttestTester = AppAttestTester()
  }
  
  override func tearDownWithError() throws {
    appAttestTester = nil
  }
  
  // Test the downloadSecret method for a successful flow
  func testDownloadSecretSuccess() async throws {
    do {
      let secret = try await appAttestTester.downloadSecret()
      XCTAssertNotNil(secret, "The secret should not be nil")
      XCTAssertEqual(secret, "secret revealed!")
    } catch {
      // When testing in iOS Simulator, you will receive this error: "The operation couldn’t be completed. (com.apple.devicecheck.error error 1.)"
      XCTFail("The call should not have thrown an error, but it threw: \(error.localizedDescription)")
    }
  }
}
