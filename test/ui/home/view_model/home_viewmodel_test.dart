import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:little_star_app/core/platform/platform_adapter.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/data/services/onboarding_service.dart';
import 'package:little_star_app/ui/home/view_model/home_viewmodel.dart';

class _FakePlatformAdapter implements PlatformAdapter {
  @override
  final bool supportsMlx;

  _FakePlatformAdapter({required this.supportsMlx});

  @override
  String get platformId => 'test';

  @override
  bool get supportsInference => true;

  @override
  DirectoryService get directoryService => DesktopDirectoryService();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS exposes MLX only on Apple Silicon', () {
    expect(MacOSPlatformAdapter(abi: Abi.macosArm64).supportsMlx, isTrue);
    expect(MacOSPlatformAdapter(abi: Abi.macosX64).supportsMlx, isFalse);
  });

  test('supportsMlx reflects the injected platform capability', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    HomeViewModel createViewModel(bool supportsMlx) => HomeViewModel(
      hfService: HuggingFaceService(),
      downloadService: DownloadService(),
      downloadRepository: DownloadRepository(),
      directoryService: DesktopDirectoryService(),
      onboardingService: OnboardingService(preferences),
      platformAdapter: _FakePlatformAdapter(supportsMlx: supportsMlx),
    );

    expect(createViewModel(true).supportsMlx, isTrue);
    expect(createViewModel(false).supportsMlx, isFalse);
  });
}
