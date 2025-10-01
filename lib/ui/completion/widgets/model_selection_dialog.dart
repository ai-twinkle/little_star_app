import 'dart:io';
import 'package:flutter/material.dart';

import '../../../services/model_selection_service.dart';

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
  final ModelSelectionService _modelService = ModelSelectionService();
  List<GGUFModelInfo> _models = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scanForModels();
  }

  Future<void> _scanForModels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request permissions on Android if needed
      if (Platform.isAndroid) {
        final hasPermission = await _modelService.requestAndroidPermissions(context);
        if (!hasPermission) {
          setState(() {
            _errorMessage = 'Storage permission required to access model files. Please grant permission and try again.';
            _isLoading = false;
          });
          return;
        }
      }

      final models = await _modelService.scanForGGUFFiles();
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
        height: 400,
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
              'Place .gguf model files in your Downloads folder\nor Documents directory',
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

  Future<void> _selectModel(GGUFModelInfo model) async {
    try {
      // Close the dialog
      Navigator.of(context).pop();

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loading model: ${model.fileName}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Load the model
      widget.onModelSelected(model.filePath);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Model loaded: ${model.fileName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load model: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
