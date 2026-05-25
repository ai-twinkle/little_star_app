import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum DirectoryType {
  documents,
  downloads,
  temporary,
  applicationSupport,
  library,
  external,
  other,
}

abstract class DirectoryService {
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes});

  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension});

  Future<bool> requestPermissions({required BuildContext context});

  /// Returns the directory for storing downloaded models.
  /// Creates the directory if it doesn't exist.
  Future<Directory> getModelsDirectory();

  /// Returns available storage space in bytes.
  Future<int> getAvailableStorageSpace();
}

class AndroidDirectoryService implements DirectoryService {
  @override
  Future<Directory> getModelsDirectory() async {
    // Prefer external Downloads folder for user visibility
    final downloadDir = Directory('/storage/emulated/0/Download/LittleStar/models');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  @override
  Future<int> getAvailableStorageSpace() async {
    // FileStat doesn't provide free space; proper implementation needs platform channel
    // For now, return a large value as placeholder
    return 10 * 1024 * 1024 * 1024; // 10 GB placeholder
  }

  @override
  Future<bool> requestPermissions({required BuildContext context}) async {
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
    }
    
    if (storageStatus.isGranted) {
      return true;
    }
    
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isDenied) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs access to Downloads folder to load AI models. Please grant "All files access" permission in the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Grant'),
            ),
          ],
        ),
      );
      
      if (shouldRequest != true) return false;
      
      manageStatus = await Permission.manageExternalStorage.request();
    }
    
    return manageStatus.isGranted;
  }

  
  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    final Map<String, List<String>> directoryContents = {};

    for (var directoryType in directoryTypes) {
      switch (directoryType) {
        case DirectoryType.documents:
          final documentsDir = await getApplicationDocumentsDirectory();
          directoryContents[directoryType.name] = documentsDir
              .listSync(recursive: false)
              .map((file) => file.path)
              .toList();
          break;
        case DirectoryType.downloads:
          // getDownloadsDirectory() is often null on Android; fallback to common path
          final downloadsDir = await getDownloadsDirectory();
          final List<String> entries = [];
          if (downloadsDir != null && downloadsDir.existsSync()) {
            entries.addAll(downloadsDir.listSync(recursive: false).map((e) => e.path));
          }
          final fallback = Directory('/storage/emulated/0/Download');
          if (fallback.existsSync()) {
            entries.addAll(fallback.listSync(recursive: false).map((e) => e.path));
          }
          directoryContents[directoryType.name] = entries;
          break;
        case DirectoryType.temporary:
          final tempDir = await getTemporaryDirectory();
          directoryContents[directoryType.name] = tempDir
              .listSync(recursive: false)
              .map((file) => file.path)
              .toList();
          break;
        case DirectoryType.applicationSupport:
          final appSupportDir = await getApplicationSupportDirectory();
          directoryContents[directoryType.name] = appSupportDir
              .listSync(recursive: false)
              .map((file) => file.path)
              .toList();
          break;
        case DirectoryType.library:
          final libraryDir = await getLibraryDirectory();
          directoryContents[directoryType.name] = libraryDir
              .listSync(recursive: false)
              .map((file) => file.path)
              .toList();
          break;
        case DirectoryType.external:
          final externalDir = await getExternalStorageDirectory();
          directoryContents[directoryType.name] = externalDir
                  ?.listSync(recursive: false)
                  .map((file) => file.path)
                  .toList() ??
              [];
          break;
        default:
          break;
      }
    }
    return directoryContents;
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    final List<String> foundFiles = [];

    final directoryContents = await listDirectories(directoryTypes: directoryTypes);
    for (final entry in directoryContents.entries) {
      for (final p in entry.value) {
        final f = File(p);
        final d = Directory(p);
        if (f.existsSync()) {
          final nameOk = fileName == null || path.basename(p).contains(fileName);
          final extOk = extension == null || p.toLowerCase().endsWith(extension.toLowerCase());
          if (nameOk && extOk) {
            foundFiles.add(p);
          }
        } else if (d.existsSync()) {
          for (final child in d.listSync(recursive: true, followLinks: false)) {
            final cp = child.path;
            if (File(cp).existsSync()) {
              final nameOk = fileName == null || path.basename(cp).contains(fileName);
              final extOk = extension == null || cp.toLowerCase().endsWith(extension.toLowerCase());
              if (nameOk && extOk) {
                foundFiles.add(cp);
              }
            }
          }
        }
      }
    }

    // Deduplicate
    return foundFiles.toSet().toList();
  }
}

