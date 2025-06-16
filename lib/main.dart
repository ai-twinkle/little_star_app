import 'package:flutter/material.dart';
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

  Future<void> _initializeLlama() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing Llama FFI...';
    });

    try {
      _llamaFFI = LlamaFFI();
      _llamaFFI!.initBackend();
      
      // Test the library
      final testResult = _llamaFFI!.testLibrary();
      
      // Check if model file exists
      final modelExists = _llamaFFI!.modelFileExists('Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf');
      
      // List available functions
      _llamaFFI!.listAvailableFunctions();
      
      setState(() {
        _statusMessage = testResult 
          ? 'Llama FFI initialized successfully!\nModel file exists: $modelExists'
          : 'Llama FFI loaded but test failed';
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
