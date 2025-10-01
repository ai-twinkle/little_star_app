import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ios_directory_service.dart';

/// Represents a GGUF model file with metadata
class GGUFModelInfo {
  final String filePath;
  final String fileName;
  final int fileSize; // in bytes
  final String formattedSize; // human readable

  GGUFModelInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  }) : formattedSize = _formatFileSize(fileSize);

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// Service for selecting and managing GGUF model files across platforms
class ModelSelectionService {
  /// Scans for GGUF files based on platform
  /// Returns a list of GGUFModelInfo objects
  Future<List<GGUFModelInfo>> scanForGGUFFiles() async {
    if (Platform.isAndroid) {
      return _scanAndroidDirectories();
    } else if (Platform.isIOS) {
      return _scanIOSDirectories();
    } else {
      // Desktop platforms (Windows, macOS, Linux)
      return _scanDesktopDirectories();
    }
  }

  /// Android-specific scanning with permission handling
  Future<List<GGUFModelInfo>> _scanAndroidDirectories() async {
    final List<GGUFModelInfo> ggufFiles = [];

    // Check storage permissions
    final storageStatus = await Permission.storage.status;
    final manageStatus = await Permission.manageExternalStorage.status;

    if (!storageStatus.isGranted && !manageStatus.isGranted) {
      throw Exception('Storage permission required to access model files');
    }

    // Common Android directories to scan
    final directoriesToScan = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/DCIM', // Some users might store files here
    ];

    for (final dirPath in directoriesToScan) {
      final directory = Directory(dirPath);
      if (await directory.exists()) {
        await _scanDirectoryForGGUF(directory, ggufFiles);
      }
    }

    return ggufFiles;
  }

  /// iOS-specific scanning using the existing IOSDirectoryService
  Future<List<GGUFModelInfo>> _scanIOSDirectories() async {
    final List<String> filePaths = await IOSDirectoryService.findGGUFFiles();
    final List<GGUFModelInfo> ggufFiles = [];

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        ggufFiles.add(GGUFModelInfo(
          filePath: filePath,
          fileName: path.basename(filePath),
          fileSize: stat.size,
        ));
      }
    }

    return ggufFiles;
  }

  /// Desktop-specific scanning (current working directory and common locations)
  Future<List<GGUFModelInfo>> _scanDesktopDirectories() async {
    final List<GGUFModelInfo> ggufFiles = [];

    // Current working directory
    final currentDir = Directory.current;
    await _scanDirectoryForGGUF(currentDir, ggufFiles);

    // User's home directory
    try {
      final homeDir = Directory(Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '');
      if (await homeDir.exists()) {
        await _scanDirectoryForGGUF(homeDir, ggufFiles);
        // Also check Downloads folder in home
        final downloadsDir = Directory(path.join(homeDir.path, 'Downloads'));
        if (await downloadsDir.exists()) {
          await _scanDirectoryForGGUF(downloadsDir, ggufFiles);
        }
      }
    } catch (e) {
      // Ignore errors for home directory scanning
    }

    // Documents directory
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      await _scanDirectoryForGGUF(documentsDir, ggufFiles);
    } catch (e) {
      // Ignore errors for documents directory
    }

    return ggufFiles;
  }

  /// Helper method to scan a directory for .gguf files
  Future<void> _scanDirectoryForGGUF(Directory directory, List<GGUFModelInfo> results) async {
    try {
      await for (final entity in directory.list(recursive: false, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
          final stat = await entity.stat();
          results.add(GGUFModelInfo(
            filePath: entity.path,
            fileName: path.basename(entity.path),
            fileSize: stat.size,
          ));
        }
      }
    } catch (e) {
      // Ignore directories that can't be accessed
    }
  }

  /// Requests storage permissions on Android
  Future<bool> requestAndroidPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;

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
            'This app needs access to your Downloads folder to load AI models. Please grant "All files access" permission in the next screen.',
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

      if (shouldRequest == true) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
    }

    return manageStatus.isGranted;
  }
}