class IOSDirectoryService implements DirectoryService {
  @override
  Future<Directory> getModelsDirectory() async {
    // Use Documents folder so users can see models in Files app
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(documentsDir.path, 'Models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  @override
  Future<int> getAvailableStorageSpace() async {
    // Proper implementation needs platform channel
    // For now, return a large value as placeholder
    return 10 * 1024 * 1024 * 1024; // 10 GB placeholder
  }

  @override
  Future<bool> requestPermissions({required BuildContext context}) async {
    // iOS doesn't require explicit permissions for app sandboxed directories
    return true;
  }

  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    final Map<String, List<String>> directoryContents = {};
    for (var directoryType in directoryTypes) {
      switch (directoryType) {
        case DirectoryType.documents:
          final dir = await getApplicationDocumentsDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.applicationSupport:
          final dir = await getApplicationSupportDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.library:
          final dir = await getLibraryDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.temporary:
          final dir = await getTemporaryDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        default:
          break;
      }
    }
    return directoryContents;
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    final List<String> foundFiles = [];
    final directoryContents = await listDirectories(directoryTypes: directoryTypes);
    for (final entry in directoryContents.entries) {
      for (final p in entry.value) {
        final f = File(p);
        final d = Directory(p);
        if (f.existsSync()) {
          final nameOk = fileName == null || path.basename(p).contains(fileName);
          final extOk = extension == null || p.toLowerCase().endsWith(extension.toLowerCase());
          if (nameOk && extOk) {
            foundFiles.add(p);
          }
        } else if (d.existsSync()) {
          for (final child in d.listSync(recursive: true, followLinks: false)) {
            final cp = child.path;
            if (File(cp).existsSync()) {
              final nameOk = fileName == null || path.basename(cp).contains(fileName);
              final extOk = extension == null || cp.toLowerCase().endsWith(extension.toLowerCase());
              if (nameOk && extOk) {
                foundFiles.add(cp);
              }
            }
          }
        }
      }
    }
    return foundFiles.toSet().toList();
  }
}

class MacOsDirectoryService implements DirectoryService {
  @override
  Future<Directory> getModelsDirectory() async {
    // Application Support is sandbox-safe and persists across app updates
    final appSupportDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(path.join(appSupportDir.path, 'Models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  @override
  Future<int> getAvailableStorageSpace() async {
    return 100 * 1024 * 1024 * 1024; // 100 GB placeholder
  }

  @override
  Future<bool> requestPermissions({required BuildContext context}) async {
    return true;
  }

  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    final Map<String, List<String>> directoryContents = {};
    for (final directoryType in directoryTypes) {
      switch (directoryType) {
        case DirectoryType.documents:
          final dir = await getApplicationDocumentsDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.applicationSupport:
          final dir = await getApplicationSupportDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.temporary:
          final dir = await getTemporaryDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.downloads:
          final dir = await getDownloadsDirectory();
          directoryContents[directoryType.name] = dir?.listSync(recursive: false).map((e) => e.path).toList() ?? [];
          break;
        default:
          break;
      }
    }
    return directoryContents;
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    final List<String> results = [];
    final modelsDir = await getModelsDirectory();
    for (final entity in modelsDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final p = entity.path;
        final nameOk = fileName == null || path.basename(p).contains(fileName);
        final extOk = extension == null || p.toLowerCase().endsWith(extension.toLowerCase());
        if (nameOk && extOk) results.add(p);
      }
    }
    return results.toSet().toList();
  }
}

class WindowsDirectoryService implements DirectoryService {
  @override
  Future<Directory> getModelsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(documentsDir.path, 'LittleStar', 'Models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  @override
  Future<int> getAvailableStorageSpace() async {
    return 100 * 1024 * 1024 * 1024; // 100 GB placeholder
  }

  @override
  Future<bool> requestPermissions({required BuildContext context}) async {
    return true;
  }

  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    final Map<String, List<String>> directoryContents = {};
    for (final directoryType in directoryTypes) {
      switch (directoryType) {
        case DirectoryType.documents:
          final dir = await getApplicationDocumentsDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.applicationSupport:
          final dir = await getApplicationSupportDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.temporary:
          final dir = await getTemporaryDirectory();
          directoryContents[directoryType.name] = dir.listSync(recursive: false).map((e) => e.path).toList();
          break;
        case DirectoryType.downloads:
          final dir = await getDownloadsDirectory();
          directoryContents[directoryType.name] = dir?.listSync(recursive: false).map((e) => e.path).toList() ?? [];
          break;
        default:
          break;
      }
    }
    return directoryContents;
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    final List<String> results = [];
    final modelsDir = await getModelsDirectory();
    for (final entity in modelsDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final p = entity.path;
        final nameOk = fileName == null || path.basename(p).contains(fileName);
        final extOk = extension == null || p.toLowerCase().endsWith(extension.toLowerCase());
        if (nameOk && extOk) results.add(p);
      }
    }
    return results.toSet().toList();
  }
}

/// Linux fallback — uses cwd; not sandboxed or production-ready.
class DesktopDirectoryService implements DirectoryService {
  @override
  Future<Directory> getModelsDirectory() async {
    final modelsDir = Directory(path.join(Directory.current.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  @override
  Future<int> getAvailableStorageSpace() async {
    return 100 * 1024 * 1024 * 1024; // 100 GB placeholder for desktop
  }

  @override
  Future<bool> requestPermissions({required BuildContext context}) async {
    return true;
  }

  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    final cwd = Directory.current;
    return {
      'cwd': [cwd.path]
    };
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    final List<String> results = [];
    for (final entity in Directory.current.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final p = entity.path;
        final nameOk = fileName == null || path.basename(p).contains(fileName);
        final extOk = extension == null || p.toLowerCase().endsWith(extension.toLowerCase());
        if (nameOk && extOk) results.add(p);
      }
    }
    return results.toSet().toList();
  }
}

class DirectoryServiceFactory {
  static DirectoryService create() {
    if (Platform.isAndroid) return AndroidDirectoryService();
    if (Platform.isIOS) return IOSDirectoryService();
    if (Platform.isMacOS) return MacOsDirectoryService();
    if (Platform.isWindows) return WindowsDirectoryService();
    return DesktopDirectoryService(); // Linux fallback
  }
}
