import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:little_star_app/config/recommended_models.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/ui/models/view_model/model_manager_viewmodel.dart';
import 'package:little_star_app/ui/models/widgets/model_file_list.dart';
import 'package:little_star_app/ui/models/widgets/model_search_list.dart';
import 'package:little_star_app/ui/models/widgets/local_model_list.dart';
import 'package:little_star_app/ui/models/widgets/download_progress_card.dart';
import 'package:little_star_app/utils/logger.dart';

/// Main screen for managing models - browsing, downloading, and local files.
class ModelManagerScreen extends StatefulWidget {
  final ModelManagerViewModel viewModel;
  final dynamic preselectedModel;
  final int initialTabIndex;

  const ModelManagerScreen({
    super.key,
    required this.viewModel,
    this.preselectedModel,
    this.initialTabIndex = 0,
  });

  factory ModelManagerScreen.recommended({Key? key}) {
    final directoryService = DirectoryServiceFactory.create();
    return ModelManagerScreen(
      key: key,
      viewModel: ModelManagerViewModel(
        hfService: HuggingFaceService(),
        downloadService: DownloadService(),
        downloadRepository: DownloadRepository(),
        directoryService: directoryService,
      ),
      initialTabIndex: 1,
    );
  }

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Logger _log = Logger('ModelManagerScreen');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    widget.viewModel.init();

    // If a preselected model is provided, switch to online tab and select it
    if (widget.preselectedModel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(1); // Switch to online tab
        widget.viewModel.selectModel(widget.preselectedModel);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleImportModels() async {
    try {
      // Pick files - use FileType.any since .gguf is not a recognized MIME type
      // We'll filter for .gguf files after selection
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        _log.debug('File selection cancelled');
        return;
      }

      // Log selected files info
      _log.info('FilePicker result: ${result.files.length} files');
      for (var file in result.files) {
        _log.debug('File: ${file.name}, Path: ${file.path}');
      }

      // Get file paths and filter for .gguf files
      final allPaths = result.paths.whereType<String>().toList();
      _log.debug('All paths: $allPaths');

      final paths = allPaths
          .where((path) => path.toLowerCase().endsWith('.gguf'))
          .toList();
      _log.info('Filtered GGUF paths: ${paths.length} files');

      if (allPaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No files selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (paths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No .gguf files selected. Selected ${allPaths.length} non-GGUF file(s).',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show loading indicator with file count
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Importing ${paths.length} model(s)...'),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );
      }

      _log.info('Starting import of ${paths.length} files');

      // Import files
      final importedFiles = await widget.viewModel.importModels(paths);

      _log.info('Import completed: ${importedFiles.length} files imported');

      // Hide loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Show result
      if (mounted) {
        if (importedFiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new models imported (files may already exist)'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully imported ${importedFiles.length} model(s)',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import models: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'Local Models'),
            Tab(icon: Icon(Icons.cloud_download), text: 'Online Downloads'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return Column(
            children: [
              // Download progress section
              if (widget.viewModel.activeTasks.isNotEmpty)
                _buildDownloadSection(),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLocalTab(),
                    _buildOnlineTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadSection() {
    final activeTasks = widget.viewModel.activeTasks.where((t) =>
        t.status == DownloadStatus.downloading ||
        t.status == DownloadStatus.pending ||
        t.status == DownloadStatus.paused);

    if (activeTasks.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Downloading',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...activeTasks.map((task) => DownloadProgressCard(
                task: task,
                progress: widget.viewModel.getProgress(task.id),
                onPause: () => widget.viewModel.pauseDownload(task.id),
                onResume: () => widget.viewModel.resumeDownload(task.id),
                onCancel: () => widget.viewModel.cancelDownload(task.id),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLocalTab() {
    if (widget.viewModel.isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.viewModel.localModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No local models',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download models from "Online Downloads" tab\nor import existing .gguf files',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _handleImportModels,
              icon: const Icon(Icons.file_upload),
              label: const Text('Import GGUF Models'),
            ),
          ],
        ),
      );
    }

    return LocalModelList(
      models: widget.viewModel.localModels,
      onDelete: widget.viewModel.deleteLocalModel,
      onRefresh: widget.viewModel.loadLocalModels,
      onImport: _handleImportModels,
    );
  }

  Widget _buildOnlineTab() {
    // If a model is selected, show its files
    if (widget.viewModel.selectedModel != null) {
      return ModelFileList(
        model: widget.viewModel.selectedModel!,
        files: widget.viewModel.selectedModelFiles,
        isLoading: widget.viewModel.isLoadingFiles,
        onBack: widget.viewModel.clearSelection,
        onDownload: widget.viewModel.startDownload,
        isDownloaded: widget.viewModel.isDownloaded,
        isDownloading: widget.viewModel.isDownloading,
        getDownloadStatus: widget.viewModel.getDownloadStatus,
      );
    }

    // Show search and results
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search GGUF models...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        widget.viewModel.searchModels();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onSubmitted: widget.viewModel.searchModels,
          ),
        ),
        if (widget.viewModel.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.viewModel.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.viewModel.isSearching
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    // Recommended models section
                    if (_searchController.text.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildRecommendedModelsSection(),
                      ),
                    // Search results
                    SliverToBoxAdapter(
                      child: ModelSearchList(
                        models: widget.viewModel.searchResults,
                        onSelect: widget.viewModel.selectModel,
                      ),
                    ),
                  ],
                  ),
        ),
      ],
    );
  }

  Widget _buildRecommendedModelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recommended Models',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: RecommendedModels.models.length,
          itemBuilder: (context, index) {
            final modelConfig = RecommendedModels.models[index];
            final model = modelConfig.modelInfo;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.star, color: Colors.amber, size: 20),
                ),
                title: Text(
                  model.modelName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  modelConfig.quickDescription ?? model.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => widget.viewModel.selectModel(model),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Divider(),
        ),
        if (widget.viewModel.searchResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Search Results',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
      ],
    );
  }
}
