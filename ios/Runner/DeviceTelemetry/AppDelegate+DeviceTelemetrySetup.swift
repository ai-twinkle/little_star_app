// AppDelegate extension — registers the device telemetry bridge with the
// Flutter engine. Mirrors AppDelegate+MlxSetup.swift's pattern.
//
// Add this file to Runner target in Xcode.
// ⚠️  Requires DeviceTelemetryBridge.swift + generated DeviceTelemetry.g.swift.

import Flutter
import UIKit

extension AppDelegate {

    /// Call from application(_:didFinishLaunchingWithOptions:) after
    /// GeneratedPluginRegistrant.register(with:).
    func setupDeviceTelemetry() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        let messenger = controller.binaryMessenger
        DeviceTelemetryHostApiSetup.setUp(binaryMessenger: messenger, api: DeviceTelemetryBridge())
    }
}
