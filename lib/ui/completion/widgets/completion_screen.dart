import 'package:flutter/material.dart';

import 'package:little_star_app/ui/completion/view_model/completion_viewmodel.dart';


class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  final CompletionViewModel viewModel = CompletionViewModel(modelPath: 'models/llama-3.1-8b-instruct.gguf');

  final _promptController = TextEditingController();
  final _outputScroll = ScrollController();

  bool _browsing = false;
  bool _loadingModel = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}