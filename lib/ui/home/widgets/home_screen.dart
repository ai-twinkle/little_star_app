import 'dart:io';

import 'package:flutter/material.dart';

import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/data/services/onboarding_service.dart';
import 'package:little_star_app/models/gguf_model_info.dart';
import 'package:little_star_app/ui/completion/widgets/completion_screen.dart';
import 'package:little_star_app/ui/chat/widgets/chat_screen.dart';
import 'package:little_star_app/ui/home/view_model/home_viewmodel.dart';
import 'package:little_star_app/ui/home/widgets/downloaded_models_section.dart';
import 'package:little_star_app/ui/home/widgets/onboarding_guide.dart';
import 'package:little_star_app/ui/home/widgets/recommended_model_card.dart';
import 'package:little_star_app/ui/home/widgets/skeleton_loader.dart';
import 'package:little_star_app/ui/models/view_model/model_manager_viewmodel.dart';
import 'package:little_star_app/ui/models/widgets/model_manager_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeViewModel _viewModel;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initViewModel();
  }

  Future<void> _initViewModel() async {
    final directoryService = Platform.isAndroid
        ? AndroidDirectoryService()
        : Platform.isIOS
            ? IOSDirectoryService()
            : DesktopDirectoryService();

    final onboardingService = await OnboardingService.create();

    _viewModel = HomeViewModel(
      hfService: HuggingFaceService(),
      downloadService: DownloadService(),
      downloadRepository: DownloadRepository(),
      directoryService: directoryService,
      onboardingService: onboardingService,
    );

    await _viewModel.init();

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('Little Star App'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  await _viewModel.loadLocalModels();
                  await _viewModel.loadRecommendedModelFiles();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildWelcomeSection(context),
                      const SizedBox(height: 24),

                      // Downloaded models section (if any)
                      if (_viewModel.localModels.isNotEmpty) ...[
                        DownloadedModelsSection(
                          models: _viewModel.localModels,
                          onChat: (model) => _navigateToChat(context, model),
                          onTest: (model) => _navigateToCompletion(context, model),
                          onManage: () => _openModelManager(context),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Recommended models section
                      _buildRecommendedModelsSection(context),
                      const SizedBox(height: 24),

                      // Navigation Cards
                      _buildNavigationCard(
                        context: context,
                        title: 'Model Completion',
                        subtitle: 'Test models with single prompts and view performance metrics',
                        icon: Icons.science,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CompletionScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationCard(
                        context: context,
                        title: 'AI Chat (Experimental)',
                        subtitle: 'Have conversations with AI models in a chat interface',
                        icon: Icons.chat,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationCard(
                        context: context,
                        title: 'Model Manager',
                        subtitle: 'Browse, download and manage GGUF models from Hugging Face',
                        icon: Icons.download,
                        color: Colors.orange,
                        onTap: () => _openModelManager(context),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Onboarding guide overlay
            if (!_viewModel.hasCompletedOnboarding)
              OnboardingGuide(
                currentStep: _viewModel.currentOnboardingStep,
                onNext: () => _viewModel.completeOnboardingStep(_viewModel.currentOnboardingStep),
                onSkip: () => _viewModel.skipOnboarding(),
                onComplete: () => _viewModel.skipOnboarding(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Little Star',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how you want to interact with AI models',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedModelsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.star,
                size: 20,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommended Models',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_viewModel.isLoadingLocal)
          const SkeletonRecommendedModels()
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _viewModel.recommendedModels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final modelState = _viewModel.recommendedModels[index];
                return SizedBox(
                  width: 320,
                  child: RecommendedModelCard(
                    modelState: modelState,
                    onDownload: () => _viewModel.startOneClickDownload(modelState),
                    onOpen: () => _navigateToChat(
                      context,
                      _findLocalModel(modelState.recommendedFile?.filename),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  GGUFModelInfo? _findLocalModel(String? filename) {
    if (filename == null) return null;
    try {
      return _viewModel.localModels.firstWhere((m) => m.fileName == filename);
    } catch (e) {
      return null;
    }
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, GGUFModelInfo? model) {
    if (model == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  void _navigateToCompletion(BuildContext context, GGUFModelInfo? model) {
    if (model == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CompletionScreen(),
      ),
    );
  }

  void _openModelManager(BuildContext context) {
    final directoryService = Platform.isAndroid
        ? AndroidDirectoryService()
        : Platform.isIOS
            ? IOSDirectoryService()
            : DesktopDirectoryService();

    final viewModel = ModelManagerViewModel(
      hfService: HuggingFaceService(),
      downloadService: DownloadService(),
      downloadRepository: DownloadRepository(),
      directoryService: directoryService,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelManagerScreen(viewModel: viewModel),
      ),
    );
  }
}
