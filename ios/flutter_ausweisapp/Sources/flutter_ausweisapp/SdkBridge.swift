import AusweisApp2
import Foundation

/// A failure with a channel error code and a fixed text that never contains a command.
struct SdkError: Error {
  let code: String
  let message: String

  static let startFailed = SdkError(
    code: "start_failed", message: "The AusweisApp SDK could not be started.")
  static let startedElsewhere = SdkError(
    code: "start_failed", message: "The AusweisApp SDK is already running outside this plugin.")
  static let startCancelled = SdkError(
    code: "start_failed", message: "The start was cancelled by stop.")
  static let notRunning = SdkError(
    code: "not_running", message: "The AusweisApp SDK is not running.")
}

/// Receives the messages of the SDK, on the main thread.
protocol SdkBridgeDelegate: AnyObject {
  func sdkBridgeDidReceive(_ json: String)
}

/// Starts and stops the AusweisApp SDK through its C API and hands commands to it.
///
/// The SDK runs once per process and its C callback cannot capture context,
/// hence the single shared instance. Every member must be used on the main
/// thread. The SDK thread's callbacks and the end of a shutdown are moved to
/// the main thread as well, so all state lives on one thread.
final class SdkBridge {
  static let shared = SdkBridge()

  private enum State {
    case stopped
    /// `ausweisapp_init` succeeded; waiting for the callback with `NULL`.
    case starting
    /// The SDK accepts commands.
    case ready
    /// `ausweisapp_shutdown` runs off the main thread.
    case stopping
  }

  private var state = State.stopped
  private var pendingStarts: [(Result<Void, SdkError>) -> Void] = []
  private var pendingStops: [() -> Void] = []

  /// Gets every message while the SDK is starting or ready.
  weak var delegate: SdkBridgeDelegate?

  private init() {}

  /// Whether the SDK accepts commands.
  var isRunning: Bool {
    dispatchPrecondition(condition: .onQueue(.main))
    return state == .ready && ausweisapp_is_running()
  }

  /// Starts the SDK. `completion` is called once the SDK is ready or the
  /// start failed. Succeeds at once if the SDK is ready; joins a start that is
  /// still pending. A start during a shutdown begins once the shutdown ended,
  /// so `ausweisapp_init` never overlaps `ausweisapp_shutdown`.
  func start(completion: @escaping (Result<Void, SdkError>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    switch state {
    case .ready:
      completion(.success(()))
    case .starting, .stopping:
      pendingStarts.append(completion)
    case .stopped:
      pendingStarts.append(completion)
      initialize()
    }
  }

  /// Shuts the SDK down off the main thread; `completion` is called on the
  /// main thread once it is down. A pending start fails with `start_failed`.
  /// Completes at once if the SDK is not running; joins a shutdown that is
  /// still running.
  func stop(completion: @escaping () -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    finishStarts(.failure(.startCancelled))
    switch state {
    case .stopped:
      completion()
    case .stopping:
      pendingStops.append(completion)
    case .starting, .ready:
      pendingStops.append(completion)
      state = .stopping
      DispatchQueue.global(qos: .userInitiated).async {
        // Blocks until the SDK thread has ended.
        ausweisapp_shutdown()
        DispatchQueue.main.async { self.handleShutdownFinished() }
      }
    }
  }

  /// Hands `json` to the SDK. Fails with `not_running` before the SDK is ready.
  func send(_ json: String) -> Result<Void, SdkError> {
    dispatchPrecondition(condition: .onQueue(.main))
    guard isRunning else { return .failure(.notRunning) }
    json.withCString { ausweisapp_send($0) }
    return .success(())
  }

  private func initialize() {
    if ausweisapp_init(sdkCallback, nil) {
      state = .starting
      return
    }
    // The state is stopped, so a running SDK was started outside this plugin
    // and its messages would never reach this callback.
    finishStarts(.failure(ausweisapp_is_running() ? .startedElsewhere : .startFailed))
  }

  fileprivate func handleReady() {
    // A late signal of a start that stop() cancelled: the shutdown joins the
    // SDK thread, so its callbacks are queued before the shutdown's end.
    guard state == .starting else { return }
    state = .ready
    finishStarts(.success(()))
  }

  fileprivate func handleMessage(_ json: String) {
    guard state == .starting || state == .ready else { return }
    delegate?.sdkBridgeDidReceive(json)
  }

  private func handleShutdownFinished() {
    state = .stopped
    let stops = pendingStops
    pendingStops = []
    stops.forEach { $0() }
    // Starts that arrived during the shutdown.
    if !pendingStarts.isEmpty { initialize() }
  }

  private func finishStarts(_ result: Result<Void, SdkError>) {
    let starts = pendingStarts
    pendingStarts = []
    starts.forEach { $0(result) }
  }
}

/// Runs on the SDK thread. `NULL` means the SDK is ready; any other text is a
/// message, valid only during this call, so it is copied here. Everything else
/// happens on the main thread. Never calls `ausweisapp_send` or
/// `ausweisapp_shutdown` (see ios.rst).
private func sdkCallback(_ message: UnsafePointer<CChar>?) {
  guard let message else {
    DispatchQueue.main.async { SdkBridge.shared.handleReady() }
    return
  }
  let json = String(cString: message)
  DispatchQueue.main.async { SdkBridge.shared.handleMessage(json) }
}
