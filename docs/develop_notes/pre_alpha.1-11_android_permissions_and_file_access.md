# Android Permissions and File Access Implementation

**Date:** 2025.06.25 
**Author:** Bobson Lin  

## Overview

This document outlines the key changes made to handle Android runtime permissions and file access for loading GGUF model files from the Downloads directory. These changes address the security restrictions in modern Android versions and provide robust cross-platform file handling.

## Key Changes Implemented

### 1. Added Required Packages

Added two essential packages to `pubspec.yaml`:

```yaml
dependencies:
  permission_handler: ^11.0.1  # Runtime permission handling
  path_provider: ^2.1.1        # Proper Android path handling
```

**Purpose:**
- `permission_handler`: Enables requesting storage permissions at runtime
- `path_provider`: Provides proper path access methods for different platforms

### 2. Added Permission Request Function

Implemented `_requestPermissions()` function in `lib/main.dart`:

```dart
Future<bool> _requestPermissions() async {
  if (!Platform.isAndroid) return true;

  // Request storage permission
  final status = await Permission.storage.request();
  if (status.isGranted) {
    return true;
  }

  // For Android 11+, try manage external storage permission
  if (await Permission.manageExternalStorage.isDenied) {
    final manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }

  return status.isGranted;
}
```

**Features:**
- **Runtime Permission Requests**: Asks user for storage access when app starts
- **Android 11+ Compatibility**: Handles `MANAGE_EXTERNAL_STORAGE` permission for newer Android versions
- **User Feedback**: Shows permission request status to user
- **Cross-platform**: Only requests permissions on Android

### 3. Improved Path Handling

Enhanced file path resolution with multiple fallback options:

```dart
Future<String?> findModelFile() async {
  const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_S.gguf';
  
  if (Platform.isAndroid) {
    final possiblePaths = [
      '/storage/emulated/0/Download/$modelFileName',
      '/sdcard/Download/$modelFileName',
      '/storage/self/primary/Download/$modelFileName',
    ];

    for (final testPath in possiblePaths) {
      print('Checking path: $testPath');
      final file = File(testPath);
      if (file.existsSync()) {
        print('Found model file at: $testPath');
        return testPath;
      }
    }
    return null;
  }
  // ... other platforms
}
```

**Improvements:**
- **Multiple Fallback Paths**: Tries different Android storage paths
- **Better Error Handling**: Graceful handling when directories are inaccessible
- **Debug Information**: Extensive logging to identify path issues
- **Cross-platform Support**: Platform-specific path handling

### 4. Enhanced Model File Detection

Comprehensive file detection with debugging capabilities:

**Features:**
- **Multiple Path Search**: Searches various possible Android storage locations
- **Clear Feedback**: Provides detailed information about file location status
- **Downloads Directory Listing**: Lists available files for debugging
- **Robust Error Handling**: Continues functioning even if some paths fail

```dart
if (Platform.isAndroid && !modelExists) {
  // Try to list Downloads directory for debugging
  try {
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (downloadsDir.existsSync()) {
      final files = downloadsDir.listSync();
      print('Files in Downloads: ${files.map((f) => path.basename(f.path)).toList()}');
    } else {
      print('Downloads directory does not exist or is not accessible');
    }
  } catch (e) {
    print('Error accessing Downloads directory: $e');
  }
}
```

## Android Manifest Permissions

Added necessary permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Permissions for accessing external storage/Downloads folder -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

## Implementation Benefits

### Security Compliance
- Follows Android security best practices
- Requests permissions only when needed
- Handles permission denial gracefully

### Robustness
- Multiple fallback mechanisms
- Comprehensive error handling
- Platform-specific optimizations

### User Experience
- Clear status messages
- Informative error feedback
- Seamless permission requests

### Developer Experience
- Extensive debug logging
- Clear separation of concerns
- Easy maintenance and updates

## Usage Instructions

1. **Install Dependencies**: Run `flutter pub get` to install new packages
2. **Build and Install**: Rebuild app on Android device
3. **Grant Permissions**: Allow storage access when prompted
4. **Place Model File**: Ensure GGUF file is in Downloads folder
5. **Check Logs**: Monitor console output for detailed debugging information

## Troubleshooting

### Common Issues:
- **Permission Denied**: Ensure storage permissions are granted
- **File Not Found**: Check if file exists in Downloads directory
- **Path Access**: Verify Android version compatibility

### Debug Tools:
- Console logging shows exact paths being checked
- Downloads directory listing helps identify file location issues
- Status messages provide real-time feedback

## Future Improvements

- Implement file picker for user-selected model files
- Add support for other storage locations
- Enhance error recovery mechanisms
- Optimize permission request flow

## Related Files

- `lib/main.dart` - Main implementation
- `android/app/src/main/AndroidManifest.xml` - Permissions
- `pubspec.yaml` - Dependencies
- `lib/llama_ffi.dart` - FFI integration

---

**Note**: This implementation specifically addresses Android file access challenges while maintaining cross-platform compatibility. 