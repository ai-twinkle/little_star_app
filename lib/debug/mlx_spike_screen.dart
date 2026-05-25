import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:little_star_app/core/engine/mlx/mlx_channel.dart';
import 'package:path_provider/path_provider.dart';

/// Step 3 measurement screen for task-001 MLX spike.
/// Supports:
///   1. Downloading an MLX model from HuggingFace Hub
///   2. Loading the model via MlxChannel
///   3. Running a fixed prompt and measuring token throughput
class MlxSpikeScreen extends StatefulWidget {
  const MlxSpikeScreen({super.key});

  @override
  State<MlxSpikeScreen> createState() => _MlxSpikeScreenState();
}

class _MlxSpikeScreenState extends State<MlxSpikeScreen> {
  final _channel = MlxChannel();
  final _scrollController = ScrollController();

  // Default target model for this spike
  static const _defaultRepo = 'mlx-community/gemma-3-270m-it-4bit';
  static const _testPrompt = 'Why is the sky blue?';

  String _repoId = _defaultRepo;
  String _modelPath = '';
  String _status = 'idle';
  String _output = '';
  double? _lastTps;
  bool _isBusy = false;
  double _downloadProgress = 0;

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _modelSnapshotDir(String repoId) async {
    final base = await getApplicationSupportDirectory();
    final slug = repoId.replaceAll('/', '_');
    return Directory('${base.path}/Models/$slug');
  }

  // MLX model file extensions to download
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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _autoDetectModel() async {
    final dir = await _modelSnapshotDir(_repoId);
    if (await dir.exists() && dir.listSync().isNotEmpty) {
      setState(() => _modelPath = dir.path);
    } else {
      final base = await getApplicationSupportDirectory();
      setState(() => _modelPath = '${base.path}/Models');
    }
  }

  Future<void> _downloadModel() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _status = 'Fetching file list…';
      _downloadProgress = 0;
    });

    try {
      // 1. List all files in the HF repo
      final listResp = await _dio.get(
        'https://huggingface.co/api/models/$_repoId/tree/main',
      );
      final allFiles =
          (listResp.data as List)
              .map((e) => e['path'] as String)
              .where(_isMlxFile)
              .toList();

      if (allFiles.isEmpty) {
        setState(() => _status = 'No MLX files found in repo.');
        return;
      }

      final snapshotDir = await _modelSnapshotDir(_repoId);
      await snapshotDir.create(recursive: true);

      // 2. Download each file
      for (var i = 0; i < allFiles.length; i++) {
        final filename = allFiles[i];
        final url = 'https://huggingface.co/$_repoId/resolve/main/$filename';
        final destFile = File(
          '${snapshotDir.path}/${filename.split('/').last}',
        );

        setState(
          () =>
              _status =
                  'Downloading (${i + 1}/${allFiles.length}): ${filename.split('/').last}',
        );

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

      setState(() {
        _modelPath = snapshotDir.path;
        _status = 'Download complete ✓ → ${snapshotDir.path}';
        _downloadProgress = 1;
      });
    } on DioException catch (e) {
      setState(() => _status = 'Download error: ${e.message}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _loadModel() async {
    if (_isBusy) return;
    setState(() {
      _status = 'Loading model…';
      _output = '';
      _lastTps = null;
    });
    try {
      await _channel.loadModel(_modelPath);
      setState(() => _status = 'Model loaded ✓');
    } on Exception catch (e) {
      setState(() => _status = 'Load error: $e');
    }
  }

  Future<void> _runInference() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _output = '';
      _lastTps = null;
      _status = 'Generating…';
    });

    try {
      final messages = [MlxChatMessage(role: 'user', content: _testPrompt)];
      await for (final event in _channel.generate(messages)) {
        if (!mounted) break;
        setState(() {
          if (!event.isDone) _output += event.token;
          if (event.tokensPerSecond != null) _lastTps = event.tokensPerSecond;
          if (event.isDone) _status = 'Done ✓';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    } on Exception catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _cancel() async {
    await _channel.cancel();
    setState(() {
      _isBusy = false;
      _status = 'Cancelled';
    });
  }

  @override
  void initState() {
    super.initState();
    _autoDetectModel();
  }

  @override
  void dispose() {
    _channel.dispose();
    _scrollController.dispose();
    _dio.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLX Spike — Step 3 量測'),
        backgroundColor: Colors.deepPurple.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Repo ID + download
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _repoId,
                    decoration: const InputDecoration(
                      labelText: 'HuggingFace repo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _repoId = v),
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
            const SizedBox(height: 10),
            // Model path + load + run
            TextFormField(
              key: ValueKey(_modelPath),
              initialValue: _modelPath,
              decoration: const InputDecoration(
                labelText: 'Local snapshot path',
                helperText: 'Directory with config.json + safetensors',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _modelPath = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isBusy ? null : _loadModel,
                    child: const Text('Load'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _isBusy ? null : _runInference,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text('Run Inference'),
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
            _StatusBar(status: _status, tps: _lastTps),
            const SizedBox(height: 10),
            // Prompt
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Prompt: $_testPrompt',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Output:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
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
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
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

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.tps});
  final String status;
  final double? tps;

  @override
  Widget build(BuildContext context) {
    final tpsText = tps != null ? '  |  ${tps!.toStringAsFixed(1)} tok/s' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Status: $status$tpsText',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }
}
