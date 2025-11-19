import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:little_star_app/ui/completion/view_model/completion_viewmodel.dart';
import 'package:little_star_app/ui/completion/widgets/advanced_settings_sheet.dart';
import 'package:little_star_app/ui/completion/widgets/model_selection_dialog.dart';


class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  final CompletionViewModel viewModel = CompletionViewModel(modelPath: '/storage/emulated/0/Download/Llama-3.2-3B-F1-Reasoning-Instruct-Q3_K_M.gguf');

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
    return '${s.toStringAsFixed(2)}s';
  }

  String _fmtDouble(double? v, {int frac = 2}) {
    if (v == null) return '-';
    return v.toStringAsFixed(frac);
  }

  void _showAdvancedSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AdvancedSettingsSheet(
        maxTokens: viewModel.maxTokens,
        stopSequences: viewModel.stopSequences,
        temperature: viewModel.temperature,
        topK: viewModel.topK,
        topP: viewModel.topP,
        systemPrompt: viewModel.systemPrompt,
        onApply: viewModel.updateSettings,
        onReset: viewModel.resetSettings,
      ),
    );
  }

  void _showModelSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        onModelSelected: (modelPath) async {
          try {
            await viewModel.selectModel(modelPath);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load model: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion'),
        actions: [
          // 進階設定按鈕
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Advanced settings',
            onPressed: () => _showAdvancedSettings(context),
          ),
          // 選擇模型按鈕
          // IconButton(
          //   icon: const Icon(Icons.inventory_2),
          //   tooltip: '選擇模型',
          //   onPressed: () => _showModelSelection(context),
          // ),
        ],
      ),
      body: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 模型狀態卡片
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // const Icon(Icons.model_training, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Current model',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        viewModel.selectedModelName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showModelSelection(context),
                                  icon: const Icon(Icons.swap_horiz, size: 12),
                                  label: const Text('Select GGUF'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                  ? () {
                                viewModel.cancel();
                              }
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      final prompt = _promptController.text.trim();
                                      if (prompt.isEmpty) return;
                                      viewModel.startCompletion(prompt);
                                    },
                              icon: !viewModel.isRunning
                                  ? const Icon(Icons.play_arrow)
                                  : const Icon(Icons.stop),
                              label: !viewModel.isRunning
                                  ? const Text('Run')
                                  : const Text('Cancel'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                viewModel.reset();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                            // OutlinedButton.icon(
                            //   onPressed: () async {
                            //     final json = viewModel.exportMetricsJson();
                            //     await Clipboard.setData(ClipboardData(text: json));
                            //     if (!mounted) return;
                            //     ScaffoldMessenger.of(context).showSnackBar(
                            //       const SnackBar(content: Text('Metrics JSON copied to clipboard')),
                            //     );
                            //   },
                            //   icon: const Icon(Icons.file_download),
                            //   label: const Text('Export JSON'),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Metrics Card - uses ValueListenableBuilder for better performance
                        ValueListenableBuilder(
                          valueListenable: viewModel.metricsNotifier,
                          builder: (context, metrics, child) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _MetricTile(title: 'TTFT', value: _fmtDuration(metrics.ttft))),
                                        Expanded(child: _MetricTile(title: 'Prefill tps', value: _fmtDouble(metrics.prefillTokensPerSecond))),
                                        Expanded(child: _MetricTile(title: 'Decode tps', value: _fmtDouble(metrics.decodeTokensPerSecond))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(child: _MetricTile(title: 'Prompt tokens', value: '${metrics.promptTokenCount}')),
                                        Expanded(child: _MetricTile(title: 'Gen tokens', value: '${metrics.generatedTokenCount}')),
                                        Expanded(child: _MetricTile(title: 'Total time', value: _fmtDuration(metrics.totalDuration))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Stop reason: ${metrics.stopReason ?? '-'}'),
                                    // if (viewModel.isRunning) const Padding(
                                    //   padding: EdgeInsets.only(top: 8.0),
                                    //   child: LinearProgressIndicator(minHeight: 3),
                                    // ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Output Card - uses ValueListenableBuilder for frequent text updates
                        ValueListenableBuilder<String>(
                          valueListenable: viewModel.outputTextNotifier,
                          builder: (context, outputText, child) {
                            // Trigger auto-scroll after text updates
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_outputScroll.hasClients) {
                                _outputScroll.jumpTo(_outputScroll.position.maxScrollExtent);
                              }
                            });

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 200),
                                  child: SingleChildScrollView(
                                    controller: _outputScroll,
                                    child: Text(
                                      outputText,
                                      style: const TextStyle(fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
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