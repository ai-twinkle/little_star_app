import 'dart:io';

import 'package:flutter/material.dart';

import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/ui/completion/widgets/completion_screen.dart';
import 'package:little_star_app/ui/chat/widgets/chat_screen.dart';
import 'package:little_star_app/ui/models/view_model/model_manager_viewmodel.dart';
import 'package:little_star_app/ui/models/widgets/model_manager_screen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Little Star App'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Welcome Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to Little Star',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how you want to interact with AI models',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Navigation Cards
            Column(
              children: [
                // Model Test Card
                _buildNavigationCard(
                  context: context,
                  title: 'Model Completion',
                  subtitle: 'Test models with single prompts and view performance metrics',
                  icon: Icons.science,
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompletionScreen()),
                  ),
                ),

                const SizedBox(height: 16),

                // Chat Card
                _buildNavigationCard(
                  context: context,
                  title: 'AI Chat (Experimental)',
                  subtitle: 'Have conversations with AI models in a chat interface',
                  icon: Icons.chat,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  ),
                ),

                const SizedBox(height: 16),

                // Model Manager Card
                _buildNavigationCard(
                  context: context,
                  title: 'Model Manager',
                  subtitle: 'Browse, download and manage GGUF models from Hugging Face',
                  icon: Icons.download,
                  color: Colors.orange,
                  onTap: () => _openModelManager(context),
                ),

                // Add some bottom padding to ensure content isn't cut off
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openModelManager(BuildContext context) {
    // Create dependencies
    final directoryService = Platform.isAndroid
        ? AndroidDirectoryService()
        : Platform.isIOS
            ? IOSDirectoryService()
            : DesktopDirectoryService();

    final viewModel = ModelManagerViewModel(
      hfService: HuggingFaceService(),
      downloadService: DownloadService(),
      downloadRepository: DownloadRepository(),
      directoryService: directoryService,
    );

    // Navigate (init is called in ModelManagerScreen's initState)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModelManagerScreen(viewModel: viewModel),
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
                  color: color.withValues(alpha: 0.1),
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
