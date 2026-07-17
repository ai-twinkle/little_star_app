import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/mlx_backend.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:path_provider/path_provider.dart';

/// TEMPORARY probe for task-B03 (2026-07-08-t1-benchmark-talk cycle).
///
/// Exercises the real [MlxBackend]/[MlxSession] (`lib/core/inference/mlx_backend.dart`)
/// against the actual T1 MLX weights, bypassing the production chat UI —
/// [ChatViewModel] is still hardcoded to GGUF and doesn't wire up MlxBackend
/// via the app's DI-provided BackendSelector, so this is the fastest way to
/// confirm the backend abstraction actually loads and streams T1 correctly.
///
/// The HF download step below is copy-adapted from mlx_spike_screen.dart
/// (same ad-hoc approach — no real multi-file MLX import UI exists yet,
/// see construction.md task-B03 notes) since a physical device has no
/// access to the Mac-local conversion output.
///
/// Safe to delete once ChatViewModel/BackendSelector wiring is fixed for real
/// MLX model selection (a separate, larger piece of task-B03).
class MlxBackendProbeScreen extends StatefulWidget {
  const MlxBackendProbeScreen({super.key});

  @override
  State<MlxBackendProbeScreen> createState() => _MlxBackendProbeScreenState();
}

class _MlxBackendProbeScreenState extends State<MlxBackendProbeScreen> {
  // Uploaded in task-B02 — see https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit
  static const _defaultRepo = 'Bbson/gemma-3-4B-T1-it-MLX-4bit';
  static const _defaultSystemPrompt = '你是台灣的 AI 助理，請一律使用繁體中文與台灣用語回答。';

