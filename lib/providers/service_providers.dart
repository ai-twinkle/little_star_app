import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/data/services/onboarding_service.dart';
import 'package:little_star_app/ui/models/view_model/model_manager_viewmodel.dart';

final directoryServiceProvider = Provider<DirectoryService>(
  (ref) => DirectoryServiceFactory.create(),
);

final huggingFaceServiceProvider = Provider<HuggingFaceService>(
  (ref) => HuggingFaceService(),
);

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(),
);

final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DownloadRepository(),
);

final modelManagerViewModelProvider =
    Provider.autoDispose<ModelManagerViewModel>((ref) {
      final viewModel = ModelManagerViewModel(
        hfService: ref.watch(huggingFaceServiceProvider),
        downloadService: ref.watch(downloadServiceProvider),
        downloadRepository: ref.watch(downloadRepositoryProvider),
        directoryService: ref.watch(directoryServiceProvider),
      );
      ref.onDispose(viewModel.dispose);
      return viewModel;
    });

final onboardingServiceProvider = FutureProvider<OnboardingService>(
  (ref) => OnboardingService.create(),
);

/// Selects the inference backend for a given model profile.
final backendSelectorProvider = Provider<BackendSelector>(
  (ref) => BackendSelector(),
);
