// task-C05 — full benchmark matrix (iPhone + Pixel 8a).
//
// Runs the real standardized protocol (kBenchmarkDefaultSettings: temp 0.6,
// topP 0.95, maxTokens 512) against the real T1 weights already on-device,
// for both backends across all 4 prompt tiers. Each iPhone combo gets 3
// independent session-cold samples (fresh session each time — task-C04's
// pilot found cold-start TTFT correlates with thermalState and varies
// run-to-run, so a single cold sample isn't representative) plus 3 warm
// repeats per session. Android (GGUF only — MLX is Apple Silicon only) uses
// a reduced 1 cold + 2 warm: a single generation on Pixel 8a can take 30s-70s+
// (see docs/benchmark/2026-07-19-c05-android-results.md), so the full protocol
// isn't tractable there.
//
// Split into one testWidgets block per (backend, tier) combo so each can be
// invoked individually and stays comfortably inside a single test-runner
// invocation's time budget:
//   fvm flutter test integration_test/c05_matrix_test.dart \
//     --plain-name "C05 GGUF L128" -d <device>
//
// Android notes (see the results doc's "執行障礙" section for the full story):
// re-run `flutter install --debug` + `adb shell appops set <pkg>
// MANAGE_EXTERNAL_STORAGE allow` before each invocation (flutter test's own
// reinstall resets the grant), and expect an intermittent ANR on cold launch
// (~30-50% of runs) that a retry usually clears.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
import 'package:little_star_app/core/benchmark/protocol_runner.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

const int kColdSessionsPerCombo = 3;
const int kWarmRepeatsPerSession = 3;

// Pixel 8a turned out ~15-20x slower per generation than iPhone 17 Pro (each
// generateStream call took 2.5-3+ minutes even at L128, vs seconds on iPhone —
// consistent with task-A02's unexplained "CPU only ~33% used" observation).
// The full protocol (12 generations/tier) would take 30+ min per tier; reduced
// to keep the Android side tractable in one session. Real finding, not a shortcut
// to hide — documented in the results doc.
const int kAndroidColdSessionsPerCombo = 1;
const int kAndroidWarmRepeatsPerSession = 2;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void logSample(String tag, BenchmarkSample s) {
    final g = s.generation;
    // ignore: avoid_print
    print('[$tag] label=${s.label} '
        'loadMs=${s.modelLoadDuration.inMilliseconds} '
        'ttftMs=${g.ttft?.inMilliseconds} '
        'decodeTps=${g.tokensPerSecond?.toStringAsFixed(2)} '
        'prefillTps=${g.prefillTokensPerSecond?.toStringAsFixed(2)} '
        'promptTokens=${g.promptTokenCount} '
        'genTokens=${g.tokenCount} '
        'peakMemMB=${s.peakMemoryBytes != null ? (s.peakMemoryBytes! / 1e6).toStringAsFixed(1) : null} '
        'thermal=${s.thermalStateBefore.name}->${s.thermalStateAfter.name} '
        'battery=${s.batteryLevelBefore}->${s.batteryLevelAfter}');
  }

  Future<void> runCombo(
    String tag,
    String modelPath,
    PromptTier tier, {
    int coldSessions = kColdSessionsPerCombo,
    int warmRepeats = kWarmRepeatsPerSession,
  }) async {
    expect(
      modelPath.endsWith('.gguf') ? File(modelPath).existsSync() : Directory(modelPath).existsSync(),
      isTrue,
      reason: 'Expected model already downloaded via the app at $modelPath',
    );

    final viewModel = BenchmarkViewModel();
    final runner = BenchmarkProtocolRunner(viewModel);
    for (var i = 1; i <= coldSessions; i++) {
      await runner.runTier(
        modelPath,
        tier,
        warmRepeats: warmRepeats,
        isFirstSessionThisLaunch: false,
      );
      expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    }

    for (final s in viewModel.samples) {
      logSample(tag, s);
    }
    final csv = await viewModel.exportCsv();
    // ignore: avoid_print
    print('[$tag] n=${viewModel.samples.length} csv=${csv.path} (${await csv.length()} bytes)');
    expect(viewModel.samples, hasLength(coldSessions * (1 + warmRepeats)));
  }

  Future<String> ggufPath() async {
    // Android: fixed shared Downloads path (AndroidDirectoryService.getModelsDirectory()),
    // not app-sandboxed like iOS — survives app reinstall, and the on-device T1 file (from
    // task-A03) doesn't carry the "twinkle-ai-" prefix the iOS download does.
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/LittleStar/models/gemma-3-4b-t1-it-q4_k_m.gguf';
    }
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/Models/twinkle-ai-gemma-3-4b-t1-it-q4_k_m.gguf';
  }

  Future<String> mlxPath() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/Models/mlx/Bbson_gemma-3-4B-T1-it-MLX-4bit';
  }

  testWidgets('C05 GGUF L128', (tester) async {
    await runCombo('GGUF-L128', await ggufPath(), PromptTier.l128);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 GGUF L512', (tester) async {
    await runCombo('GGUF-L512', await ggufPath(), PromptTier.l512);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 GGUF L1024', (tester) async {
    await runCombo('GGUF-L1024', await ggufPath(), PromptTier.l1024);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 GGUF L2048', (tester) async {
    await runCombo('GGUF-L2048', await ggufPath(), PromptTier.l2048);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 MLX L128', (tester) async {
    await runCombo('MLX-L128', await mlxPath(), PromptTier.l128);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 MLX L512', (tester) async {
    await runCombo('MLX-L512', await mlxPath(), PromptTier.l512);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 MLX L1024', (tester) async {
    await runCombo('MLX-L1024', await mlxPath(), PromptTier.l1024);
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('C05 MLX L2048', (tester) async {
    await runCombo('MLX-L2048', await mlxPath(), PromptTier.l2048);
  }, timeout: const Timeout(Duration(minutes: 9)));

  // Android (Pixel 8a): reduced sample count, see kAndroidColdSessionsPerCombo doc
  // comment. No MLX — Apple Silicon only.
  testWidgets('C05 Android GGUF L128', (tester) async {
    await runCombo('Android-GGUF-L128', await ggufPath(), PromptTier.l128,
        coldSessions: kAndroidColdSessionsPerCombo, warmRepeats: kAndroidWarmRepeatsPerSession);
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L512', (tester) async {
    await runCombo('Android-GGUF-L512', await ggufPath(), PromptTier.l512,
        coldSessions: kAndroidColdSessionsPerCombo, warmRepeats: kAndroidWarmRepeatsPerSession);
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L1024', (tester) async {
    await runCombo('Android-GGUF-L1024', await ggufPath(), PromptTier.l1024,
        coldSessions: kAndroidColdSessionsPerCombo, warmRepeats: kAndroidWarmRepeatsPerSession);
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L2048', (tester) async {
    await runCombo('Android-GGUF-L2048', await ggufPath(), PromptTier.l2048,
        coldSessions: kAndroidColdSessionsPerCombo, warmRepeats: kAndroidWarmRepeatsPerSession);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
