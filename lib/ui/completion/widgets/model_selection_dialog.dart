import 'package:flutter/material.dart';

import '../../../data/repositories/gguf_repository.dart';
import '../../../data/services/directory_service.dart';
import '../../../models/gguf_model_info.dart';

/// Dialog for selecting GGUF model files
class ModelSelectionDialog extends StatefulWidget {
  final Function(String) onModelSelected;

  const ModelSelectionDialog({
    super.key,
    required this.onModelSelected,
  });

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  late final DirectoryService _directoryService;
  late final GGUFRepository _repository;
  List<GGUFModelInfo> _models = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _directoryService = _createPlatformDirectoryService();
    _repository = GGUFRepository(directoryService: _directoryService);
    _scanForModels();
  }

  DirectoryService _createPlatformDirectoryService() {
    return DirectoryServiceFactory.create();
  }

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }

  Future<void> _scanForModels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request permissions if needed (Android only)
      final hasPermission = await _repository.ensurePermissions(context);
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Storage permission required to access model files. Please grant permission and try again.';
          _isLoading = false;
        });
        return;
      }

      final models = await _repository.getGGUFModels();
      setState(() {
        _models = models;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select GGUF Model'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _scanForModels,
          child: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for GGUF files...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _scanForModels,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_models.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text('No GGUF files found'),
            SizedBox(height: 8),
            Text(
              'Download or import models from\nthe Model Manager screen',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _models.length,
      itemBuilder: (context, index) {
        final model = _models[index];
        return ListTile(
          leading: const Icon(Icons.model_training),
          title: Text(
            model.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Size: ${model.formattedSize}'),
              Text(
                model.filePath,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          onTap: () => _selectModel(model),
          dense: true,
        );
      },
    );
  }

  void _selectModel(GGUFModelInfo model) {
    // Close the dialog first
    Navigator.of(context).pop();

    // Call the callback - let the parent handle loading state and error handling
    widget.onModelSelected(model.filePath);
  }
}
