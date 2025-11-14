import UIKit
import Flutter
import GoogleMaps   // <- IMPORTANT pour google_maps_flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {

    // Initialise Google Maps avec la clé stockée dans Info.plist (key: "GMSApiKey")
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
      print("✅ GMSApiKey chargée")
    } else {
      assertionFailure("❌ GMSApiKey manquante dans Info.plist")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
