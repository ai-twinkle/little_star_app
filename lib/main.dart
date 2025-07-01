import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'llama_ffi.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little Star App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
      ),
      home: const MyHomePage(title: '✨ A Little Star'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  LlamaFFI? _llamaFFI;
  String _statusMessage = 'Ready to test Llama FFI';
  bool _isLoading = false;

  // Model-related state
  final ExpansibleController _modelController = ExpansibleController();
  String? _modelPath;
  bool _isModelLoaded = false;

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
    _initializeLlama();
  }

  // Request necessary permissions for Android
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // Request storage permission
    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // For Android 11+, try manage external storage permission
    if (await Permission.manageExternalStorage.isDenied) {
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }

    return status.isGranted;
  }

  // Get the correct path for the model file based on platform
  Future<String> getModelPath() async {
    const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_S.gguf';

    if (Platform.isAndroid) {
      // Try different approaches for Android
      final possiblePaths = [
        '/storage/emulated/0/Download/$modelFileName',
        '/sdcard/Download/$modelFileName',
        '/storage/self/primary/Download/$modelFileName',
      ];

      // Try to get external storage directory
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to Downloads from external storage
          final downloadsPath = '/storage/emulated/0/Download/$modelFileName';
          possiblePaths.insert(0, downloadsPath);
        }
      } catch (e) {
        print('Could not get external storage directory: $e');
      }

      return possiblePaths.first; // Return the first path to try
    } else if (Platform.isWindows) {
      return path.join(Directory.current.path, modelFileName);
    } else if (Platform.isLinux || Platform.isMacOS) {
      return path.join(Directory.current.path, modelFileName);
    } else {
      return modelFileName;
    }
  }

  // Check multiple possible locations for the model file
  Future<String?> findModelFile() async {
    const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_S.gguf';

    if (Platform.isAndroid) {
      final possiblePaths = [
        '/storage/emulated/0/Download/$modelFileName',
        '/sdcard/Download/$modelFileName',
        '/storage/self/primary/Download/$modelFileName',
      ];

      for (final testPath in possiblePaths) {
        print('Checking path: $testPath');
        final file = File(testPath);
        if (file.existsSync()) {
          print('Found model file at: $testPath');
          return testPath;
        }
      }
      return null;
    } else {
      final modelPath = await getModelPath();
      return File(modelPath).existsSync() ? modelPath : null;
    }
  }

  Future<void> _initializeLlama() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing Llama FFI...';
    });

    try {
      // Request permissions first on Android
      if (Platform.isAndroid) {
        setState(() {
          _statusMessage = 'Requesting storage permissions...';
        });

        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          setState(() {
            _statusMessage =
                'Storage permission denied. Cannot access Downloads folder.';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _statusMessage = 'Creating FFI instance...';
      });

      _llamaFFI = LlamaFFI();

      setState(() {
        _statusMessage = 'Initializing backend...';
      });

      // Initialize the llama backend
      if (Platform.isWindows) {
        _llamaFFI!.ggml_backend_load_all();
      } else {
        _llamaFFI!.initBackend();
      }

      setState(() {
        _statusMessage = 'Testing library...';
      });

      // Test the library
      final testResult = _llamaFFI!.testLibrary();

      // Platform info
      print('Platform: ${Platform.operatingSystem}');
      print('Current directory: ${Directory.current.path}');

      // Find the model file
      setState(() {
        _statusMessage = 'Looking for model file...';
      });

      final modelPath = await findModelFile();
      final modelExists = modelPath != null;
      _modelPath = modelPath;

      if (Platform.isAndroid && !modelExists) {
        // Try to list Downloads directory for debugging
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (downloadsDir.existsSync()) {
            final files = downloadsDir.listSync();
            print(
              'Files in Downloads: ${files.map((f) => path.basename(f.path)).toList()}',
            );
          } else {
            print('Downloads directory does not exist or is not accessible');
          }
        } catch (e) {
          print('Error accessing Downloads directory: $e');
        }
      }

      // List available functions
      _llamaFFI!.listAvailableFunctions();

      setState(() {
        _statusMessage =
            testResult
                ? 'Llama FFI initialized successfully!\nModel file exists: $modelExists${modelPath != null ? '\nModel path: $modelPath' : '\nModel file not found in Downloads'}'
                : 'Llama FFI loaded but test failed\nModel file exists: $modelExists${modelPath != null ? '\nModel path: $modelPath' : '\nModel file not found in Downloads'}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize Llama FFI: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadModel() async {
    if (_llamaFFI == null || _modelPath == null) {
      setState(() {
        _statusMessage = 'FFI not initialized or model file not found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading model...';
    });

    try {
      final loadModelSuccess = _llamaFFI!.loadModel(_modelPath!);
      if (loadModelSuccess) {
        _modelController.collapse();
        final contextCreated = _llamaFFI!.createContext();
        setState(() {
          _isModelLoaded = loadModelSuccess && contextCreated;
          _statusMessage =
              _isModelLoaded
                  ? 'Model loaded successfully! Ready for inference.'
                  : 'Model loaded but failed to create context.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isModelLoaded = false;
          _statusMessage = 'Failed to load model from: $_modelPath';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _statusMessage = 'Error loading model: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _performInference() async {
    if (_llamaFFI == null ||
        !_isModelLoaded ||
        _promptController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isInferenceLoading = true;
      _inferenceResult = 'Processing...';
      _benchmarkResults = '';
    });

    try {
      // Start timing
      final stopwatch = Stopwatch()..start();
      final prompt = _promptController.text.trim();
      final maxTokens = 100;

      // Time first token (simulate - would need actual FFI support for real measurement)
      final firstTokenStopwatch = Stopwatch()..start();

      // Perform inference
      final result = _llamaFFI!.performInference(prompt, maxTokens: maxTokens);

      // Stop timing
      stopwatch.stop();
      firstTokenStopwatch.stop();

      // Calculate metrics
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final elapsedSeconds = elapsedMs / 1000.0;

      // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
      final outputTokens = (result?.length ?? 0) / 4;
      final inputTokens = prompt.length / 4;
      final totalTokens = outputTokens + inputTokens;

      // Calculate detailed performance metrics
      final firstTokenTime = firstTokenStopwatch.elapsedMilliseconds / 1000.0;
      final prefillSpeed =
          inputTokens / (firstTokenTime > 0 ? firstTokenTime : 0.1);
      final decodeTime = elapsedSeconds - firstTokenTime;
      final decodeSpeed = outputTokens / (decodeTime > 0 ? decodeTime : 0.1);
      final latency = elapsedSeconds;

      // Store metrics for UI display
      _performanceMetrics = {
        'firstToken': firstTokenTime,
        'prefillSpeed': prefillSpeed,
        'decodeSpeed': decodeSpeed,
        'latency': latency,
      };

      // Format benchmark results (legacy format for compatibility)
      final benchmarkInfo = '''
Inference Time: ${elapsedMs}ms (${elapsedSeconds.toStringAsFixed(2)}s)
Estimated Tokens: ${totalTokens.toStringAsFixed(0)} (${inputTokens.toStringAsFixed(0)} input + ${outputTokens.toStringAsFixed(0)} output)
Tokens/Second: ${(totalTokens / elapsedSeconds).toStringAsFixed(2)}
Characters Generated: ${result?.length ?? 0}
''';

      setState(() {
        _inferenceResult = result ?? 'Failed to generate response';
        _benchmarkResults = benchmarkInfo;
        _isInferenceLoading = false;
      });
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
  void dispose() {
    _llamaFFI?.freeBackend();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Column(
          children: <Widget>[
            // Model Status Section
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ExpansionTile(
                  controller: _modelController,
                  title: const Text(
                    'Model Status',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                  initiallyExpanded: !_isModelLoaded,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _initializeLlama,
                                child: const Text('Reinitialize FFI'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton(
                                onPressed:
                                    (_isLoading || _modelPath == null)
                                        ? null
                                        : _loadModel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isModelLoaded
                                          ? Colors.lightGreenAccent
                                          : null,
                                ),
                                child: Text(
                                  _isModelLoaded
                                      ? 'Model Loaded ✓'
                                      : 'Load Model',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              enabled: _isModelLoaded && !_isInferenceLoading,
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
              child: ElevatedButton(
                onPressed:
                    _isModelLoaded &&
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
                    // Performance Stats Section (CPU Stats format)
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
