import 'package:flutter/material.dart';

import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/chat/view_model/chat_viewmodel.dart';
import 'package:little_star_app/ui/chat/widgets/message_bubble.dart';
import 'package:little_star_app/ui/completion/widgets/model_selection_dialog.dart';
import 'package:little_star_app/ui/completion/widgets/advanced_settings_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatViewModel viewModel;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // TODO: Replace with actual model path
    viewModel = ChatViewModel(
      modelPath: '/storage/emulated/0/Download/Llama-3.2-3B-F1-Reasoning-Instruct-Q3_K_M.gguf',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    viewModel.sendMessage(text);
    _messageController.clear();

    // Auto-scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showModelSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        onModelSelected: (modelPath) async {
          try {
            await viewModel.selectModel(modelPath);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load model: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showAdvancedSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AdvancedSettingsSheet(
        maxTokens: viewModel.maxTokens,
        stopSequences: viewModel.stopSequences,
        temperature: viewModel.temperature,
        topK: viewModel.topK,
        topP: viewModel.topP,
        systemPrompt: viewModel.systemPrompt,
        onApply: viewModel.updateSettings,
        onReset: viewModel.resetSettings,
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.clearChat();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: () => _showClearChatDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Advanced settings',
            onPressed: () => _showAdvancedSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Model selection banner
          AnimatedBuilder(
            animation: viewModel,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.model_training,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.selectedModelName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showModelSelection(context),
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Messages list
          Expanded(
            child: AnimatedBuilder(
              animation: viewModel,
              builder: (context, _) {
                if (viewModel.messages.isEmpty && !viewModel.isGenerating) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to begin',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: viewModel.messages.length + (viewModel.isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show streaming message
                    if (index == viewModel.messages.length && viewModel.isGenerating) {
                      return ValueListenableBuilder<String>(
                        valueListenable: viewModel.streamingMessageNotifier,
                        builder: (context, streamingText, _) {
                          // Auto-scroll during streaming
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToBottom();
                          });

                          return MessageBubble(
                            message: ChatMessage(
                              content: streamingText.isEmpty ? '...' : streamingText,
                              isUser: false,
                              modelName: viewModel.selectedModelName,
                            ),
                            isStreaming: true,
                          );
                        },
                      );
                    }

                    // Show regular messages
                    final message = viewModel.messages[index];
                    final metrics = viewModel.getMessageMetrics(index);

                    return MessageBubble(
                      message: message,
                      metrics: metrics,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          AnimatedBuilder(
            animation: viewModel,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _inputFocusNode,
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (viewModel.isGenerating)
                        IconButton(
                          icon: const Icon(Icons.stop_circle),
                          onPressed: viewModel.stopGeneration,
                          tooltip: 'Stop generation',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage,
                          tooltip: 'Send message',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
