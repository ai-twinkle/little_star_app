import 'package:flutter/material.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/chat/view_model/chat_viewmodel.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final MessageMetrics? metrics;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.metrics,
    this.isStreaming = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showMetrics = false;

  String _fmtDuration(Duration? d) {
    if (d == null) return '-';
    final ms = d.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    final s = ms / 1000.0;
    return '${s.toStringAsFixed(2)}s';
  }

  String _fmtDouble(double? v, {int frac = 2}) {
    if (v == null) return '-';
    return v.toStringAsFixed(frac);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message bubble
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.smart_toy,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: widget.metrics != null
                      ? () {
                          setState(() {
                            _showMetrics = !_showMetrics;
                          });
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.content,
                          style: TextStyle(
                            color: isUser
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        if (widget.isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
          // Metrics panel (collapsible)
          if (_showMetrics && widget.metrics != null) ...[
            const SizedBox(height: 4),
            Container(
              margin: EdgeInsets.only(
                left: isUser ? 0 : 40,
                right: isUser ? 40 : 0,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metrics',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetricChip(
                        label: 'TTFT',
                        value: _fmtDuration(widget.metrics!.ttft),
                      ),
                      _MetricChip(
                        label: 'Total',
                        value: _fmtDuration(widget.metrics!.totalDuration),
                      ),
                      _MetricChip(
                        label: 'TPS',
                        value: _fmtDouble(widget.metrics!.tokensPerSecond),
                      ),
                      _MetricChip(
                        label: 'Tokens',
                        value: '${widget.metrics!.tokenCount ?? 0}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 40,
              right: isUser ? 40 : 0,
              top: 2,
            ),
            child: Text(
              _formatTimestamp(widget.message.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
