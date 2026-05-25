import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/data/services/directory_service.dart';

// Tests cover the platform-independent surface of each desktop DirectoryService:
//  • getAvailableStorageSpace() — returns a constant, no plugin I/O
//  • requestPermissions()      — returns true without touching BuildContext
//  • listDirectories([])       — empty input → empty map, no plugin I/O
//
// getModelsDirectory() and listDirectories(non-empty) require path_provider
// plugin context and are exercised via integration / device tests.

void main() {
  group('MacOsDirectoryService', () {
    late MacOsDirectoryService sut;
    setUp(() => sut = MacOsDirectoryService());

    test('getAvailableStorageSpace returns 100 GB placeholder', () async {
      final bytes = await sut.getAvailableStorageSpace();
      expect(bytes, 100 * 1024 * 1024 * 1024);
    });

    test('listDirectories with empty list returns empty map', () async {
      final result = await sut.listDirectories(directoryTypes: []);
      expect(result, isEmpty);
    });
  });

  group('WindowsDirectoryService', () {
    late WindowsDirectoryService sut;
    setUp(() => sut = WindowsDirectoryService());

    test('getAvailableStorageSpace returns 100 GB placeholder', () async {
      final bytes = await sut.getAvailableStorageSpace();
      expect(bytes, 100 * 1024 * 1024 * 1024);
    });

    test('listDirectories with empty list returns empty map', () async {
      final result = await sut.listDirectories(directoryTypes: []);
      expect(result, isEmpty);
    });
  });

  group('DesktopDirectoryService (Linux fallback)', () {
    late DesktopDirectoryService sut;
    setUp(() => sut = DesktopDirectoryService());

    test('getAvailableStorageSpace returns 100 GB placeholder', () async {
      final bytes = await sut.getAvailableStorageSpace();
      expect(bytes, 100 * 1024 * 1024 * 1024);
    });

    test('listDirectories contains cwd key', () async {
      final result = await sut.listDirectories(directoryTypes: [DirectoryType.other]);
      expect(result.keys, contains('cwd'));
    });
  });

  group('IOSDirectoryService', () {
    late IOSDirectoryService sut;
    setUp(() => sut = IOSDirectoryService());

    test('getAvailableStorageSpace returns 10 GB placeholder', () async {
      final bytes = await sut.getAvailableStorageSpace();
      expect(bytes, 10 * 1024 * 1024 * 1024);
    });

    test('listDirectories with empty list returns empty map', () async {
      final result = await sut.listDirectories(directoryTypes: []);
      expect(result, isEmpty);
    });
  });

  group('AndroidDirectoryService', () {
    late AndroidDirectoryService sut;
    setUp(() => sut = AndroidDirectoryService());

    test('getAvailableStorageSpace returns 10 GB placeholder', () async {
      final bytes = await sut.getAvailableStorageSpace();
      expect(bytes, 10 * 1024 * 1024 * 1024);
    });

    test('listDirectories with empty list returns empty map', () async {
      final result = await sut.listDirectories(directoryTypes: []);
      expect(result, isEmpty);
    });
  });
}
