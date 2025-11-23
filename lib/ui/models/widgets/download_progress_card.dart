import 'package:flutter/material.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/models/download_task.dart';

/// Card widget showing download progress with pause/resume/cancel controls.
class DownloadProgressCard extends StatelessWidget {
  final DownloadTask task;
  final DownloadProgress? progress;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const DownloadProgressCard({
    super.key,
    required this.task,
    this.progress,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = progress?.progress ?? task.progress;
    final isPaused = task.status == DownloadStatus.paused;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaused ? Icons.pause_circle : Icons.downloading,
                  color: isPaused
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.filename,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${task.formattedDownloadedBytes} / ${task.formattedTotalBytes}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progressValue * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress != null && progress!.speed > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatSpeed(progress!.speed),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                // Control buttons
                if (task.canPause)
                  IconButton(
                    icon: const Icon(Icons.pause, size: 20),
                    onPressed: onPause,
                    tooltip: 'Pause',
                    visualDensity: VisualDensity.compact,
                  ),
                if (task.canResume)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    onPressed: onResume,
                    tooltip: 'Continue',
                    visualDensity: VisualDensity.compact,
                  ),
                if (task.canCancel)
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.error),
                    onPressed: onCancel,
                    tooltip: 'Cancel',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }
}
