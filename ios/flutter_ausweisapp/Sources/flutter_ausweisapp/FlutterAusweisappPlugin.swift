import Flutter
import UIKit

/// Moves JSON strings between Dart and the AusweisApp SDK.
///
/// Flutter calls every handler here on the main thread and `SdkBridge` reports
/// on the main thread, so the event sink and method results are only ever
/// used there.
public class FlutterAusweisappPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  SdkBridgeDelegate
{
  private static let methodChannelName = "flutter_ausweisapp/methods"
  private static let eventChannelName = "flutter_ausweisapp/events"

  private let bridge = SdkBridge.shared
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterAusweisappPlugin()
    let methods = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    // Needed for detachFromEngine(for:).
    registrar.publish(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      // The SDK exists once per process; the engine that starts it last gets
      // its messages.
      bridge.delegate = self
      bridge.start { outcome in
        switch outcome {
        case .success: result(nil)
        case .failure(let error): result(error.flutterError)
        }
      }
    case "stop":
      bridge.stop { result(nil) }
    case "send":
      guard let json = call.arguments as? String else {
        result(
          FlutterError(code: "send_failed", message: "The command must be a string.", details: nil))
        return
      }
      switch bridge.send(json) {
      case .success: result(nil)
      case .failure(let error): result(error.flutterError)
      }
    case "isRunning":
      result(bridge.isRunning)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    // A second listen (hot restart) replaces the sink; the SDK keeps running.
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func sdkBridgeDidReceive(_ json: String) {
    // Without a listener the message is dropped.
    eventSink?(["type": "message", "json": json])
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    eventSink = nil
    // Leave the SDK alone if another engine started it after this one.
    guard bridge.delegate === self else { return }
    bridge.delegate = nil
    bridge.stop {}
  }
}

extension SdkError {
  fileprivate var flutterError: FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }
}
