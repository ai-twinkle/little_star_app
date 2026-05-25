// SPIKE BRANCH STUB — firebase_options.dart
// The real file is gitignored (contains API keys). This stub lets the app
// compile and launch on spike branches. Firebase features will be unavailable.
// Replace with the real file (from `flutterfire configure`) before shipping.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  /// True when this file is a spike-branch stub (no real Firebase keys).
  static const bool isStub = true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _stub;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _stub;
      case TargetPlatform.iOS:
        return _stub;
      case TargetPlatform.macOS:
        return _stub;
      default:
        throw UnsupportedError('No stub for ${defaultTargetPlatform.name}');
    }
  }

  static const _stub = FirebaseOptions(
    apiKey: 'STUB_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'stub-project',
    storageBucket: 'stub-project.appspot.com',
    iosBundleId: 'tw.twinkleai.little-star-app',
    androidClientId: null,
    iosClientId: null,
  );
}
