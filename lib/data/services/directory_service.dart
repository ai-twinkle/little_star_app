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
}

class AndroidDirectoryService implements DirectoryService {
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
          directoryContents[directoryType.name] = documentsDir.listSync(recursive: false).map((file) => file.path).toList();
          break;
        case DirectoryType.downloads:
          final downloadsDir = await getDownloadsDirectory();
          directoryContents[directoryType.name] = downloadsDir?.listSync(recursive: false).map((file) => file.path).toList() ?? [];
          break;
        case DirectoryType.temporary:
          final tempDir = await getTemporaryDirectory();
          directoryContents[directoryType.name] = tempDir.listSync(recursive: false).map((file) => file.path).toList();
          break;
        case DirectoryType.applicationSupport:
          final appSupportDir = await getApplicationSupportDirectory();
          directoryContents[directoryType.name] = appSupportDir.listSync(recursive: false).map((file) => file.path).toList();
          break;
        case DirectoryType.library:
          final libraryDir = await getLibraryDirectory();
          directoryContents[directoryType.name] = libraryDir.listSync(recursive: false).map((file) => file.path).toList();
          break;
        case DirectoryType.external:
          final externalDir = await getExternalStorageDirectory();
          directoryContents[directoryType.name] = externalDir?.listSync(recursive: false).map((file) => file.path).toList() ?? [];
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

    listDirectories(directoryTypes: directoryTypes).then((directoryContents) {
      for (var directoryType in directoryTypes) {
        switch (directoryType) {
          case DirectoryType.documents:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          case DirectoryType.downloads:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          case DirectoryType.temporary:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          case DirectoryType.applicationSupport:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          case DirectoryType.library:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          case DirectoryType.external:
            foundFiles.addAll(directoryContents[directoryType.name] ?? []);
            break;
          default:
            break;
        }
      }
    });

    if (fileName != null) {
      foundFiles.addAll(foundFiles.where((file) => file.contains(fileName)).toList());
    }

    if (extension != null) {
      foundFiles.addAll(foundFiles.where((file) => file.endsWith(extension)).toList());
    }

    return foundFiles;
  }
}

class IOSDirectoryService implements DirectoryService {
  @override
  Future<Map<String, List<String>>> listDirectories({required List<DirectoryType> directoryTypes}) async {
    return {};
  }

  @override
  Future<List<String>> findFiles({required List<DirectoryType> directoryTypes, String? fileName, String? extension}) async {
    return [];
  }
}



