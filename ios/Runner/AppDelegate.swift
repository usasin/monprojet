import Flutter
import UIKit
import AppTrackingTransparency

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var trackingObserver: NSObjectProtocol?
  private var trackingChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "ProspectoPrivacy") {
      trackingChannel = FlutterMethodChannel(name: "prospecto/privacy", binaryMessenger: registrar.messenger())
      trackingChannel?.setMethodCallHandler { [weak self] call, result in
        guard call.method == "requestTracking" else { result(FlutterMethodNotImplemented); return }
        DispatchQueue.main.async { self?.requestTracking(result) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func trackingStatus(_ status: ATTrackingManager.AuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  private func requestTracking(_ result: @escaping FlutterResult) {
    let status = ATTrackingManager.trackingAuthorizationStatus
    if status != .notDetermined { result(trackingStatus(status)); return }
    guard UIApplication.shared.applicationState == .active else {
      trackingObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self = self else { result("notDetermined"); return }
        if let observer = self.trackingObserver { NotificationCenter.default.removeObserver(observer) }
        self.trackingObserver = nil
        self.requestTracking(result)
      }
      return
    }
    ATTrackingManager.requestTrackingAuthorization { [weak self] status in
      DispatchQueue.main.async { result(self?.trackingStatus(status) ?? "notDetermined") }
    }
  }
}
