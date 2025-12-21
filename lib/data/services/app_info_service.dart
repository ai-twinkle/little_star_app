import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Service for retrieving application and device information
class AppInfoService {
  PackageInfo? _packageInfo;
  DeviceInfoPlugin? _deviceInfo;

  /// Get package information (app version, build number, etc.)
  Future<PackageInfo> getPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// Get app version string (e.g., "0.0.3")
  Future<String> getAppVersion() async {
    final info = await getPackageInfo();
    return info.version;
  }

  /// Get build number string
  Future<String> getBuildNumber() async {
    final info = await getPackageInfo();
    return info.buildNumber;
  }

  /// Get app name
  Future<String> getAppName() async {
    final info = await getPackageInfo();
    return info.appName;
  }

  /// Get package name
  Future<String> getPackageName() async {
    final info = await getPackageInfo();
    return info.packageName;
  }

  /// Get full version string with build number (e.g., "0.0.3 (1)")
  Future<String> getFullVersion() async {
    final info = await getPackageInfo();
    return '${info.version} (${info.buildNumber})';
  }

  /// Get device information
  Future<Map<String, String>> getDeviceInfo() async {
    _deviceInfo ??= DeviceInfoPlugin();
    final Map<String, String> deviceData = {};

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo!.androidInfo;
      deviceData['platform'] = 'Android';
      deviceData['version'] = 'Android ${androidInfo.version.release}';
      deviceData['model'] = androidInfo.model;
      deviceData['manufacturer'] = androidInfo.manufacturer;
      deviceData['device'] = androidInfo.device;
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo!.iosInfo;
      deviceData['platform'] = 'iOS';
      deviceData['version'] = 'iOS ${iosInfo.systemVersion}';
      deviceData['model'] = iosInfo.model;
      deviceData['name'] = iosInfo.name;
      deviceData['systemName'] = iosInfo.systemName;
    } else if (Platform.isMacOS) {
      final macInfo = await _deviceInfo!.macOsInfo;
      deviceData['platform'] = 'macOS';
      deviceData['version'] = macInfo.osRelease;
      deviceData['model'] = macInfo.model;
      deviceData['computerName'] = macInfo.computerName;
    } else if (Platform.isWindows) {
      final windowsInfo = await _deviceInfo!.windowsInfo;
      deviceData['platform'] = 'Windows';
      deviceData['version'] = windowsInfo.productName;
      deviceData['computerName'] = windowsInfo.computerName;
    } else if (Platform.isLinux) {
      final linuxInfo = await _deviceInfo!.linuxInfo;
      deviceData['platform'] = 'Linux';
      deviceData['version'] = linuxInfo.prettyName;
      deviceData['name'] = linuxInfo.name;
    }

    return deviceData;
  }

  /// Get storage paths information
  Future<Map<String, String>> getStorageInfo() async {
    final Map<String, String> paths = {};

    try {
      final tempDir = await getTemporaryDirectory();
      paths['Temporary'] = tempDir.path;
    } catch (e) {
      paths['Temporary'] = 'Not available';
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      paths['Documents'] = appDocDir.path;
    } catch (e) {
      paths['Documents'] = 'Not available';
    }

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      paths['App Support'] = appSupportDir.path;
    } catch (e) {
      paths['App Support'] = 'Not available';
    }

    if (Platform.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          paths['External Storage'] = externalDir.path;
        }
      } catch (e) {
        paths['External Storage'] = 'Not available';
      }
    }

    return paths;
  }

  /// Get llama.cpp version (placeholder - would need native bridge)
  Future<String> getLlamaCppVersion() async {
    // TODO: Implement native method to get llama.cpp version
    // For now, return a placeholder based on recent commits
    return 'b7493 (2025-12-21)';
  }

  /// Get Flutter SDK version
  String getFlutterVersion() {
    // This is a compile-time constant, would need to be updated manually
    // or read from a config file
    return Platform.version.split(' ').first;
  }
}
