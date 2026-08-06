import 'dart:ffi';
import 'dart:io';

import 'package:little_star_app/data/services/directory_service.dart';

/// Abstraction over platform-specific capabilities used by the inference layer.
///
/// Each platform provides its own [directoryService], reports its [platformId],
/// and declares inference capabilities via [supportsInference] and
/// [supportsMlx].
abstract class PlatformAdapter {
  String get platformId;
  bool get supportsInference;
  bool get supportsMlx;
  DirectoryService get directoryService;

  /// Returns the [PlatformAdapter] for the running platform.
  static PlatformAdapter current() => PlatformAdapterFactory.create();
}

class AndroidPlatformAdapter implements PlatformAdapter {
  @override
  String get platformId => 'android';

  @override
  bool get supportsInference => true;

  @override
  bool get supportsMlx => false;

  @override
  DirectoryService get directoryService => AndroidDirectoryService();
}

class IOSPlatformAdapter implements PlatformAdapter {
  @override
  String get platformId => 'ios';

  @override
  bool get supportsInference => true;

  @override
  bool get supportsMlx => true;

  @override
  DirectoryService get directoryService => IOSDirectoryService();
}

class MacOSPlatformAdapter implements PlatformAdapter {
  final Abi _abi;

  MacOSPlatformAdapter({Abi? abi}) : _abi = abi ?? Abi.current();

  @override
  String get platformId => 'macos';

  @override
  bool get supportsInference => true;

  @override
  bool get supportsMlx => _abi == Abi.macosArm64;

  @override
  DirectoryService get directoryService => MacOsDirectoryService();
}

class WindowsPlatformAdapter implements PlatformAdapter {
  @override
  String get platformId => 'windows';

  /// llama.cpp Desktop planned for EP-1.
  @override
  bool get supportsInference => false;

  @override
  bool get supportsMlx => false;

  @override
  DirectoryService get directoryService => WindowsDirectoryService();
}

class LinuxPlatformAdapter implements PlatformAdapter {
  @override
  String get platformId => 'linux';

  @override
  bool get supportsInference => false;

  @override
  bool get supportsMlx => false;

  @override
  DirectoryService get directoryService => DesktopDirectoryService();
}

class PlatformAdapterFactory {
  static PlatformAdapter create() {
    if (Platform.isAndroid) return AndroidPlatformAdapter();
    if (Platform.isIOS) return IOSPlatformAdapter();
    if (Platform.isMacOS) return MacOSPlatformAdapter();
    if (Platform.isWindows) return WindowsPlatformAdapter();
    return LinuxPlatformAdapter();
  }
}