  final _repoController = TextEditingController(text: _defaultRepo);
  final _modelPathController = TextEditingController();
  final _systemPromptController = TextEditingController(text: _defaultSystemPrompt);
  final _promptController =
      TextEditingController(text: '請用三句話介紹台灣夜市文化，並推薦三樣必吃小吃。');
  final _scrollController = ScrollController();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );

  InferenceSession? _session;
  String _status = 'idle';
  String _output = '';
  bool _isBusy = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _autoDetectModel();
  }

  Future<Directory> _modelSnapshotDir(String repoId) async {
    final base = await getApplicationSupportDirectory();
    final slug = repoId.replaceAll('/', '_');
    return Directory('${base.path}/Models/mlx/$slug');
  }

  bool _isMlxFile(String path) {
    final name = path.split('/').last.toLowerCase();
    return name.endsWith('.safetensors') ||
        name == 'config.json' ||
        name == 'tokenizer.json' ||
        name == 'tokenizer_config.json' ||
        name == 'special_tokens_map.json' ||
        name == 'generation_config.json' ||
        name == 'tokenizer.model';
  }

  Future<void> _autoDetectModel() async {
    final dir = await _modelSnapshotDir(_repoController.text.trim());
    final exists = await dir.exists();
    if (!mounted) return;
    if (exists && dir.listSync().isNotEmpty) {
      setState(() {
        _modelPathController.text = dir.path;
        _status = 'Found existing local snapshot ✓';
      });
    }
  }

  Future<void> _downloadModel() async {
    if (_isBusy) return;
    final repoId = _repoController.text.trim();
    setState(() {
      _isBusy = true;
      _status = 'Fetching file list…';
      _downloadProgress = 0;
    });

    try {
      final listResp =
          await _dio.get('https://huggingface.co/api/models/$repoId/tree/main');
      final allFiles = (listResp.data as List)
          .map((e) => e['path'] as String)
          .where(_isMlxFile)
          .toList();

      if (allFiles.isEmpty) {
        debugPrint('[MlxBackendProbe] No MLX files found in $repoId');
        if (mounted) setState(() => _status = 'No MLX files found in repo.');
        return;
      }

      final snapshotDir = await _modelSnapshotDir(repoId);
      await snapshotDir.create(recursive: true);

      for (var i = 0; i < allFiles.length; i++) {
        final filename = allFiles[i];
        final url = 'https://huggingface.co/$repoId/resolve/main/$filename';
        final destFile = File('${snapshotDir.path}/${filename.split('/').last}');

        debugPrint('[MlxBackendProbe] Downloading ${i + 1}/${allFiles.length}: $filename');
        if (mounted) {
          setState(() => _status =
              'Downloading (${i + 1}/${allFiles.length}): ${filename.split('/').last}');
        }

        await _dio.download(
          url,
          destFile.path,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() => _downloadProgress = received / total);
            }
          },
        );
      }

      debugPrint('[MlxBackendProbe] Download complete -> ${snapshotDir.path}');
      if (mounted) {
        setState(() {
          _modelPathController.text = snapshotDir.path;
          _status = 'Download complete ✓ → ${snapshotDir.path}';
          _downloadProgress = 1;
        });
      }
    } on DioException catch (e) {
      debugPrint('[MlxBackendProbe] Download error: $e');
      if (mounted) setState(() => _status = 'Download error: ${e.message}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _createSession() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _status = 'Creating session…';
      _output = '';
    });

    try {
      _session?.dispose();
      final profile = ModelProfile(
        id: 'debug-probe-t1-mlx',
        displayName: 'T1 MLX (debug probe)',
        format: ModelFormat.mlx,
        chatTemplateHint: ChatTemplateHint.gemma,
        localPath: _modelPathController.text.trim(),
      );
      final settings = InferenceSettings(
        systemPrompt: _systemPromptController.text.trim(),
        maxTokens: 256,
        samplingParams: const SamplingParams(topP: 0.95, temperature: 0.6),
      );
      _session = MlxBackend().createSession(profile, settings);
      debugPrint('[MlxBackendProbe] Session created for ${profile.localPath}');
      if (mounted) {
        setState(() => _status = 'Session created (model loads lazily on first generate)');
      }
    } catch (e, st) {
      debugPrint('[MlxBackendProbe] Error creating session: $e\n$st');
      if (mounted) setState(() => _status = 'Error creating session: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null || _isBusy) return;

    setState(() {
      _isBusy = true;
      _output = '';
      _status = 'Generating (first call also loads the model)…';
    });

    final sw = Stopwatch()..start();
    Duration? ttft;

    try {
      final stream = session.generate([
        ChatMessage(content: _promptController.text.trim(), isUser: true),
      ]);
      await for (final token in stream) {
        ttft ??= sw.elapsed;
        if (!mounted) break;
        setState(() => _output += token);
        _scrollToBottom();
      }
      sw.stop();
      debugPrint('[MlxBackendProbe] Done. TTFT=${ttft?.inMilliseconds}ms '
          'total=${sw.elapsedMilliseconds}ms output="$_output"');
      if (mounted) {
        setState(() {
          _status = 'Done ✓  TTFT: ${ttft?.inMilliseconds ?? '-'} ms  '
              'total: ${sw.elapsedMilliseconds} ms';
        });
      }
    } catch (e, st) {
      debugPrint('[MlxBackendProbe] Error generating: $e\n$st');
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _cancel() {
    _session?.cancel();
    setState(() => _status = 'Cancelled');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _session?.dispose();
    _repoController.dispose();
    _modelPathController.dispose();
    _systemPromptController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLX Backend Probe — task-B03 (temporary)'),
        backgroundColor: Colors.deepPurple.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: 'HuggingFace repo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _downloadModel,
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Download'),
                ),
              ],
            ),
            if (_isBusy && _downloadProgress > 0 && _downloadProgress < 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: _downloadProgress),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelPathController,
              decoration: const InputDecoration(
                labelText: 'Local MLX model directory',
                helperText: 'Filled automatically after Download, or set manually',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _systemPromptController,
              decoration: const InputDecoration(
                labelText: 'System prompt',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isBusy ? null : _createSession,
              child: const Text('Create MlxBackend session'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _promptController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: (_session != null && !_isBusy) ? _send : null,
                    style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
                    child: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isBusy ? _cancel : null,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Status: $_status', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Text(
                    _output.isEmpty ? '(waiting for tokens…)' : _output,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
