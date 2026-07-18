import 'package:flutter/services.dart';
import 'package:little_star_app/core/platform/device_telemetry.g.dart';
import 'package:little_star_app/utils/logger.dart';

export 'package:little_star_app/core/platform/device_telemetry.g.dart' show ThermalStatus;

/// Reads the device's current thermal pressure state.
///
/// Backed by [DeviceTelemetryHostApi] (iOS: `ProcessInfo.thermalState`;
/// Android: `PowerManager.getCurrentThermalStatus()`, API 29+). Kept as its
/// own small interface — mirroring [LlamaFfiDriver]/[MlxChannelDriver] — so
/// benchmark recorder logic can be unit-tested without a platform channel.
abstract class ThermalProbe {
  Future<ThermalStatus> currentThermalState();
}

/// Production implementation — delegates to the generated Pigeon API.
///
/// Returns [ThermalStatus.unknown] instead of throwing when the channel
/// isn't registered (e.g. macOS/web dev builds, or plain `flutter test`)
/// rather than crashing the caller — a benchmark run should still complete
/// with a degraded reading, not fail outright.
class PigeonThermalProbe implements ThermalProbe {
  final DeviceTelemetryHostApi _api;
  final Logger _log = Logger('PigeonThermalProbe');

  PigeonThermalProbe({DeviceTelemetryHostApi? api})
      : _api = api ?? DeviceTelemetryHostApi();

  @override
  Future<ThermalStatus> currentThermalState() async {
    try {
      return await _api.getThermalState();
    } on PlatformException catch (e) {
      _log.warn('getThermalState failed: $e');
      return ThermalStatus.unknown;
    } on MissingPluginException catch (e) {
      _log.warn('getThermalState channel not registered: $e');
      return ThermalStatus.unknown;
    }
  }
}
