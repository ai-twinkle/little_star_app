# iOS File Access Guide

This guide explains how to work with GGUF model files on iOS devices with your Little Star App.

## Overview

iOS apps run in a sandboxed environment, which means they can only access specific directories. Your app now properly handles iOS file access using the following directories:

1. **Documents Directory** - Primary storage for app files
2. **Downloads Directory** - System Downloads folder (iOS 14+)
3. **Temporary Directory** - Temporary files (cleared by system)
4. **Application Support Directory** - App-specific support files
5. **Library Directory** - App library files

## How to Add GGUF Files to Your iOS Device

### Method 1: Using Files App (Recommended)

1. **Download GGUF file to your device**:
   - Use Safari or another browser to download your GGUF model file
   - Files will typically be saved to the Downloads folder

2. **Copy to app's Documents folder**:
   - Open the iOS Files app
   - Navigate to "On My iPhone/iPad" → "Little Star App"
   - Create this folder if it doesn't exist
   - Copy your GGUF file here

3. **Verify in the app**:
   - Open Little Star App
   - Go to Model Testing page
   - Tap "Debug iOS Directories" to see available files
   - Use "Browse & Load GGUF" to load your model

### Method 2: Using iTunes/Finder File Sharing

1. **Connect your device** to your computer
2. **Open iTunes** (Windows) or **Finder** (macOS Catalina+)
3. **Select your device** when it appears
4. **Go to File Sharing** section
5. **Find "Little Star App"** in the list
6. **Drag and drop** your GGUF files into the app's documents area

### Method 3: Using AirDrop

1. **AirDrop the GGUF file** from another Apple device
2. **Choose "Save to Files"** when prompted
3. **Navigate to** "On My iPhone/iPad" → "Little Star App"
4. **Save the file** in the app's Documents folder

## App Features for iOS File Management

### Browse & Load GGUF Button

The app will search for GGUF files in the following order:
1. Documents directory
2. Downloads directory (if accessible)
3. Temporary directory

### Debug iOS Directories Button

**Location**: Model Testing page (only visible on iOS)

This debug feature will:
- Print a detailed report of all accessible directories
- List all files in each directory
- Show specifically which GGUF files are found
- Help troubleshoot file access issues

**How to use**:
1. Open Model Testing page
2. Tap "Debug iOS Directories" button
3. Check the console output in Xcode or your debug environment

### Console Output Example

```
=== iOS Directory Report ===

📁 Documents (/var/mobile/Containers/Data/Application/.../Documents)
   Files: 2
   - my-model.gguf
   - notes.txt

📁 Downloads (/var/mobile/Containers/Data/Application/.../Downloads)
   Files: 1
   - downloaded-model.gguf

📁 Temporary (/var/mobile/Containers/Data/Application/.../tmp)
   Files: 0
   (empty)

🎯 GGUF Files Found: 2
   - my-model.gguf (/var/mobile/Containers/Data/Application/.../Documents/my-model.gguf)
   - downloaded-model.gguf (/var/mobile/Containers/Data/Application/.../Downloads/downloaded-model.gguf)
```

## Permissions Added to iOS

The following permissions have been added to `ios/Runner/Info.plist`:

- **LSSupportsOpeningDocumentsInPlace**: Allows the app to work with documents in place
- **UIFileSharingEnabled**: Enables iTunes/Finder file sharing
- **UTImportedTypeDeclarations**: Registers GGUF file type with iOS

## Troubleshooting

### No GGUF Files Found

1. **Use the Debug button** to see what directories are accessible
2. **Check file location** - ensure GGUF files are in Documents or Downloads
3. **Verify file extension** - files must end with `.gguf`
4. **Try different transfer methods** if files aren't appearing

### Downloads Directory Not Accessible

This is normal on some iOS versions. The app will show:
```
Downloads directory not accessible or available: [error details]
```

**Solution**: Use the Documents directory instead via Files app or iTunes.

### File Permissions Issues

If you see permission errors:
1. **Restart the app** to refresh permissions
2. **Try copying files** to Documents directory instead
3. **Check iOS version** - some features require iOS 14+

## Best Practices

1. **Use Documents directory** for permanent storage of model files
2. **Keep file names simple** (no special characters or spaces)
3. **Use the Debug button** when troubleshooting file access
4. **Check file sizes** - ensure your device has enough storage
5. **Use compressed models** (Q4, Q8) for better performance on mobile

## Technical Details

### Directory Paths

- **Documents**: `/var/mobile/Containers/Data/Application/[UUID]/Documents`
- **Downloads**: `/var/mobile/Containers/Data/Application/[UUID]/Downloads`
- **Temporary**: `/var/mobile/Containers/Data/Application/[UUID]/tmp`

### Supported File Extensions

The app specifically looks for files ending with:
- `.gguf` (case-insensitive)

### Path Provider Integration

The app uses the `path_provider` Flutter package to access iOS directories properly, ensuring compatibility across different iOS versions.

---

For additional help, check the console output when using the "Debug iOS Directories" feature, which provides real-time information about file system access on your specific device. 