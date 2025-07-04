import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'llama_ffi.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
  LlamaFFI? _llamaFFI;
  String _statusMessage = 'Ready to test Llama FFI';
  bool _isLoading = false;

  // Model-related state
  final ExpansibleController _modelController = ExpansibleController();
  String? _modelPath;
  String? _selectedModelName;
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

    // Check Android version and handle permissions accordingly
    if (Platform.isAndroid) {
      // For Android 11+ (API level 30+), we need MANAGE_EXTERNAL_STORAGE
      // For Android 13+ (API level 33+), we need READ_MEDIA_* permissions
      
      // First, try the basic storage permission
      var storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        storageStatus = await Permission.storage.request();
      }
      
      // If basic storage permission is granted, return true
      if (storageStatus.isGranted) {
        return true;
      }
      
      // If basic storage permission is denied, try MANAGE_EXTERNAL_STORAGE
      var manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isDenied) {
        // Show a dialog explaining why we need this permission
        setState(() {
          _statusMessage = 'This app needs access to Downloads folder to load AI models. Please grant "All files access" permission in the next screen.';
        });
        
        // Wait a bit for user to read the message
        await Future.delayed(const Duration(seconds: 2));
        
        manageStatus = await Permission.manageExternalStorage.request();
      }
      
      // If MANAGE_EXTERNAL_STORAGE is granted, return true
      if (manageStatus.isGranted) {
        return true;
      }
      
      // If all permissions are denied, show error message
      setState(() {
        _statusMessage = 'Storage permissions are required to access model files. Please grant permissions in Settings > Apps > Little Star App > Permissions.';
      });
      
      return false;
    }

    return true;
  }

  // Manual permission request method for the button
  Future<void> _requestPermissionsManually() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting permissions...';
    });

    final hasPermission = await _requestPermissions();
    
    if (hasPermission) {
      // If permissions are granted, reinitialize the app
      await _initializeLlama();
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Storage permissions are still required. Please grant permissions in Settings > Apps > Little Star App > Permissions, then tap "Grant Permissions" again.';
      });
    }
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
    // const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_S.gguf';
    const modelFileName = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q8_0.gguf';

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



  // Method to browse and list available GGUF files in common directories
  Future<void> _browseGGUFFiles() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Browsing for GGUF files...';
    });

    try {
      // Check and request permissions first
      if (Platform.isAndroid) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          setState(() {
            _statusMessage = 'Storage permission denied. Cannot browse files.';
            _isLoading = false;
          });
          return;
        }
      }

      List<String> ggufFiles = [];
      
      if (Platform.isAndroid) {
        // Common directories to search on Android
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
      } else {
        // For desktop platforms, search in current directory
        final currentDir = Directory.current;
        final files = currentDir.listSync(recursive: false);
        for (final file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.gguf')) {
            ggufFiles.add(file.path);
          }
        }
      }

      if (ggufFiles.isNotEmpty) {
        // Show a dialog to select from found files
        _showGGUFFilesDialog(ggufFiles);
      } else {
        setState(() {
          _statusMessage = 'No GGUF files found in common directories.\nPlease place GGUF files in Downloads or Documents folder.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error browsing files: $e';
        _isLoading = false;
      });
    }
  }

  // Combined method to browse GGUF files and load model
  Future<void> _browseAndLoadModel() async {
    // If no model is selected, browse for GGUF files first
    if (_modelPath == null) {
      await _browseGGUFFiles();
      // Note: The dialog now automatically loads the model after selection
    } else {
      // If a model is already selected, just load it
      await _loadModel();
    }
  }

  // Show dialog with found GGUF files
  void _showGGUFFilesDialog(List<String> ggufFiles) {
    setState(() {
      _isLoading = false;
    });

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
                      _isModelLoaded = false;
                      _isLoading = true;
                      _statusMessage = 'Model file selected: $fileName\nLoading model...';
                    });
                    // Automatically load the selected model
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

      // List available functions
      _llamaFFI!.listAvailableFunctions();

      setState(() {
        _statusMessage =
            testResult
                ? 'Llama FFI initialized successfully!\nReady to load model. Please select a GGUF model file.'
                : 'Llama FFI loaded but test failed\nPlease check your setup and try again.';
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
      // Yield control to UI thread
      await Future.delayed(Duration.zero);
      
      setState(() {
        _statusMessage = 'Initializing model loader...';
      });
      
      // Another yield to keep UI responsive
      await Future.delayed(const Duration(milliseconds: 50));
      
      setState(() {
        _statusMessage = 'Loading model file...';
      });
      
      final loadModelSuccess = _llamaFFI!.loadModel(_modelPath!);
      
      if (loadModelSuccess) {
        _modelController.collapse();
        
        // Yield before creating context
        await Future.delayed(const Duration(milliseconds: 50));
        
        setState(() {
          _statusMessage = 'Creating inference context...';
        });
        
        final contextCreated = _llamaFFI!.createContext();
        
        setState(() {
          _isModelLoaded = loadModelSuccess && contextCreated;
          _statusMessage = _isModelLoaded
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

  // Fallback method for progressive inference (if isolate approach fails)
  Future<void> _performInferenceProgressive() async {
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
      final stopwatch = Stopwatch()..start();
      final prompt = _promptController.text.trim();
      const maxTokens = 512;

      // Yield control to UI thread before heavy operation
      await Future.delayed(Duration.zero);
      
      setState(() {
        _inferenceResult = 'Tokenizing prompt...';
      });
      
      // Another yield
      await Future.delayed(const Duration(milliseconds: 100));
      
      setState(() {
        _inferenceResult = 'Generating response...';
      });
      
      // Perform inference
      final result = _llamaFFI!.performInference(prompt, maxTokens: maxTokens);
      
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
        final firstTokenTime = elapsedSeconds * 0.1; // Rough estimate
        final prefillSpeed = inputTokens / (firstTokenTime > 0 ? firstTokenTime : 0.1);
        final decodeTime = elapsedSeconds - firstTokenTime;
        final decodeSpeed = outputTokens / (decodeTime > 0 ? decodeTime : 0.1);

        // Store metrics for UI display
        _performanceMetrics = {
          'firstToken': firstTokenTime,
          'prefillSpeed': prefillSpeed,
          'decodeSpeed': decodeSpeed,
          'latency': elapsedSeconds,
        };

        // Format benchmark results
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

  // Enhanced inference with fallback
  Future<void> _performInferenceWithFallback() async {
    try {
      // Try isolate approach first for inference
      await _performInference();
    } catch (e) {
      print('Isolate inference failed, falling back to progressive: $e');
      setState(() {
        _inferenceResult = 'Isolate failed, trying progressive approach...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      await _performInferenceProgressive();
    }
  }

  Future<void> _performInference() async {
    if (_modelPath == null ||
        !_isModelLoaded ||
        _promptController.text.trim().isEmpty) {
      return;
    }

    final prompt = _promptController.text.trim();
    const maxTokens = 512;

    setState(() {
      _isInferenceLoading = true;
      _inferenceResult = 'Processing in background...';
      _benchmarkResults = '';
    });

    try {
      // Prepare inference parameters
      final inferenceParams = InferenceParams(
        modelPath: _modelPath!,
        prompt: prompt,
        maxTokens: maxTokens,
      );

      // Start timing
      final stopwatch = Stopwatch()..start();
      
      // Run inference in background isolate
      final result = await compute(_performInferenceInIsolate, inferenceParams);
      
      // Stop timing
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
        final firstTokenTime = elapsedSeconds * 0.1; // Rough estimate
        final prefillSpeed = inputTokens / (firstTokenTime > 0 ? firstTokenTime : 0.1);
        final decodeTime = elapsedSeconds - firstTokenTime;
        final decodeSpeed = outputTokens / (decodeTime > 0 ? decodeTime : 0.1);

        // Store metrics for UI display
        _performanceMetrics = {
          'firstToken': firstTokenTime,
          'prefillSpeed': prefillSpeed,
          'decodeSpeed': decodeSpeed,
          'latency': elapsedSeconds,
        };

        // Format benchmark results
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
                                if (_selectedModelName != null)
                                  Text(
                                    'Selected: $_selectedModelName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  const Text(
                                    'No model file selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
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
                                          _isModelLoaded 
                                            ? Icons.check_circle 
                                            : (_modelPath == null ? Icons.search : Icons.play_arrow),
                                          size: 18,
                                        ),
                                    label: Text(
                                      _isLoading 
                                        ? 'Loading...' 
                                        : (_isModelLoaded 
                                            ? 'Model Loaded ✓' 
                                            : (_modelPath == null ? 'Browse & Load GGUF' : 'Load Model')),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isLoading 
                                        ? Colors.grey 
                                        : (_isModelLoaded 
                                            ? Colors.lightGreen 
                                            : (_modelPath == null ? Colors.blue : Colors.orange)),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Action Buttons Section
                          SizedBox(
                            width: double.infinity,
                            child: 
                              // Show permission request button if permissions are denied
                              (_statusMessage.contains('Storage permission denied') || _statusMessage.contains('Storage permissions are required'))
                                ? ElevatedButton(
                                    onPressed: _isLoading ? null : _requestPermissionsManually,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Grant Permissions'),
                                  )
                                : ElevatedButton(
                                    onPressed: _isLoading ? null : _initializeLlama,
                                    child: const Text('Reinitialize FFI'),
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
                        ? _performInferenceWithFallback
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

// Top-level functions for isolate execution

// Inference isolate function - this works because it's a complete operation
Future<String?> _performInferenceInIsolate(InferenceParams params) async {
  try {
    // Create a new FFI instance in this isolate
    final llamaFFI = LlamaFFI();
    
    // Initialize backend
    if (Platform.isWindows) {
      llamaFFI.ggml_backend_load_all();
    } else {
      llamaFFI.initBackend();
    }
    
    // Load the model
    final modelLoaded = llamaFFI.loadModel(params.modelPath);
    if (!modelLoaded) {
      llamaFFI.freeBackend();
      return null;
    }
    
    // Create context
    final contextCreated = llamaFFI.createContext();
    if (!contextCreated) {
      llamaFFI.freeBackend();
      return null;
    }
    
    // Perform inference
    final result = llamaFFI.performInference(
      params.prompt,
      maxTokens: params.maxTokens,
    );
    
    // Clean up
    llamaFFI.freeBackend();
    
    return result;
  } catch (e) {
    print('Error in inference isolate: $e');
    return null;
  }
}
