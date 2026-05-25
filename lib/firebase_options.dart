// Stub for platforms where Firebase is not configured (macOS, Windows, Linux).
// On Android/iOS, this file is replaced by the real firebase_options.dart
// generated via `flutterfire configure`. That file is gitignored.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured for this platform. '
      'Run `flutterfire configure` to generate firebase_options.dart.',
    );
  }
}
