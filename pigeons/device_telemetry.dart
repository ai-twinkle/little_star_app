// Pigeon API definition for device thermal telemetry (iOS + Android).
//
// Used by the C-line benchmark harness (2026-07-08-t1-benchmark-talk) to
// record ProcessInfo.thermalState (iOS) / PowerManager thermal status
// (Android) alongside TTFT/decode-tps/memory for each run, and to gate
// "cool down between runs" in the standardized test protocol.
//
// Generate with:
//   dart run pigeon --input pigeons/device_telemetry.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/platform/device_telemetry.g.dart',
  swiftOut: 'ios/Runner/DeviceTelemetry/DeviceTelemetry.g.swift',
  // MlxInference.g.swift is already generated into the same Runner target
  // and includes the shared PigeonError class; a second copy here would
  // fail to compile with "Invalid redeclaration of 'PigeonError'".
  swiftOptions: SwiftOptions(includeErrorClass: false),
  kotlinOut:
      'android/app/src/main/kotlin/tw/twinkleai/little_star_app/DeviceTelemetry.g.kt',
  kotlinOptions: KotlinOptions(package: 'tw.twinkleai.little_star_app'),
))

/// Normalized thermal pressure level, collapsing each platform's native scale
/// (iOS: 4 levels; Android: 7 levels, API 29+) onto a shared 4-point scale so
/// benchmark output is comparable across backends/devices.
enum ThermalStatus {
  nominal,
  fair,
  serious,
  critical,

  /// Reading unavailable — e.g. Android below API 29, or the platform call
  /// failed. Callers should treat this as "unknown", not "nominal".
  unknown,
}

@HostApi()
abstract class DeviceTelemetryHostApi {
  /// Current thermal pressure state.
  /// iOS: `ProcessInfo.processInfo.thermalState`.
  /// Android: `PowerManager.getCurrentThermalStatus()` (API 29+; returns
  /// [ThermalStatus.unknown] below API 29).
  ThermalStatus getThermalState();
}
