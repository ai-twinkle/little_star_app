import 'package:battery_plus/battery_plus.dart';
import 'package:little_star_app/utils/logger.dart';

/// Reads the device's current battery level (0-100).
///
/// Kept as its own small interface — mirroring [ThermalProbe] — so benchmark
/// recorder logic can be unit-tested without a platform channel.
abstract class BatteryProbe {
  /// Battery percentage (0-100), or null if unavailable (e.g. desktop/web,
  /// or the platform call failed).
  Future<int?> currentBatteryLevel();
}

/// Production implementation — delegates to the `battery_plus` plugin.
class PluginBatteryProbe implements BatteryProbe {
  final Battery _battery;
  final Logger _log = Logger('PluginBatteryProbe');

  PluginBatteryProbe({Battery? battery}) : _battery = battery ?? Battery();

  @override
  Future<int?> currentBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      _log.warn('batteryLevel failed: $e');
      return null;
    }
  }
}
