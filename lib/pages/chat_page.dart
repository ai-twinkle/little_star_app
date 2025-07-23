import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../services/llama_service.dart';
import '../services/ios_directory_service.dart';
import '../llama_ffi.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final LlamaService _llamaService = LlamaService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = false;
  bool _isResponding = false;
  String? _modelPath;
  String? _selectedModelName;
  Timer? _streamingTimer;
  int _currentStreamingMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {}); // Update send button state
    });
    _llamaService.addListener(_onServiceStateChanged);
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _llamaService.removeListener(_onServiceStateChanged);
    super.dispose();
  }

  void _onServiceStateChanged() {
    setState(() {});
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Request permissions for Android
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    var storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
    }
    
    if (storageStatus.isGranted) {
      return true;
    }
    
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isDenied) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs access to Downloads folder to load AI models. Please grant "All files access" permission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Grant'),
            ),
          ],
        ),
      );
      
      if (shouldRequest != true) return false;
      
      manageStatus = await Permission.manageExternalStorage.request();
    }
    
    return manageStatus.isGranted;
  }

  // Browse for GGUF files
  Future<void> _browseGGUFFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isAndroid) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      List<String> ggufFiles = [];
      
      if (Platform.isAndroid) {
        final searchPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/sdcard/Download',
          '/sdcard/Documents',
        ];

        for (final searchPath in searchPaths) {
          try {
            final dir = Directory(searchPath);
            if (await dir.exists()) {
              final files = dir.listSync(recursive: false);
              for (final file in files) {
                if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
                  ggufFiles.add(file.path);
                }
              }
            }
          } catch (e) {
            print('Error searching in $searchPath: $e');
          }
        }
      } else if (Platform.isIOS) {
        // For iOS, use the IOSDirectoryService
        ggufFiles = await IOSDirectoryService.findGGUFFiles();
      } else {
        // For other platforms (macOS, Windows, Linux)
        final currentDir = Directory.current;
        final files = currentDir.listSync(recursive: false);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
            ggufFiles.add(file.path);
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (ggufFiles.isNotEmpty) {
        _showGGUFFilesDialog(ggufFiles);
      } else {
        if (mounted) {
          String message;
          if (Platform.isIOS) {
            message = 'No GGUF files found in iOS directories.\n'
                     'Please place GGUF files in the app\'s Documents folder or use the Files app to copy them.';
          } else {
            message = 'No GGUF files found in common directories.\n'
                     'Please place GGUF files in Downloads or Documents folder.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error browsing files: $e')),
        );
      }
    }
  }

  // Show dialog with found GGUF files
  void _showGGUFFilesDialog(List<String> ggufFiles) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select GGUF Model'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ggufFiles.length,
              itemBuilder: (context, index) {
                final filePath = ggufFiles[index];
                final fileName = path.basename(filePath);
                final file = File(filePath);
                
                return ListTile(
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    'Size: ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      _modelPath = filePath;
                      _selectedModelName = fileName;
                      _isLoading = true;
                    });
                    await _loadModel();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Load model using service
  Future<void> _loadModel() async {
    if (_modelPath == null || _selectedModelName == null) return;

    setState(() {
      _isLoading = true;
    });

    final success = await _llamaService.loadModel(_modelPath!, _selectedModelName!);
    
    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      // Add system message when model is loaded
      setState(() {
        _messages.add(ChatMessage(
          content: 'Model "${_llamaService.selectedModelName}" loaded successfully! You can now start chatting.',
          isUser: false,
          modelName: _llamaService.selectedModelName,
        ));
      });
      _scrollToBottom();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load model: ${_llamaService.statusMessage}')),
      );
    }
  }

  // Send message and get AI response with real streaming
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || !_llamaService.isModelLoaded || _isResponding) {
      return;
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        content: messageText,
        isUser: true,
      ));
      _isResponding = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Add empty AI message placeholder for streaming
    final aiMessageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(
        content: '',
        isUser: false,
        modelName: _llamaService.selectedModelName,
      ));
      _currentStreamingMessageIndex = aiMessageIndex;
    });
    _scrollToBottom();

    try {
      // Build conversation context
      final conversationContext = _buildConversationContext();
      
      // Start real streaming inference
      String accumulatedContent = '';
      
      await for (final tokenText in _llamaService.performStreamingInference(
        conversationContext,
        maxTokens: 512,
      )) {
        // Check if we should still be streaming
        if (_currentStreamingMessageIndex != aiMessageIndex || !mounted) {
          break;
        }
        
        // Accumulate the token text
        accumulatedContent += tokenText;
        
        // Update the message content in real-time
        setState(() {
          if (aiMessageIndex < _messages.length) {
            _messages[aiMessageIndex] = _messages[aiMessageIndex].copyWith(
              content: accumulatedContent,
            );
          }
        });
        
        // Auto scroll to keep latest content visible
        _scrollToBottom();
      }
      
      // Streaming complete
      setState(() {
        _isResponding = false;
        _currentStreamingMessageIndex = -1;
      });
      
    } catch (e) {
      // Handle error case
      setState(() {
        if (aiMessageIndex < _messages.length) {
          _messages[aiMessageIndex] = _messages[aiMessageIndex].copyWith(
            content: 'Error during streaming: $e',
          );
        }
        _isResponding = false;
        _currentStreamingMessageIndex = -1;
      });
    }

    _scrollToBottom();
  }

  // Build conversation context for the AI
  String _buildConversationContext() {
    final conversationPairs = <String>[];
    
    // Get recent messages (limit to last 10 exchanges to avoid context overflow)
    final recentMessages = _messages.where((msg) => msg.content != 'Model "${_llamaService.selectedModelName}" loaded successfully! You can now start chatting.').toList();
    final messagesToUse = recentMessages.length > 20 ? recentMessages.sublist(recentMessages.length - 20) : recentMessages;
    
    for (final message in messagesToUse) {
      if (message.isUser) {
        conversationPairs.add('Human: ${message.content}');
      } else {
        conversationPairs.add('Assistant: ${message.content}');
      }
    }
    
    // Add current context
    final context = conversationPairs.join('\n\n');
    return context.isEmpty ? '' : '$context\n\nAssistant:';
  }

  // Clear chat history
  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _messages.clear();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // 新的流式显示方法
  Future<void> _streamResponse(String fullResponse, int messageIndex) async {
    // Split response into words for streaming effect
    final words = fullResponse.split(' ');
    String currentContent = '';
    
    // Cancel any existing timer
    _streamingTimer?.cancel();
    
    for (int i = 0; i < words.length; i++) {
      // Check if we should still be streaming
      if (_currentStreamingMessageIndex != messageIndex || !mounted) {
        break;
      }
      
      // Add next word
      currentContent += (i == 0 ? '' : ' ') + words[i];
      
      // Update the message content
      setState(() {
        if (messageIndex < _messages.length) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            content: currentContent,
          );
        }
      });
      
      // Scroll to bottom to keep the latest content visible
      _scrollToBottom();
      
      // Wait before showing next word (adjust speed here)
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    // Streaming complete
    setState(() {
      _isResponding = false;
      _currentStreamingMessageIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _llamaService,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Chat'),
                if (_llamaService.selectedModelName != null)
                  Text(
                    _llamaService.selectedModelName!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
              ],
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _clearChat,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear chat',
            ),
          IconButton(
            onPressed: _isLoading ? null : () async {
              await _browseGGUFFiles();
            },
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open),
            tooltip: 'Load model',
          ),
        ],
      ),
      body: Column(
        children: [
          // Model status bar
          if (!_llamaService.isModelLoaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No model loaded. Please load a model to start chatting.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _browseGGUFFiles,
                    child: const Text('Load Model'),
                  ),
                ],
              ),
            ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _llamaService.isModelLoaded
                              ? 'Type a message below to begin'
                              : 'Load a model first to start chatting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length + (_isResponding ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isResponding) {
                        // Show typing indicator
                        return _buildTypingIndicator();
                      }
                      
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _llamaService.isModelLoaded && !_isResponding,
                    decoration: InputDecoration(
                      hintText: _llamaService.isModelLoaded 
                          ? 'Type your message...' 
                          : 'Load a model to start chatting',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _llamaService.isModelLoaded &&
                          !_isResponding &&
                          _messageController.text.trim().isNotEmpty
                      ? _sendMessage
                      : null,
                  icon: _isResponding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: _llamaService.isModelLoaded &&
                            !_isResponding &&
                            _messageController.text.trim().isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.smart_toy, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: message.isUser ? const Radius.circular(4) : null,
                  bottomLeft: !message.isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.smart_toy, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Thinking...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Chat inference parameters for isolate
class ChatInferenceParams {
  final String modelPath;
  final String prompt;
  final int maxTokens;

  ChatInferenceParams({
    required this.modelPath,
    required this.prompt,
    required this.maxTokens,
  });
}

// Top-level function for chat inference in isolate
Future<String?> _performChatInferenceInIsolate(ChatInferenceParams params) async {
  try {
    final llamaFFI = LlamaFFI();
    
    if (Platform.isWindows) {
      llamaFFI.ggml_backend_load_all();
    } else {
      llamaFFI.initBackend();
    }
    
    final modelLoaded = llamaFFI.loadModel(params.modelPath);
    if (!modelLoaded) {
      llamaFFI.freeBackend();
      return null;
    }
    
    final contextCreated = llamaFFI.createContext();
    if (!contextCreated) {
      llamaFFI.freeBackend();
      return null;
    }
    
    final result = llamaFFI.performInference(
      params.prompt,
      maxTokens: params.maxTokens,
    );
    
    llamaFFI.freeBackend();
    
    return result;
  } catch (e) {
    print('Error in chat inference isolate: $e');
    return null;
  }
} 