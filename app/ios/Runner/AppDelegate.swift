import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShacheniWebAuth") {
      ShacheniWebAuth.register(with: registrar)
    }
  }
}

/// System OAuth session: credentials stay in Apple's browser surface and the
/// sheet closes when the registered callback arrives. No Safari app switch.
private final class ShacheniWebAuth: NSObject, FlutterPlugin,
  ASWebAuthenticationPresentationContextProviding
{
  private var session: ASWebAuthenticationSession?
  private var pendingResult: FlutterResult?
  private var presentationWindow: UIWindow?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.shacheni/system_web_auth", binaryMessenger: registrar.messenger())
    let instance = ShacheniWebAuth()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.publish(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "authenticate" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard session == nil else {
      result(FlutterError(code: "AUTH_BUSY", message: "Sign-in is already open.", details: nil))
      return
    }
    guard let args = call.arguments as? [String: String],
      let rawURL = args["url"], let url = URL(string: rawURL),
      url.scheme == "https", url.host != nil, url.path == "/auth/v1/authorize",
      let callbackScheme = args["callbackScheme"],
      callbackScheme == "com.shacheni.shacheniapp"
    else {
      result(FlutterError(code: "AUTH_INVALID_URL", message: "Invalid sign-in URL.", details: nil))
      return
    }
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
    guard let window = windows.first(where: { $0.isKeyWindow }) else {
      result(FlutterError(code: "AUTH_NO_WINDOW", message: "Sign-in needs an active window.", details: nil))
      return
    }

    presentationWindow = window
    pendingResult = result
    let next = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) {
      [weak self] returnedURL, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error = error as? ASWebAuthenticationSessionError,
          error.code == .canceledLogin
        {
          self.finish(nil)
        } else if error != nil || returnedURL == nil {
          self.finish(FlutterError(code: "AUTH_FAILED", message: "Sign-in could not finish.", details: nil))
        } else {
          self.finish(returnedURL?.absoluteString)
        }
      }
    }
    next.presentationContextProvider = self
    next.prefersEphemeralWebBrowserSession = false
    session = next
    if !next.start() {
      finish(FlutterError(code: "AUTH_FAILED", message: "Sign-in could not open.", details: nil))
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    // Set before start(), and held until the session's completion callback.
    return presentationWindow!
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    session?.cancel()
    finish(nil)
  }

  private func finish(_ value: Any?) {
    let result = pendingResult
    pendingResult = nil
    session = nil
    presentationWindow = nil
    result?(value)
  }
}
