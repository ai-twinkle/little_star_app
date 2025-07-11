import 'package:flutter/foundation.dart';
import '../llama_ffi.dart';
import 'dart:io';

class LlamaService extends ChangeNotifier {
  static final LlamaService _instance = LlamaService._internal();
  factory LlamaService() => _instance;
  LlamaService._internal();

  LlamaFFI? _llamaFFI;
  String? _modelPath;
  String? _selectedModelName;
  bool _isInitialized = false;
  bool _isModelLoaded = false;
  String _statusMessage = 'Ready to initialize';

  // Getters
  LlamaFFI? get llamaFFI => _llamaFFI;
  String? get modelPath => _modelPath;
  String? get selectedModelName => _selectedModelName;
  bool get isInitialized => _isInitialized;
  bool get isModelLoaded => _isModelLoaded;
  String get statusMessage => _statusMessage;

  // Initialize FFI
  Future<bool> initializeLlama() async {
    try {
      _statusMessage = 'Initializing Llama FFI...';
      notifyListeners();

      _llamaFFI = LlamaFFI();

      _statusMessage = 'Initializing backend...';
      notifyListeners();

      if (Platform.isWindows) {
        _llamaFFI!.ggml_backend_load_all();
      } else {
        _llamaFFI!.initBackend();
      }

      _statusMessage = 'Testing library...';
      notifyListeners();

      final testResult = _llamaFFI!.testLibrary();
      _llamaFFI!.listAvailableFunctions();

      _isInitialized = testResult;
      _statusMessage = testResult 
        ? 'Llama FFI initialized successfully!\nReady to load model.'
        : 'Llama FFI loaded but test failed\nPlease check your setup and try again.';
      
      notifyListeners();
      return testResult;
    } catch (e) {
      _statusMessage = 'Failed to initialize Llama FFI: $e';
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  // Load model
  Future<bool> loadModel(String modelPath, String modelName) async {
    if (_llamaFFI == null || !_isInitialized) {
      _statusMessage = 'FFI not initialized';
      notifyListeners();
      return false;
    }

    try {
      _statusMessage = 'Loading model...';
      notifyListeners();

      // Yield control to UI thread
      await Future.delayed(Duration.zero);
      
      _statusMessage = 'Initializing model loader...';
      notifyListeners();
      
      // Another yield to keep UI responsive
      await Future.delayed(const Duration(milliseconds: 50));
      
      _statusMessage = 'Loading model file...';
      notifyListeners();

      final loadModelSuccess = _llamaFFI!.loadModel(modelPath);
      
      if (loadModelSuccess) {
        // Yield before creating context
        await Future.delayed(const Duration(milliseconds: 50));
        
        _statusMessage = 'Creating inference context...';
        notifyListeners();
        
        final contextCreated = _llamaFFI!.createContext();
        _isModelLoaded = loadModelSuccess && contextCreated;
        
        if (_isModelLoaded) {
          _modelPath = modelPath;
          _selectedModelName = modelName;
          _statusMessage = 'Model loaded successfully! Ready for inference.';
        } else {
          _statusMessage = 'Model loaded but failed to create context.';
        }
      } else {
        _isModelLoaded = false;
        _statusMessage = 'Failed to load model from: $modelPath';
      }

      notifyListeners();
      return _isModelLoaded;
    } catch (e) {
      _statusMessage = 'Error loading model: $e';
      _isModelLoaded = false;
      notifyListeners();
      return false;
    }
  }

  // Perform inference
  Future<String?> performInference(String prompt, {int maxTokens = 1024}) async {
    if (_llamaFFI == null || !_isModelLoaded) {
      return null;
    }

    try {
      return _llamaFFI!.performInference(prompt, maxTokens: maxTokens);
    } catch (e) {
      debugPrint('Error during inference: $e');
      return null;
    }
  }

  // Reset model (unload current model)
  void resetModel() {
    _modelPath = null;
    _selectedModelName = null;
    _isModelLoaded = false;
    _statusMessage = 'Model unloaded. Ready to load new model.';
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _llamaFFI?.freeBackend();
    super.dispose();
  }
} 