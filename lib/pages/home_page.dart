import 'package:flutter/material.dart';
import 'model_test_page.dart';
import 'chat_page.dart';
import '../services/llama_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LlamaService _llamaService = LlamaService();
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
    });
    
    await _llamaService.initializeLlama();
    
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Little Star App'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Welcome Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to Little Star',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how you want to interact with AI models',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Service Status
                    ListenableBuilder(
                      listenable: _llamaService,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _llamaService.isInitialized 
                              ? Colors.green[50] 
                              : Colors.orange[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _llamaService.isInitialized 
                                ? Colors.green[200]! 
                                : Colors.orange[200]!,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isInitializing)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Icon(
                                  _llamaService.isInitialized 
                                    ? Icons.check_circle 
                                    : Icons.warning,
                                  size: 16,
                                  color: _llamaService.isInitialized 
                                    ? Colors.green 
                                    : Colors.orange,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _isInitializing 
                                  ? 'Initializing...' 
                                  : (_llamaService.isInitialized 
                                      ? 'Service Ready' 
                                      : 'Service Not Ready'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _llamaService.isInitialized 
                                    ? Colors.green[700] 
                                    : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Navigation Cards
            Expanded(
              child: Column(
                children: [
                  // Model Test Card
                  _buildNavigationCard(
                    context: context,
                    title: 'Model Testing',
                    subtitle: 'Test models with single prompts and view performance metrics',
                    icon: Icons.science,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ModelTestPage()),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chat Card
                  _buildNavigationCard(
                    context: context,
                    title: 'AI Chat',
                    subtitle: 'Have conversations with AI models in a chat interface',
                    icon: Icons.chat,
                    color: Colors.green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatPage()),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Reinitialize button
                  if (!_llamaService.isInitialized && !_isInitializing)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _initializeService,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reinitialize Service'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 