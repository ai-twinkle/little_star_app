import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/llama_service.dart';
import '../services/ios_directory_service.dart';
import '../core/lm.dart';

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

  // Context parameters state
  bool _useCustomContextParams = false;
  int _nCtx = 1024;
  int _nBatch = 256;
  int _nUbatch = 128;
  int _nSeqMax = 1;
  int _nThreads = 2;
  int _nThreadsBatch = 1;

  // Sampling parameters state
  bool _useCustomSamplingParams = false;
  int _maxTokens = 512;
  double _temperature = 0.8;
  int _topK = 40;
  double _topP = 0.9;

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

  // Show debug menu
  void _showDebugMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Debug Tools',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Diagnostic and debugging tools for troubleshooting',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              // Debug iOS Directories Button (only on iOS)
              if (Platform.isIOS) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close bottom sheet
                    await _debugIOSDirectories();
                  },
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Debug iOS Directories'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // FFI Library Test Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () async {
                  Navigator.of(context).pop(); // Close bottom sheet
                  setState(() => _isLoading = true);
                  
                  try {
                    final success = _llamaService.llamaFFI?.testLibrary() ?? false;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success 
                              ? 'FFI library test passed ✓'
                              : 'FFI library test failed ✗'
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('FFI test error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  
                  setState(() => _isLoading = false);
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Test FFI Library'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Show settings menu
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.settings, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Advanced Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure context parameters and advanced options',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Enable Custom Parameters Toggle
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _useCustomContextParams,
                                      onChanged: (value) {
                                        setState(() {
                                          _useCustomContextParams = value ?? false;
                                        });
                                        setModalState(() {
                                          _useCustomContextParams = value ?? false;
                                        });
                                      },
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Use Custom Context Parameters',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _useCustomContextParams
                                    ? 'Custom parameters will override automatic optimizations'
                                    : Platform.isIOS 
                                      ? 'iOS optimizations will be applied automatically'
                                      : 'Default llama.cpp parameters will be used',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Context Parameters Configuration (only shown when custom is enabled)
                          if (_useCustomContextParams) ...[
                            const SizedBox(height: 16),
                            Container(
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
                                    'Context Parameters Configuration',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Context Size
                                  _buildSliderSetting(
                                    'Context Size', 
                                    _nCtx.toDouble(), 
                                    512, 
                                    4096, 
                                    7,
                                    (value) {
                                      setState(() => _nCtx = value.round());
                                      setModalState(() => _nCtx = value.round());
                                    },
                                    'Controls the maximum context length for the model'
                                  ),
                                  
                                  // Batch Size
                                  _buildSliderSetting(
                                    'Batch Size', 
                                    _nBatch.toDouble(), 
                                    32, 
                                    1024, 
                                    31,
                                    (value) {
                                      setState(() => _nBatch = value.round());
                                      setModalState(() => _nBatch = value.round());
                                    },
                                    'Logical maximum batch size for processing'
                                  ),
                                  
                                  // Micro-batch Size
                                  _buildSliderSetting(
                                    'Micro-batch Size', 
                                    _nUbatch.toDouble(), 
                                    32, 
                                    512, 
                                    15,
                                    (value) {
                                      setState(() => _nUbatch = value.round());
                                      setModalState(() => _nUbatch = value.round());
                                    },
                                    'Physical maximum batch size for processing'
                                  ),
                                  
                                  // Threads
                                  _buildSliderSetting(
                                    'Threads', 
                                    _nThreads.toDouble(), 
                                    1, 
                                    8, 
                                    7,
                                    (value) {
                                      setState(() => _nThreads = value.round());
                                      setModalState(() => _nThreads = value.round());
                                    },
                                    'Number of threads for generation'
                                  ),
                                  
                                  // Batch Threads
                                  _buildSliderSetting(
                                    'Batch Threads', 
                                    _nThreadsBatch.toDouble(), 
                                    1, 
                                    4, 
                                    3,
                                    (value) {
                                      setState(() => _nThreadsBatch = value.round());
                                      setModalState(() => _nThreadsBatch = value.round());
                                    },
                                    'Number of threads for batch processing'
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Quick presets
                                  const Text(
                                    'Quick Presets:',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _nCtx = 1024;
                                              _nBatch = 256;
                                              _nUbatch = 128;
                                              _nThreads = 2;
                                              _nThreadsBatch = 1;
                                              _nSeqMax = 1;
                                            });
                                            setModalState(() {
                                              _nCtx = 1024;
                                              _nBatch = 256;
                                              _nUbatch = 128;
                                              _nThreads = 2;
                                              _nThreadsBatch = 1;
                                              _nSeqMax = 1;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[100],
                                            foregroundColor: Colors.green[800],
                                          ),
                                          child: const Text('iOS Optimized', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _nCtx = 2048;
                                              _nBatch = 512;
                                              _nUbatch = 256;
                                              _nThreads = 4;
                                              _nThreadsBatch = 2;
                                              _nSeqMax = 1;
                                            });
                                            setModalState(() {
                                              _nCtx = 2048;
                                              _nBatch = 512;
                                              _nUbatch = 256;
                                              _nThreads = 4;
                                              _nThreadsBatch = 2;
                                              _nSeqMax = 1;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[100],
                                            foregroundColor: Colors.blue[800],
                                          ),
                                          child: const Text('Balanced', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Sampling Parameters Toggle
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _useCustomSamplingParams,
                                      onChanged: (value) {
                                        setState(() {
                                          _useCustomSamplingParams = value ?? false;
                                        });
                                        setModalState(() {
                                          _useCustomSamplingParams = value ?? false;
                                        });
                                      },
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Use Custom Sampling Parameters',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _useCustomSamplingParams
                                    ? 'Custom sampling parameters will control text generation behavior'
                                    : 'Default llama.cpp sampling parameters will be used',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sampling Parameters Configuration (only shown when custom is enabled)
                          if (_useCustomSamplingParams) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sampling Parameters Configuration',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Max Tokens
                                  _buildSliderSetting(
                                    'Max Tokens', 
                                    _maxTokens.toDouble(), 
                                    50, 
                                    2048, 
                                    39,
                                    (value) {
                                      setState(() => _maxTokens = value.round());
                                      setModalState(() => _maxTokens = value.round());
                                    },
                                    'Maximum number of tokens to generate'
                                  ),
                                  
                                  // Temperature
                                  _buildSliderSetting(
                                    'Temperature', 
                                    _temperature, 
                                    0.0, 
                                    2.0, 
                                    20,
                                    (value) {
                                      setState(() => _temperature = value);
                                      setModalState(() => _temperature = value);
                                    },
                                    'Controls randomness (0.0 = deterministic, 1.0 = creative)'
                                  ),
                                  
                                  // Top-K
                                  _buildSliderSetting(
                                    'Top-K', 
                                    _topK.toDouble(), 
                                    1, 
                                    100, 
                                    99,
                                    (value) {
                                      setState(() => _topK = value.round());
                                      setModalState(() => _topK = value.round());
                                    },
                                    'Limits vocabulary to top K most likely tokens'
                                  ),
                                  
                                  // Top-P
                                  _buildSliderSetting(
                                    'Top-P', 
                                    _topP, 
                                    0.1, 
                                    1.0, 
                                    9,
                                    (value) {
                                      setState(() => _topP = value);
                                      setModalState(() => _topP = value);
                                    },
                                    'Nucleus sampling: uses smallest set of tokens with cumulative probability >= P'
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Sampling presets
                                  const Text(
                                    'Sampling Presets:',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _maxTokens = 512;
                                              _temperature = 0.3;
                                              _topK = 20;
                                              _topP = 0.8;
                                            });
                                            setModalState(() {
                                              _maxTokens = 512;
                                              _temperature = 0.3;
                                              _topK = 20;
                                              _topP = 0.8;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[100],
                                            foregroundColor: Colors.green[800],
                                          ),
                                          child: const Text('Conservative', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _maxTokens = 512;
                                              _temperature = 0.8;
                                              _topK = 40;
                                              _topP = 0.9;
                                            });
                                            setModalState(() {
                                              _maxTokens = 512;
                                              _temperature = 0.8;
                                              _topK = 40;
                                              _topP = 0.9;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[100],
                                            foregroundColor: Colors.blue[800],
                                          ),
                                          child: const Text('Balanced', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _maxTokens = 1024;
                                              _temperature = 1.2;
                                              _topK = 60;
                                              _topP = 0.95;
                                            });
                                            setModalState(() {
                                              _maxTokens = 1024;
                                              _temperature = 1.2;
                                              _topK = 60;
                                              _topP = 0.95;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange[100],
                                            foregroundColor: Colors.orange[800],
                                          ),
                                          child: const Text('Creative', style: TextStyle(fontSize: 12)),
                                        ),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build slider settings
  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    int divisions,
    Function(double) onChanged,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (title == 'Temperature' || title == 'Top-P') 
                    ? value.toStringAsFixed(1)
                    : value.round().toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: (title == 'Temperature' || title == 'Top-P') 
              ? value.toStringAsFixed(1)
              : value.round().toString(),
            onChanged: onChanged,
          ),
        ],
      ),
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
    final maxTokens = _useCustomSamplingParams ? _maxTokens : 512;

    setState(() {
      _isInferenceLoading = true;
      _inferenceResult = 'Processing...';
      _benchmarkResults = '';
      _performanceMetrics = {};
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      // Log custom parameter usage
      if (_useCustomContextParams) {
        print('Using custom context parameters: nCtx=$_nCtx, nBatch=$_nBatch, nUbatch=$_nUbatch, nSeqMax=$_nSeqMax, nThreads=$_nThreads, nThreadsBatch=$_nThreadsBatch');
      }
      if (_useCustomSamplingParams) {
        print('Using custom sampling parameters: maxTokens=$_maxTokens, temperature=$_temperature, topK=$_topK, topP=$_topP');
      }
      
      // Use isolate for inference with custom sampling parameters
      final inferenceParams = InferenceParams(
        modelPath: _llamaService.modelPath!,
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: _useCustomSamplingParams ? _temperature : null,
        topK: _useCustomSamplingParams ? _topK : null,
        topP: _useCustomSamplingParams ? _topP : null,
        nCtx: _useCustomContextParams ? _nCtx : null,
        nBatch: _useCustomContextParams ? _nBatch : null,
        nUbatch: _useCustomContextParams ? _nUbatch : null,
        nSeqMax: _useCustomContextParams ? _nSeqMax : null,
        nThreads: _useCustomContextParams ? _nThreads : null,
        nThreadsBatch: _useCustomContextParams ? _nThreadsBatch : null,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Tools',
            onPressed: _showDebugMenu,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsMenu,
          ),
        ],
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
            
            // Custom Parameters Status Indicator
            if (_useCustomContextParams || _useCustomSamplingParams) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using custom ${_useCustomContextParams && _useCustomSamplingParams ? 'context & sampling' : _useCustomContextParams ? 'context' : 'sampling'} parameters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
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

// (Removed local ContextParams to use the one from core/lm.dart)

// Inference parameters class for isolate communication
class InferenceParams {
  final String modelPath;
  final String prompt;
  final int maxTokens;
  final double? temperature;
  final int? topK;
  final double? topP;
  
  // Context parameters
  final int? nCtx;
  final int? nBatch;
  final int? nUbatch;
  final int? nSeqMax;
  final int? nThreads;
  final int? nThreadsBatch;

  InferenceParams({
    required this.modelPath,
    required this.prompt,
    required this.maxTokens,
    this.temperature,
    this.topK,
    this.topP,
    this.nCtx,
    this.nBatch,
    this.nUbatch,
    this.nSeqMax,
    this.nThreads,
    this.nThreadsBatch,
  });
}

// Top-level function for isolate execution
Future<String?> _performInferenceInIsolate(InferenceParams params) async {
  try {
    final modelParams = ModelParams(modelPath: params.modelPath);

    final contextParams = ContextParams();
    if (params.nCtx != null) contextParams.nCtx = params.nCtx!;
    if (params.nBatch != null) contextParams.nBatch = params.nBatch!;
    if (params.nUbatch != null) contextParams.nUbatch = params.nUbatch!;
    if (params.nSeqMax != null) contextParams.nSeqMax = params.nSeqMax!;
    if (params.nThreads != null) contextParams.nThreads = params.nThreads!;
    if (params.nThreadsBatch != null) contextParams.nThreadsBatch = params.nThreadsBatch!;

    final samplerParams = SamplerParams();
    samplerParams.temp = params.temperature;
    samplerParams.topK = params.topK;
    samplerParams.topP = params.topP;

    final lm = UnifiedLM.withParams(
      modelParams,
      contextParams,
      samplerParams,
    );

    final result = lm.completion(params.prompt);
    
    return result;
  } catch (e) {
    print('Error in inference isolate: $e');
    return null;
  }
} 