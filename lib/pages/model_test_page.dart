import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/llama_service.dart';
import '../services/ios_directory_service.dart';
import '../llama_ffi.dart';

class ExpansibleController extends ChangeNotifier {
  bool _isExpanded = true;

  bool get isExpanded => _isExpanded;

  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  void toggle() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }
}

class ModelTestPage extends StatefulWidget {
  const ModelTestPage({super.key});

  @override
  State<ModelTestPage> createState() => _ModelTestPageState();
}

class _ModelTestPageState extends State<ModelTestPage> {
  final LlamaService _llamaService = LlamaService();
  bool _isLoading = false;

  // Model-related state
  final ExpansibleController _modelController = ExpansibleController();
  String? _modelPath;
  String? _selectedModelName;

  // Inference-related state
  final TextEditingController _promptController = TextEditingController();
  String _inferenceResult = '';
  bool _isInferenceLoading = false;

  // Benchmark-related state
  String _benchmarkResults = '';
  Map<String, dynamic> _performanceMetrics = {};

  @override
  void initState() {
    super.initState();
    _promptController.addListener(() {
      setState(() {}); // Rebuild to update button state
    });
    _llamaService.addListener(_onServiceStateChanged);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _llamaService.removeListener(_onServiceStateChanged);
    super.dispose();
  }

  void _onServiceStateChanged() {
    setState(() {
      if (_llamaService.isModelLoaded) {
        _modelController.collapse();
      }
    });
  }

  // Request necessary permissions for Android
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
      setState(() {
        _isLoading = false;
      });
      
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs access to Downloads folder to load AI models. Please grant "All files access" permission in the next screen.',
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

  // Find model file in common locations
  Future<String?> findModelFile() async {
    const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q8_0.gguf';

    if (Platform.isAndroid) {
      final possiblePaths = [
        '/storage/emulated/0/Download/$modelFileName',
        '/sdcard/Download/$modelFileName',
        '/storage/self/primary/Download/$modelFileName',
      ];

      for (final testPath in possiblePaths) {
        final file = File(testPath);
        if (file.existsSync()) {
          return testPath;
        }
      }
      return null;
    } else if (Platform.isIOS) {
      // For iOS, check Documents and Downloads directories
      try {
        // Check Documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        final documentsPath = path.join(documentsDir.path, modelFileName);
        if (File(documentsPath).existsSync()) {
          return documentsPath;
        }

        // Check Downloads directory if available
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final downloadsPath = path.join(downloadsDir.path, modelFileName);
          if (File(downloadsPath).existsSync()) {
            return downloadsPath;
          }
        }

        // Check Temporary directory as fallback
        final tempDir = await getTemporaryDirectory();
        final tempPath = path.join(tempDir.path, modelFileName);
        if (File(tempPath).existsSync()) {
          return tempPath;
        }
      } catch (e) {
        print('Error accessing iOS directories: $e');
      }
      return null;
    } else {
      final currentDir = Directory.current;
      final modelPath = path.join(currentDir.path, modelFileName);
      return File(modelPath).existsSync() ? modelPath : null;
    }
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
                    'Size: ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB\nPath: $filePath',
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

  // Combined browse and load
  Future<void> _browseAndLoadModel() async {
    if (_modelPath == null) {
      await _browseGGUFFiles();
    } else {
      await _loadModel();
    }
  }

