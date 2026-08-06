package tw.twinkleai.little_star_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceTelemetryHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceTelemetryBridge(applicationContext),
        )
    }
}
