import 'package:flutter/material.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/models/hf_model_info.dart';

/// List widget for displaying GGUF files within a model repository.
class ModelFileList extends StatelessWidget {
  final HFModelInfo model;
  final List<HFModelFile> files;
  final bool isLoading;
  final VoidCallback onBack;
  final Function(HFModelFile) onDownload;
  final bool Function(String filename) isDownloaded;
  final bool Function(String url) isDownloading;
  final DownloadStatus? Function(String url) getDownloadStatus;

  const ModelFileList({
    super.key,
    required this.model,
    required this.files,
    required this.isLoading,
    required this.onBack,
    required this.onDownload,
    required this.isDownloaded,
    required this.isDownloading,
    required this.getDownloadStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.modelName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      model.author,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // File list
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : files.isEmpty
                  ? Center(
                      child: Text(
                        'No GGUF files found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return _ModelFileCard(
                          file: file,
                          isDownloaded: isDownloaded(file.filename),
                          isDownloading: isDownloading(file.downloadUrl),
                          status: getDownloadStatus(file.downloadUrl),
                          onDownload: () => onDownload(file),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ModelFileCard extends StatelessWidget {
  final HFModelFile file;
  final bool isDownloaded;
  final bool isDownloading;
  final DownloadStatus? status;
  final VoidCallback onDownload;

  const _ModelFileCard({
    required this.file,
    required this.isDownloaded,
    required this.isDownloading,
    required this.status,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getContainerColor(theme),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(),
                color: _getIconColor(theme),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        file.formattedSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (file.quantization != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.quantization!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final theme = Theme.of(context);

    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Downloaded',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (isDownloading || status == DownloadStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Downloading',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    if (status == DownloadStatus.paused) {
      return TextButton.icon(
        onPressed: onDownload,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Continue'),
      );
    }

    return FilledButton.icon(
      onPressed: onDownload,
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Download'),
    );
  }

  Color _getContainerColor(ThemeData theme) {
    if (isDownloaded) return theme.colorScheme.primaryContainer;
    if (isDownloading) return theme.colorScheme.secondaryContainer;
    return theme.colorScheme.surfaceContainerHighest;
  }

  IconData _getIcon() {
    if (isDownloaded) return Icons.check_circle;
    if (isDownloading) return Icons.downloading;
    return Icons.description;
  }

  Color _getIconColor(ThemeData theme) {
    if (isDownloaded) return theme.colorScheme.primary;
    if (isDownloading) return theme.colorScheme.secondary;
    return theme.colorScheme.outline;
  }
}
