import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class IOSDirectoryService {
  /// Lists all GGUF files available in iOS sandboxed directories
  static Future<List<String>> findGGUFFiles() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('This service is only for iOS');
    }

    final List<String> ggufFiles = [];

    try {
      // Get Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      print('iOS Documents directory: ${documentsDir.path}');
      
      // Search in Documents directory
      if (await documentsDir.exists()) {
        final files = documentsDir.listSync(recursive: false);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
            ggufFiles.add(file.path);
            print('Found GGUF file in Documents: ${file.path}');
          }
        }
      }

      // Try to get Downloads directory (iOS 14+)
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          print('iOS Downloads directory: ${downloadsDir.path}');
          
          if (await downloadsDir.exists()) {
            final files = downloadsDir.listSync(recursive: false);
            for (final file in files) {
              if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
                ggufFiles.add(file.path);
                print('Found GGUF file in Downloads: ${file.path}');
              }
            }
          }
        }
      } catch (e) {
        print('Downloads directory not accessible or available: $e');
      }

      // Also check temporary directory as fallback
      final tempDir = await getTemporaryDirectory();
      print('iOS Temporary directory: ${tempDir.path}');
      
      if (await tempDir.exists()) {
        final files = tempDir.listSync(recursive: false);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
            ggufFiles.add(file.path);
            print('Found GGUF file in Temporary: ${file.path}');
          }
        }
      }

      // Remove duplicates if any
      return ggufFiles.toSet().toList();

    } catch (e) {
      print('Error accessing iOS directories: $e');
      return [];
    }
  }

  /// Lists all available iOS directories and their contents for debugging
  static Future<Map<String, List<String>>> listAllDirectories() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('This service is only for iOS');
    }

    final Map<String, List<String>> directoryContents = {};

    try {
      // Documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final docFiles = documentsDir.listSync(recursive: false);
      directoryContents['Documents (${documentsDir.path})'] = 
          docFiles.map((file) => path.basename(file.path)).toList();

      // Downloads directory
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null && await downloadsDir.exists()) {
          final downloadFiles = downloadsDir.listSync(recursive: false);
          directoryContents['Downloads (${downloadsDir.path})'] = 
              downloadFiles.map((file) => path.basename(file.path)).toList();
        }
      } catch (e) {
        directoryContents['Downloads'] = ['Not accessible: $e'];
      }

      // Temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync(recursive: false);
      directoryContents['Temporary (${tempDir.path})'] = 
          tempFiles.map((file) => path.basename(file.path)).toList();

      // Application Support directory
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        final appSupportFiles = appSupportDir.listSync(recursive: false);
        directoryContents['Application Support (${appSupportDir.path})'] = 
            appSupportFiles.map((file) => path.basename(file.path)).toList();
      } catch (e) {
        directoryContents['Application Support'] = ['Not accessible: $e'];
      }

      // Library directory (if accessible)
      try {
        final libraryDir = await getLibraryDirectory();
        final libraryFiles = libraryDir.listSync(recursive: false);
        directoryContents['Library (${libraryDir.path})'] = 
            libraryFiles.map((file) => path.basename(file.path)).toList();
      } catch (e) {
        directoryContents['Library'] = ['Not accessible: $e'];
      }

    } catch (e) {
      print('Error listing iOS directories: $e');
    }

    return directoryContents;
  }

  /// Prints a detailed report of all iOS directories and their contents
  static Future<void> printDirectoryReport() async {
    if (!Platform.isIOS) {
      print('Directory report is only available on iOS');
      return;
    }

    print('=== iOS Directory Report ===');
    
    final directories = await listAllDirectories();
    
    for (final entry in directories.entries) {
      print('\n📁 ${entry.key}');
      print('   Files: ${entry.value.length}');
      
      if (entry.value.isEmpty) {
        print('   (empty)');
      } else {
        for (final file in entry.value) {
          print('   - $file');
        }
      }
    }

    // Also show GGUF files specifically
    final ggufFiles = await findGGUFFiles();
    print('\n🎯 GGUF Files Found: ${ggufFiles.length}');
    for (final gguf in ggufFiles) {
      print('   - ${path.basename(gguf)} (${gguf})');
    }
  }

  /// Gets the path for a specific file in the Documents directory
  static Future<String> getDocumentsFilePath(String fileName) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('This service is only for iOS');
    }
    
    final documentsDir = await getApplicationDocumentsDirectory();
    return path.join(documentsDir.path, fileName);
  }

  /// Checks if a file exists in any of the iOS accessible directories
  static Future<String?> findFileInIOSDirectories(String fileName) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('This service is only for iOS');
    }

    // Check Documents directory
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final documentsPath = path.join(documentsDir.path, fileName);
      if (File(documentsPath).existsSync()) {
        return documentsPath;
      }
    } catch (e) {
      print('Error checking Documents directory: $e');
    }

    // Check Downloads directory
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final downloadsPath = path.join(downloadsDir.path, fileName);
        if (File(downloadsPath).existsSync()) {
          return downloadsPath;
        }
      }
    } catch (e) {
      print('Error checking Downloads directory: $e');
    }

    // Check Temporary directory
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, fileName);
      if (File(tempPath).existsSync()) {
        return tempPath;
      }
    } catch (e) {
      print('Error checking Temporary directory: $e');
    }

    return null;
  }
} 