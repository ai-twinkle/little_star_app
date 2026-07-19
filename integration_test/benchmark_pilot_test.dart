// task-C04 pilot run — drives the C01-C03 benchmark harness for real on a
// connected device, against the real T1 weights already downloaded via the
// app (GGUF: Documents/Models/, MLX: Application Support/Models/mlx/).
//
// Run with:
//   fvm flutter test integration_test/benchmark_pilot_test.dart -d <device>
//
// Purpose (task-C04): surface methodology problems before the full matrix
// (task-C05) — this is deliberately not the final protocol (short prompt,
// small maxTokens) so it runs quickly; results print to stdout for
// inspection, nothing here is meant to be cited as final benchmark numbers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const pilotSettings = InferenceSettings(
    samplingParams: SamplingParams(temperature: 0.6, topP: 0.95),
    maxTokens: 64, // small on purpose — this is a plumbing check, not C05
  );
  const prompt = '請用一句話介紹台灣夜市文化。';

  void logSample(String tag, BenchmarkSample s) {
    final g = s.generation;
    // ignore: avoid_print
    print('[$tag] label=${s.label} format=${s.format.name} '
        'loadMs=${s.modelLoadDuration.inMilliseconds} '
        'ttftMs=${g.ttft?.inMilliseconds} '
        'decodeTps=${g.tokensPerSecond?.toStringAsFixed(2)} '
        'prefillTps=${g.prefillTokensPerSecond?.toStringAsFixed(2)} '
        'promptTokens=${g.promptTokenCount} '
        'peakMemMB=${s.peakMemoryBytes != null ? (s.peakMemoryBytes! / 1e6).toStringAsFixed(1) : null} '
        'thermal=${s.thermalStateBefore.name}->${s.thermalStateAfter.name} '
        'battery=${s.batteryLevelBefore}->${s.batteryLevelAfter} '
        'text="${s.generatedText.replaceAll('\n', ' ')}"');
  }

  testWidgets('pilot: GGUF cold + warm on real T1 weights', (tester) async {
    final docs = await getApplicationDocumentsDirectory();
    final ggufPath = '${docs.path}/Models/twinkle-ai-gemma-3-4b-t1-it-q4_k_m.gguf';
    expect(File(ggufPath).existsSync(), isTrue,
        reason: 'Expected T1 GGUF already downloaded via the app at $ggufPath');

    final viewModel = BenchmarkViewModel(settings: pilotSettings);
    await viewModel.openSessionAndRunPrompt(ggufPath, prompt, label: 'pilot-gguf-session-cold');
    expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    await viewModel.runOnOpenSessionPrompt(prompt, label: 'pilot-gguf-session-warm');
    expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    viewModel.closeSession();

    expect(viewModel.samples, hasLength(2));
    for (final s in viewModel.samples) {
      logSample('GGUF', s);
      expect(s.generation.tokenCount, greaterThan(0));
    }

    final csv = await viewModel.exportCsv();
    final json = await viewModel.exportJson();
    // ignore: avoid_print
    print('[GGUF] csv=${csv.path} (${await csv.length()} bytes)');
    // ignore: avoid_print
    print('[GGUF] json=${json.path} (${await json.length()} bytes)');
    expect(await csv.length(), greaterThan(0));
    expect(await json.length(), greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('pilot: MLX cold + warm on real T1 weights', (tester) async {
    final support = await getApplicationSupportDirectory();
    final mlxPath = '${support.path}/Models/mlx/Bbson_gemma-3-4B-T1-it-MLX-4bit';
    expect(Directory(mlxPath).existsSync(), isTrue,
        reason: 'Expected T1 MLX already downloaded via the app at $mlxPath');

    final viewModel = BenchmarkViewModel(settings: pilotSettings);
    await viewModel.openSessionAndRunPrompt(mlxPath, prompt, label: 'pilot-mlx-session-cold');
    expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    await viewModel.runOnOpenSessionPrompt(prompt, label: 'pilot-mlx-session-warm');
    expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    viewModel.closeSession();

    expect(viewModel.samples, hasLength(2));
    for (final s in viewModel.samples) {
      logSample('MLX', s);
      expect(s.generation.tokenCount, greaterThan(0));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
