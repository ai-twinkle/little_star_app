import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:little_star_app/core/benchmark/benchmark_recorder.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/benchmark/protocol_runner.dart';
import 'package:little_star_app/core/benchmark/sustained_load_runner.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

/// One entry in the "pick a downloaded model" list — scanned straight off
/// disk (same directories the app's own model manager screens use) so the
/// user never has to hand-type an app-sandboxed path (which changes every
/// reinstall, e.g. `/var/mobile/Containers/Data/Application/<UUID>/...`).
class _ModelOption {
  final String label;
  final String path;
  const _ModelOption(this.label, this.path);
}

Future<List<_ModelOption>> _discoverLocalModels() async {
  final options = <_ModelOption>[];
  try {
    final modelsDir = await DirectoryServiceFactory.create().getModelsDirectory();
    if (await modelsDir.exists()) {
      await for (final entity in modelsDir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
          options.add(_ModelOption('GGUF · ${p.basename(entity.path)}', entity.path));
        }
      }
    }
  } catch (_) {
    // Best-effort discovery — falls back to manual path entry.
  }
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    final mlxDir = Directory(p.join(appSupportDir.path, 'Models', 'mlx'));
    if (await mlxDir.exists()) {
      await for (final entity in mlxDir.list()) {
        if (entity is Directory) {
          options.add(_ModelOption('MLX · ${p.basename(entity.path)}', entity.path));
        }
      }
    }
  } catch (_) {
    // Best-effort discovery — falls back to manual path entry.
  }
  return options;
}

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
  late final BenchmarkProtocolRunner _protocolRunner;
  late final SustainedLoadRunner _sustainedLoadRunner;
  late final TextEditingController _pathController;
  late final TextEditingController _promptController;

  PreflightStatus? _preflight;
  bool _appJustLaunched = false;
  bool _sustainedLoadRunning = false;
  List<_ModelOption> _availableModels = [];

  static const _defaultPrompt = '請用三句話介紹台灣夜市文化,並推薦三樣必吃小吃。';

  @override
  void initState() {
    super.initState();
    _viewModel = BenchmarkViewModel()..addListener(_onChanged);
    _protocolRunner = BenchmarkProtocolRunner(_viewModel);
    _sustainedLoadRunner = SustainedLoadRunner(_viewModel);
    _pathController = TextEditingController(text: widget.initialModelPath ?? '');
    _promptController = TextEditingController(text: _defaultPrompt);
    _refreshPreflight();
    _discoverLocalModels().then((models) {
      if (mounted) setState(() => _availableModels = models);
    });
  }

  Future<void> _pickModel() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _availableModels.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No downloaded models found in the app\'s model directories.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final m in _availableModels)
                    ListTile(
                      title: Text(m.label),
                      subtitle: Text(m.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(context, m.path),
                    ),
                ],
              ),
      ),
    );
    if (selected != null) {
      setState(() => _pathController.text = selected);
    }
  }

  Future<void> _refreshPreflight() async {
    final status = await _viewModel.checkPreflight();
    if (mounted) setState(() => _preflight = status);
  }

  Future<void> _runProtocol() async {
    final wasAppJustLaunched = _appJustLaunched;
    setState(() => _appJustLaunched = false); // consumed — only applies once
    await _protocolRunner.runAll(
      _pathController.text.trim(),
      appJustLaunched: wasAppJustLaunched,
    );
  }

  Future<void> _runSustainedLoad() async {
    setState(() => _sustainedLoadRunning = true);
    try {
      await _sustainedLoadRunner.run(
        messages: [ChatMessage(content: _promptController.text, isUser: true)],
      );
    } finally {
      if (mounted) setState(() => _sustainedLoadRunning = false);
    }
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
    if (!mounted) return;
    // iOS requires a non-zero sharePositionOrigin for the share sheet's
    // popover anchor — without it, shareXFiles throws a PlatformException
    // and the sheet never appears (silently dropping the export).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
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
            _PreflightBanner(status: _preflight, onRefresh: _refreshPreflight),
            const SizedBox(height: 12),
            TextField(
              controller: _pathController,
              enabled: !_viewModel.hasOpenSession,
              decoration: InputDecoration(
                labelText: 'Model path (.gguf file or MLX directory)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Pick a downloaded model',
                  onPressed: _viewModel.hasOpenSession ? null : _pickModel,
                ),
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
                      : () => _viewModel.openSessionAndRunPrompt(
                            _pathController.text.trim(),
                            _promptController.text,
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Open session + run (cold)'),
                ),
                OutlinedButton.icon(
                  onPressed: _viewModel.isRunning || !_viewModel.hasOpenSession
                      ? null
                      : () => _viewModel.runOnOpenSessionPrompt(_promptController.text),
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
            const Divider(height: 24),
            Text('Standardized protocol (task-C02)', style: Theme.of(context).textTheme.titleSmall),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _appJustLaunched,
              onChanged: _viewModel.isRunning
                  ? null
                  : (v) => setState(() => _appJustLaunched = v ?? false),
              title: const Text('App was just force-quit + relaunched (labels first sample app-cold)'),
            ),
            FilledButton.icon(
              onPressed: _viewModel.isRunning || _pathController.text.trim().isEmpty
                  ? null
                  : _runProtocol,
              icon: const Icon(Icons.playlist_play),
              label: const Text('Run standardized protocol (all 4 tiers)'),
            ),
            const Divider(height: 24),
            Text('Sustained load (task-C03)', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _sustainedLoadRunning || !_viewModel.hasOpenSession
                      ? null
                      : _runSustainedLoad,
                  icon: const Icon(Icons.timelapse),
                  label: const Text('Run 10 min sustained load'),
                ),
                if (_sustainedLoadRunning)
                  OutlinedButton.icon(
                    onPressed: _sustainedLoadRunner.cancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop'),
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

/// Shows what the app itself can verify from the pre-flight checklist
/// (docs/benchmark/zh-tw-prompt-set.md Part 3). Airplane mode and screen
/// brightness aren't readable by a third-party app, so those stay a manual
/// reminder here rather than something this banner can confirm.
class _PreflightBanner extends StatelessWidget {
  final PreflightStatus? status;
  final VoidCallback onRefresh;
  const _PreflightBanner({required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final warn = s != null && !s.isThermalNominal;
    return Card(
      color: warn ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s == null
                    ? 'Checking thermal/battery…'
                    : 'thermal: ${s.thermalState.name}${warn ? ' (cool down before running)' : ''} · '
                        'battery: ${s.batteryLevel ?? '-'}% · '
                        'manual: airplane mode + fixed brightness',
              ),
            ),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
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
