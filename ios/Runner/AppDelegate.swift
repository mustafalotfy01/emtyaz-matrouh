import Flutter
import UIKit
// Google Maps SDK for iOS
// Key is injected from ios/Flutter/Debug.xcconfig or Release.xcconfig at build time.
// DO NOT hardcode the API key here.
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Provide the iOS Maps API key (from xcconfig / Info.plist build variable)
    if let mapsKey = Bundle.main.infoDictionary?["IOS_MAPS_API_KEY"] as? String,
       !mapsKey.isEmpty, mapsKey != "$(IOS_MAPS_API_KEY)" {
      GMSServices.provideAPIKey(mapsKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
