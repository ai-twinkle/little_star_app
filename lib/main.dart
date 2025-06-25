import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'llama_ffi.dart';

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
      home: const MyHomePage(title: 'A Little Star\'s Home'),
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

  @override
  void initState() {
    super.initState();
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
            _statusMessage = 'Storage permission denied. Cannot access Downloads folder.';
            _isLoading = false;
          });
          return;
        }
      }

      _llamaFFI = LlamaFFI();
      _llamaFFI!.initBackend();
      
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

      if (Platform.isAndroid && !modelExists) {
        // Try to list Downloads directory for debugging
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (downloadsDir.existsSync()) {
            final files = downloadsDir.listSync();
            print('Files in Downloads: ${files.map((f) => path.basename(f.path)).toList()}');
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
        _statusMessage = testResult 
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

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void dispose() {
    _llamaFFI?.freeBackend();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.star,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 20),
            const Text(
              'Llama.cpp FFI Integration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _initializeLlama,
              child: const Text('Reinitialize Llama FFI'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'You have pushed the button this many times:',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
