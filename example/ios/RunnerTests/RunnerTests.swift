import Flutter
import UIKit
import XCTest

@testable import flutter_ausweisapp

// Unit tests of the Swift side that need no running SDK. The integration tests
// in example/integration_test cover start, send and stop.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testSendWithoutStartReportsNotRunning() {
    let plugin = FlutterAusweisappPlugin()

    let call = FlutterMethodCall(methodName: "send", arguments: "{\"cmd\":\"GET_INFO\"}")

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      let error = result as? FlutterError
      XCTAssertEqual(error?.code, "not_running")
      XCTAssertFalse(error?.message?.contains("GET_INFO") ?? true)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testUnknownMethodIsNotImplemented() {
    let plugin = FlutterAusweisappPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue((result as? NSObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
