import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:little_star_app/models/mlx_model_info.dart';
import 'package:little_star_app/ui/chat/widgets/chat_screen.dart';
import 'package:little_star_app/ui/completion/widgets/completion_screen.dart';
import 'package:little_star_app/ui/models/view_model/mlx_model_viewmodel.dart';

/// Lets the user download an MLX model (a multi-file Hugging Face repo,
/// e.g. Bbson/gemma-3-4B-T1-it-MLX-4bit) and open it in the chat screen.
class MlxModelsScreen extends StatefulWidget {
  const MlxModelsScreen({super.key});

  @override
  State<MlxModelsScreen> createState() => _MlxModelsScreenState();
}

class _MlxModelsScreenState extends State<MlxModelsScreen> {
  static const _defaultRepo = 'Bbson/gemma-3-4B-T1-it-MLX-4bit';

  final _repoController = TextEditingController(text: _defaultRepo);
  MlxModelViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final mlxDir = Directory(path.join(appSupportDir.path, 'Models', 'mlx'));
    final vm = MlxModelViewModel(mlxModelsDir: mlxDir);
    await vm.init();
    if (!mounted) return;
    setState(() => _viewModel = vm);
  }

  @override
  void dispose() {
    _repoController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    await _viewModel?.downloadModel(_repoController.text);
  }

  void _openChat(MlxModelInfo model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialModelPath: model.directoryPath),
      ),
    );
  }

  void _openCompletion(MlxModelInfo model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompletionScreen(initialModelPath: model.directoryPath),
      ),
    );
  }

  Future<void> _confirmDelete(MlxModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete model?'),
        content: Text(
          'Remove ${model.displayName} (${model.formattedSize}) from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _viewModel?.deleteLocalModel(model);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _viewModel;
    return Scaffold(
      appBar: AppBar(title: const Text('MLX Models')),
      body: vm == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: vm,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'MLX models run natively on Apple Silicon. Paste a Hugging '
                      'Face repo id below to download one.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _repoController,
                            enabled: !vm.isDownloading,
                            decoration: const InputDecoration(
                              labelText: 'HuggingFace repo',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: vm.isDownloading ? null : _download,
                          icon: const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const Text('Download'),
                        ),
                      ],
                    ),
                    if (vm.isDownloading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: vm.downloadProgress),
                      const SizedBox(height: 4),
                      Text(vm.status, style: const TextStyle(fontSize: 12)),
                    ],
                    if (vm.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        vm.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Downloaded models',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: vm.isLoadingLocal
                          ? const Center(child: CircularProgressIndicator())
                          : vm.localModels.isEmpty
                              ? const Center(
                                  child: Text('No MLX models downloaded yet.'),
                                )
                              : ListView.separated(
                                  itemCount: vm.localModels.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final model = vm.localModels[index];
                                    return ListTile(
                                      leading: const Icon(Icons.memory),
                                      title: Text(model.displayName),
                                      subtitle: Text(model.formattedSize),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chat_outlined),
                                            tooltip: 'Chat',
                                            onPressed: () => _openChat(model),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_note_outlined),
                                            tooltip: 'Completion',
                                            onPressed: () => _openCompletion(model),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            tooltip: 'Delete',
                                            onPressed: () => _confirmDelete(model),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
