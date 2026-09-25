import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // The 10-band equalizer's iOS native surface (see
    // ios/Runner/CraunchEqualizerPlugin.swift) is not an installable pub
    // package — it's app-local native code — so it's wired up manually
    // here rather than through GeneratedPluginRegistrant, which only
    // knows about actual Flutter plugin packages.
    if let controller = window?.rootViewController as? FlutterViewController {
      CraunchEqualizerPlugin.register(with: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
