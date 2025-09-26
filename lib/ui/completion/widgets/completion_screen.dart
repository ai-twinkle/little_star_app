import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void dispose() {
    _promptController.dispose();
    _outputScroll.dispose();
    viewModel.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration? d) {
    if (d == null) return '-';
    final ms = d.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    final s = (ms / 1000.0);
    return s.toStringAsFixed(2) + 's';
  }

  String _fmtDouble(double? v, {int frac = 2}) {
    if (v == null) return '-';
    return v.toStringAsFixed(frac);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion'),
      ),
      body: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_outputScroll.hasClients) {
              _outputScroll.jumpTo(_outputScroll.position.maxScrollExtent);
            }
          });

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _promptController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: viewModel.isRunning
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              final prompt = _promptController.text.trim();
                              if (prompt.isEmpty) return;
                              viewModel.startCompletion(prompt, maxTokens: 256);
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run'),
                    ),
                    OutlinedButton.icon(
                      onPressed: viewModel.isRunning
                          ? () {
                              viewModel.cancel();
                            }
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Cancel'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        viewModel.reset();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final json = viewModel.exportMetricsJson();
                        await Clipboard.setData(ClipboardData(text: json));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Metrics JSON copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export JSON'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _MetricTile(title: 'TTFT', value: _fmtDuration(viewModel.ttft))),
                            Expanded(child: _MetricTile(title: 'Prefill tps', value: _fmtDouble(viewModel.prefillTokensPerSecond))),
                            Expanded(child: _MetricTile(title: 'Decode tps', value: _fmtDouble(viewModel.decodeTokensPerSecond))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _MetricTile(title: 'Prompt tokens', value: '${viewModel.promptTokenCount}')),
                            Expanded(child: _MetricTile(title: 'Gen tokens', value: '${viewModel.generatedTokenCount}')),
                            Expanded(child: _MetricTile(title: 'Total time', value: _fmtDuration(viewModel.totalDuration))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Stop reason: ${viewModel.stopReason ?? '-'}'),
                        if (viewModel.isRunning) const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SingleChildScrollView(
                        controller: _outputScroll,
                        child: Text(
                          viewModel.outputText,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}