  // Debug iOS directories function
  Future<void> _debugIOSDirectories() async {
    if (Platform.isIOS) {
      await IOSDirectoryService.printDirectoryReport();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iOS directory report printed to console. Check your debug output.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load model: ${_llamaService.statusMessage}')),
      );
    }
  }

  // Perform inference with benchmark
  Future<void> _performInference() async {
    if (!_llamaService.isModelLoaded || _promptController.text.trim().isEmpty) {
      return;
    }

    final prompt = _promptController.text.trim();
    const maxTokens = 512;

    setState(() {
      _isInferenceLoading = true;
      _inferenceResult = 'Processing...';
      _benchmarkResults = '';
      _performanceMetrics = {};
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      // Use isolate for inference
      final inferenceParams = InferenceParams(
        modelPath: _llamaService.modelPath!,
        prompt: prompt,
        maxTokens: maxTokens,
      );

      final result = await compute(_performInferenceInIsolate, inferenceParams);
      
      stopwatch.stop();

      if (result != null) {
        // Calculate metrics
        final elapsedMs = stopwatch.elapsedMilliseconds;
        final elapsedSeconds = elapsedMs / 1000.0;

        // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
        final outputTokens = result.length / 4;
        final inputTokens = prompt.length / 4;
        final totalTokens = outputTokens + inputTokens;

        // Calculate detailed performance metrics
        final firstTokenTime = elapsedSeconds * 0.1;
        final prefillSpeed = inputTokens / (firstTokenTime > 0 ? firstTokenTime : 0.1);
        final decodeTime = elapsedSeconds - firstTokenTime;
        final decodeSpeed = outputTokens / (decodeTime > 0 ? decodeTime : 0.1);

        _performanceMetrics = {
          'firstToken': firstTokenTime,
          'prefillSpeed': prefillSpeed,
          'decodeSpeed': decodeSpeed,
          'latency': elapsedSeconds,
        };

        final benchmarkInfo = '''
Inference Time: ${elapsedMs}ms (${elapsedSeconds.toStringAsFixed(2)}s)
Estimated Tokens: ${totalTokens.toStringAsFixed(0)} (${inputTokens.toStringAsFixed(0)} input + ${outputTokens.toStringAsFixed(0)} output)
Tokens/Second: ${(totalTokens / elapsedSeconds).toStringAsFixed(2)}
Characters Generated: ${result.length}
''';

        setState(() {
          _inferenceResult = result;
          _benchmarkResults = benchmarkInfo;
          _isInferenceLoading = false;
        });
      } else {
        setState(() {
          _inferenceResult = 'Failed to generate response';
          _benchmarkResults = '';
          _performanceMetrics = {};
          _isInferenceLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _inferenceResult = 'Error during inference: $e';
        _benchmarkResults = '';
        _performanceMetrics = {};
        _isInferenceLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Testing'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Column(
          children: <Widget>[
            // Model Status Section
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListenableBuilder(
                  listenable: _modelController,
                  builder: (context, _) {
                    return ExpansionTile(
                      title: const Text(
                        'Model Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      subtitle: ListenableBuilder(
                        listenable: _llamaService,
                        builder: (context, _) {
                          return Text(
                            _llamaService.statusMessage,
                            style: const TextStyle(fontSize: 14),
                          );
                        },
                      ),
                      initiallyExpanded: _modelController.isExpanded,
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          _modelController.expand();
                        } else {
                          _modelController.collapse();
                        }
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              // Model File Selection Section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Model File Selection',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ListenableBuilder(
                                      listenable: _llamaService,
                                      builder: (context, _) {
                                        if (_llamaService.selectedModelName != null) {
                                          return Text(
                                            'Selected: ${_llamaService.selectedModelName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        } else {
                                          return const Text(
                                            'No model file selected',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ListenableBuilder(
                                        listenable: _llamaService,
                                        builder: (context, _) {
                                          return ElevatedButton.icon(
                                            onPressed: _isLoading ? null : _browseAndLoadModel,
                                            icon: _isLoading 
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : Icon(
                                                  _llamaService.isModelLoaded 
                                                    ? Icons.check_circle 
                                                    : (_modelPath == null ? Icons.search : Icons.play_arrow),
                                                  size: 18,
                                                ),
                                            label: Text(
                                              _isLoading 
                                                ? 'Loading...' 
                                                : (_llamaService.isModelLoaded 
                                                    ? 'Model Loaded ✓' 
                                                    : (_modelPath == null ? 'Browse & Load GGUF' : 'Load Model')),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _isLoading 
                                                ? Colors.grey 
                                                : (_llamaService.isModelLoaded 
                                                    ? Colors.lightGreen 
                                                    : (_modelPath == null ? Colors.blue : Colors.orange)),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                                            // Action Buttons Section
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    await _llamaService.initializeLlama();
                    setState(() => _isLoading = false);
                  },
                  child: const Text('Reinitialize FFI'),
                ),
              ),

              // Debug iOS Directories Button (only on iOS)
              if (Platform.isIOS) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _debugIOSDirectories,
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Debug iOS Directories'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // Inference Section
            const Text(
              'Model Inference',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _promptController,
              enabled: _llamaService.isModelLoaded && !_isInferenceLoading,
              decoration: const InputDecoration(
                labelText: 'Enter your prompt',
                hintText: 'e.g., What is the capital of France?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ListenableBuilder(
                listenable: _llamaService,
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed:
                        _llamaService.isModelLoaded &&
                                !_isInferenceLoading &&
                                _promptController.text.trim().isNotEmpty
                            ? _performInference
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _isInferenceLoading
                            ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Processing...'),
                              ],
                            )
                            : const Text('Run Inference'),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Results Section
            if (_inferenceResult.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 150,
                  maxHeight: 300,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inference Result:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _inferenceResult,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Benchmark Results Section
            if (_benchmarkResults.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Metrics:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _benchmarkResults,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    // Performance Stats Section
                    if (_performanceMetrics.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Stats on CPU',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                            children: [
                              _buildMetricCard(
                                '1st token',
                                '${_performanceMetrics['firstToken']?.toStringAsFixed(2) ?? '0.00'}',
                                'sec',
                              ),
                              _buildMetricCard(
                                'Prefill',
                                '${_performanceMetrics['prefillSpeed']?.toStringAsFixed(2) ?? '0.00'}',
                                'tokens/s',
                              ),
                              _buildMetricCard(
                                'Decode',
                                '${_performanceMetrics['decodeSpeed']?.toStringAsFixed(2) ?? '0.00'}',
                                'tokens/s',
                              ),
                              _buildMetricCard(
                                'Latency',
                                '${_performanceMetrics['latency']?.toStringAsFixed(2) ?? '0.00'}',
                                'sec',
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Inference parameters class for isolate communication
class InferenceParams {
  final String modelPath;
  final String prompt;
  final int maxTokens;

  InferenceParams({
    required this.modelPath,
    required this.prompt,
    required this.maxTokens,
  });
}

// Top-level function for isolate execution
Future<String?> _performInferenceInIsolate(InferenceParams params) async {
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
    print('Error in inference isolate: $e');
    return null;
  }
} 