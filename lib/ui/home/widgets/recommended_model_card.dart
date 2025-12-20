import 'package:flutter/material.dart';
import 'package:little_star_app/ui/home/view_model/home_viewmodel.dart';
import 'package:little_star_app/ui/home/widgets/skeleton_loader.dart';

/// Enhanced card for displaying recommended models with download status
class RecommendedModelCard extends StatelessWidget {
  final RecommendedModelState modelState;
  final VoidCallback onDownload;
  final VoidCallback? onOpen;

  const RecommendedModelCard({
    super.key,
    required this.modelState,
    required this.onDownload,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: modelState.isDownloaded && onOpen != null ? onOpen : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, theme),
              const SizedBox(height: 8),
              _buildDescription(context, theme),
              const SizedBox(height: 12),
              _buildFileInfo(context, theme),
              const SizedBox(height: 12),
              _buildActionButton(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.stars,
          size: 20,
          color: Colors.amber,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getDisplayName(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (modelState.config.badge != null) _buildBadge(theme),
      ],
    );
  }

  String _getDisplayName() {
    // Extract a cleaner name from the model name
    final name = modelState.config.modelInfo.modelName;
    // Remove GGUF suffix and make it more readable
    return name.replaceAll('-GGUF', '').replaceAll('_', ' ');
  }

  Widget _buildBadge(ThemeData theme) {
    final badgeColor = modelState.config.badge == 'Recommended'
        ? Colors.blue
        : modelState.config.badge == 'Fastest'
            ? Colors.green
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        modelState.config.badge!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context, ThemeData theme) {
    final description = modelState.config.quickDescription ??
        modelState.config.modelInfo.description ??
        '';

    return Text(
      description,
      style: theme.textTheme.bodySmall?.copyWith(
        color: Colors.grey[700],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFileInfo(BuildContext context, ThemeData theme) {
    if (modelState.isLoadingFileInfo) {
      return Row(
        children: [
          const SkeletonLine(width: 60, height: 12),
          const SizedBox(width: 8),
          const Text('•'),
          const SizedBox(width: 8),
          const SkeletonLine(width: 80, height: 12),
        ],
      );
    }

    if (modelState.error != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
          const SizedBox(width: 4),
          Text(
            'Info unavailable',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      );
    }

    final file = modelState.recommendedFile;
    if (file == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            file.quantization ?? 'GGUF',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '•',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Text(
          file.formattedSize,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    if (modelState.isDownloaded) {
      return _buildDownloadedButton(theme);
    }

    if (modelState.isDownloading) {
      return _buildDownloadingProgress(theme);
    }

    if (modelState.error != null && !modelState.isLoadingFileInfo) {
      return _buildRetryButton(theme);
    }

    return _buildDownloadButton(theme);
  }

  Widget _buildDownloadedButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            'Downloaded',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingProgress(ThemeData theme) {
    final progress = modelState.progress;
    final progressValue = progress?.progress ?? 0.0;
    final progressPercent = (progressValue * 100).toStringAsFixed(0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$progressPercent%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (progress != null && progress.speed > 0)
              Text(
                _formatSpeed(progress.speed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              Text(
                'Downloading...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            Text(
              '${_formatBytes(progress?.downloadedBytes ?? 0)} / ${modelState.recommendedFile?.formattedSize ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadButton(ThemeData theme) {
    final isDisabled = modelState.isLoadingFileInfo || modelState.recommendedFile == null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isDisabled ? null : onDownload,
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Download'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRetryButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onDownload,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Retry'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: Colors.orange,
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }
}
