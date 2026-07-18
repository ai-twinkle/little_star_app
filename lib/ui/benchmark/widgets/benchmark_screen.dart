import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

/// Internal-only benchmark harness screen (task-C01) — not part of the
/// customer-facing app (plan.md scoped C-line as "內部量測工具"). Reachable
/// only via the debug-gated entry point on the home screen.
class BenchmarkScreen extends StatefulWidget {
  final String? initialModelPath;

  const BenchmarkScreen({super.key, this.initialModelPath});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final BenchmarkViewModel _viewModel;
  late final TextEditingController _pathController;
  late final TextEditingController _promptController;

  static const _defaultPrompt = '請用三句話介紹台灣夜市文化,並推薦三樣必吃小吃。';

  @override
  void initState() {
    super.initState();
    _viewModel = BenchmarkViewModel()..addListener(_onChanged);
    _pathController = TextEditingController(text: widget.initialModelPath ?? '');
    _promptController = TextEditingController(text: _defaultPrompt);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _pathController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _share(Future<dynamic> Function() export) async {
    final file = await export();
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark (Internal)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pathController,
              enabled: !_viewModel.hasOpenSession,
              decoration: const InputDecoration(
                labelText: 'Model path (.gguf file or MLX directory)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _viewModel.isRunning || _pathController.text.trim().isEmpty
                      ? null
                      : () => _viewModel.openSessionAndRun(
                            _pathController.text.trim(),
                            _promptController.text,
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Open session + run (cold)'),
                ),
                OutlinedButton.icon(
                  onPressed: _viewModel.isRunning || !_viewModel.hasOpenSession
                      ? null
                      : () => _viewModel.runOnOpenSession(_promptController.text),
                  icon: const Icon(Icons.replay),
                  label: const Text('Run again (warm)'),
                ),
                OutlinedButton.icon(
                  onPressed: !_viewModel.hasOpenSession ? null : _viewModel.closeSession,
                  icon: const Icon(Icons.stop),
                  label: const Text('Close session'),
                ),
              ],
            ),
            if (_viewModel.isRunning) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_viewModel.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                _viewModel.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${_viewModel.samples.length} sample(s)',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: _viewModel.samples.isEmpty ? null : _viewModel.clearSamples,
                  child: const Text('Clear'),
                ),
                TextButton.icon(
                  onPressed:
                      _viewModel.samples.isEmpty ? null : () => _share(_viewModel.exportCsv),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('CSV'),
                ),
                TextButton.icon(
                  onPressed:
                      _viewModel.samples.isEmpty ? null : () => _share(_viewModel.exportJson),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('JSON'),
                ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _viewModel.samples.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => _SampleTile(
                  sample: _viewModel.samples[_viewModel.samples.length - 1 - index],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  final BenchmarkSample sample;
  const _SampleTile({required this.sample});

  @override
  Widget build(BuildContext context) {
    final g = sample.generation;
    return ListTile(
      dense: true,
      title: Text('${sample.format.name} · ${sample.label ?? '(no label)'}'),
      subtitle: Text(
        'TTFT ${g.ttft?.inMilliseconds ?? '-'}ms · '
        'decode ${g.tokensPerSecond?.toStringAsFixed(1) ?? '-'} tok/s · '
        'prefill ${g.prefillTokensPerSecond?.toStringAsFixed(1) ?? '-'} tok/s · '
        'peakMem ${sample.peakMemoryBytes != null ? '${(sample.peakMemoryBytes! / 1e6).toStringAsFixed(0)}MB' : '-'} · '
        'thermal ${sample.thermalStateBefore.name}→${sample.thermalStateAfter.name} · '
        'battery ${sample.batteryLevelBefore ?? '-'}→${sample.batteryLevelAfter ?? '-'}',
      ),
    );
  }
}
