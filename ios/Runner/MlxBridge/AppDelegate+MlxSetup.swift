// AppDelegate extension — registers the MLX bridge with the Flutter engine.
//
// Add this file to Runner target in Xcode.
// ⚠️  Requires MlxInferenceBridge.swift + generated MlxInference.g.swift.

import Flutter
import UIKit

extension AppDelegate {

    /// Call from application(_:didFinishLaunchingWithOptions:) after
    /// GeneratedPluginRegistrant.register(with:).
    func setupMlxBridge() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        let messenger = controller.binaryMessenger

        let bridge = MlxInferenceBridge()
        let tokenHandler = MlxTokenStreamHandler()
        bridge.streamHandler = tokenHandler

        // Register the host API (Dart → Swift commands)
        MlxInferenceHostApiSetup.setUp(binaryMessenger: messenger, api: bridge)

        // Register the event channel (Swift → Dart token stream)
        OnTokenStreamHandler.register(
            with: messenger,
            streamHandler: tokenHandler
        )
    }
}
