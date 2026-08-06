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
// "C05 overnight matrix" (below) is the unattended alternative to the above:
// all 8 iPhone combos in one run, gated by a thermalState-nominal wait
// between combos (task-C04/C05 both found decode speed and cold TTFT track
// thermalState — the earlier iPhone run had no such gate and thermalState
// climbed to `serious` by combo 2 and never recovered), and one CSV
// checkpointed after every combo so a mid-run failure doesn't lose the
// whole night. This is the one to run before bed.
//
// "C05 timeboxed matrix" is the bounded alternative for a session where
// running all night isn't an option: same per-combo protocol and checkpoint
// behavior, but capped to kTimeboxBudget wall-clock minutes and combos are
// interleaved by tier (GGUF/MLX per tier, not all-GGUF-then-all-MLX) so a
// run that gets cut short still covers both backends across whatever tiers
// it reached.
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
import 'package:little_star_app/core/benchmark/benchmark_export.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
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

// "C05 timeboxed matrix" budget — tune between 60-90 min depending on how
// much awake time is actually available tonight. Checked before each combo
// starts (not mid-combo), so real wall-clock time can run a bit over this by
// up to one combo's duration.
const Duration kTimeboxBudget = Duration(minutes: 75);
// Shorter than the overnight run's 20 min: with only kTimeboxBudget total,
// a full-length cooldown wait could eat most of the budget by itself.
const Duration kTimeboxNominalWaitTimeout = Duration(minutes: 5);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void logSample(String tag, BenchmarkSample s) {
    final g = s.generation;
    // ignore: avoid_print
    print(
      '[$tag] label=${s.label} '
      'loadMs=${s.modelLoadDuration.inMilliseconds} '
      'ttftMs=${g.ttft?.inMilliseconds} '
      'decodeTps=${g.tokensPerSecond?.toStringAsFixed(2)} '
      'prefillTps=${g.prefillTokensPerSecond?.toStringAsFixed(2)} '
      'promptTokens=${g.promptTokenCount} '
      'genTokens=${g.tokenCount} '
      'peakMemMB=${s.peakMemoryBytes != null ? (s.peakMemoryBytes! / 1e6).toStringAsFixed(1) : null} '
      'thermal=${s.thermalStateBefore.name}->${s.thermalStateAfter.name} '
      'battery=${s.batteryLevelBefore}->${s.batteryLevelAfter}',
    );
  }

  Future<void> runCombo(
    String tag,
    String modelPath,
    PromptTier tier, {
    int coldSessions = kColdSessionsPerCombo,
    int warmRepeats = kWarmRepeatsPerSession,
  }) async {
    expect(
      modelPath.endsWith('.gguf')
          ? File(modelPath).existsSync()
          : Directory(modelPath).existsSync(),
      isTrue,
      reason: 'Expected model already downloaded via the app at $modelPath',
    );

    final viewModel = BenchmarkViewModel();
    for (var i = 1; i <= coldSessions; i++) {
      await viewModel.runProtocol(
        modelPath,
        tiers: [tier],
        warmRepeats: warmRepeats,
      );
      expect(viewModel.lastError, isNull, reason: viewModel.lastError ?? '');
    }

    for (final s in viewModel.samples) {
      logSample(tag, s);
    }
    final csv = await viewModel.exportCsv();
    // ignore: avoid_print
    print(
      '[$tag] n=${viewModel.samples.length} csv=${csv.path} (${await csv.length()} bytes)',
    );
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

  /// Polls thermalState until it's back to nominal, or gives up after
  /// [timeout] and continues anyway — this is what lets the overnight
  /// matrix run unattended instead of stalling forever on a device that
  /// never fully cools (see task-C05's iPhone results: 8 combos back-to-back
  /// with no cooldown drove thermalState from nominal to serious and it
  /// never recovered).
  Future<void> waitForNominal(
    BenchmarkViewModel vm, {
    Duration timeout = const Duration(minutes: 20),
    Duration pollInterval = const Duration(seconds: 20),
  }) async {
    final start = DateTime.now();
    while (true) {
      final status = await vm.checkPreflight();
      final elapsed = DateTime.now().difference(start);
      if (status.isThermalNominal) {
        // ignore: avoid_print
        print('[cooldown] thermalState=nominal after ${elapsed.inSeconds}s');
        return;
      }
      if (elapsed >= timeout) {
        // ignore: avoid_print
        print(
          '[cooldown] timed out after ${elapsed.inSeconds}s, still '
          'thermalState=${status.thermalState.name} — continuing anyway',
        );
        return;
      }
      // ignore: avoid_print
      print(
        '[cooldown] thermalState=${status.thermalState.name}, waiting '
        '(${elapsed.inSeconds}s elapsed, battery=${status.batteryLevel}%)',
      );
      await Future.delayed(pollInterval);
    }
  }

  /// Overwrites a fixed-path CSV with every sample recorded so far, AND
  /// prints the full CSV text to stdout. Called after each combo (not just
  /// once at the end) so an unattended run that dies partway — device
  /// reboot, ANR, USB drop — still leaves the completed combos recoverable.
  ///
  /// The stdout dump is the important part: `flutter test` on a physical
  /// iOS device uninstalls the app (and its data container) once the test
  /// finishes, so the on-device CSV file becomes permanently unreachable via
  /// devicectl the moment the run ends — the checkpoint file on disk is not
  /// actually retrievable after the fact. As long as this run's terminal
  /// output is captured (`fvm flutter test ... | tee run.log`), the CSV
  /// survives in the log regardless of what happens to the container.
  Future<void> writeCheckpointCsv(BenchmarkViewModel vm, String path) async {
    final content = benchmarkSamplesToCsv(vm.samples);
    final file = File(path);
    await file.writeAsString(content);
    // ignore: avoid_print
    print(
      '[checkpoint] ${vm.samples.length} samples -> $path (${content.length} bytes)',
    );
    // ignore: avoid_print
    print('=== CSV_DUMP_BEGIN ===');
    // ignore: avoid_print
    print(content);
    // ignore: avoid_print
    print('=== CSV_DUMP_END ===');
  }

  // The overnight matrix — one shared session's worth of state (one
  // BenchmarkViewModel, one CSV), all 8 iPhone combos (GGUF+MLX x 4 tiers),
  // full protocol (kColdSessionsPerCombo cold + kWarmRepeatsPerSession warm
  // each), a nominal-thermal gate between combos, and a checkpoint write
  // after each combo. MLX only — not meaningful on Android (no MLX there).
  //
  // Run this one right before bed, plugged in, auto-lock off, and watch the
  // first combo complete before walking away:
  //   fvm flutter test integration_test/c05_matrix_test.dart \
  //     --plain-name "C05 overnight matrix" -d <device>
  testWidgets('C05 overnight matrix', (tester) async {
    final viewModel = BenchmarkViewModel();
    final gguf = await ggufPath();
    final mlx = await mlxPath();
    final docs = await getApplicationDocumentsDirectory();
    final csvPath = '${docs.path}/c05_overnight_matrix.csv';

    final combos = <(String, String, PromptTier)>[
      ('GGUF', gguf, PromptTier.l128),
      ('GGUF', gguf, PromptTier.l512),
      ('GGUF', gguf, PromptTier.l1024),
      ('GGUF', gguf, PromptTier.l2048),
      ('MLX', mlx, PromptTier.l128),
      ('MLX', mlx, PromptTier.l512),
      ('MLX', mlx, PromptTier.l1024),
      ('MLX', mlx, PromptTier.l2048),
    ];

    for (var ci = 0; ci < combos.length; ci++) {
      final (backend, path, tier) = combos[ci];
      // ignore: avoid_print
      print('=== combo ${ci + 1}/${combos.length}: $backend ${tier.label} ===');

      if (ci > 0) await waitForNominal(viewModel);

      final beforeCount = viewModel.samples.length;
      for (var i = 1; i <= kColdSessionsPerCombo; i++) {
        try {
          await viewModel.runProtocol(
            path,
            tiers: [tier],
            warmRepeats: kWarmRepeatsPerSession,
          );
          if (viewModel.lastError != null) {
            // ignore: avoid_print
            print(
              '[warn] $backend ${tier.label} session $i: ${viewModel.lastError}',
            );
          }
        } catch (e) {
          // ignore: avoid_print
          print(
            '[error] $backend ${tier.label} session $i threw: $e — continuing',
          );
        }
      }

      for (final s in viewModel.samples.skip(beforeCount)) {
        logSample('$backend-${tier.label}', s);
      }
      await writeCheckpointCsv(viewModel, csvPath);
    }

    // ignore: avoid_print
    print(
      '=== overnight matrix complete: ${viewModel.samples.length} samples, csv=$csvPath ===',
    );
  }, timeout: const Timeout(Duration(hours: 10)));

  // Bounded alternative to "C05 overnight matrix" — same per-combo protocol
  // and checkpointing, but stops once kTimeboxBudget wall-clock minutes have
  // elapsed instead of running unattended for hours. Combos are interleaved
  // by tier (GGUF then MLX at each tier, ascending) rather than all-GGUF-
  // then-all-MLX, so a run that only gets through the first few combos still
  // has both backends represented instead of only ever finishing GGUF.
  //
  // Run this for "just run a bit tonight, watch it, stop worrying about the
  // full matrix":
  //   fvm flutter test integration_test/c05_matrix_test.dart \
  //     --plain-name "C05 timeboxed matrix" -d <device>
  testWidgets('C05 timeboxed matrix', (tester) async {
    final viewModel = BenchmarkViewModel();
    final gguf = await ggufPath();
    final mlx = await mlxPath();
    final docs = await getApplicationDocumentsDirectory();
    final csvPath = '${docs.path}/c05_timeboxed_matrix.csv';
    final budgetStart = DateTime.now();

    final combos = <(String, String, PromptTier)>[
      ('GGUF', gguf, PromptTier.l128),
      ('MLX', mlx, PromptTier.l128),
      ('GGUF', gguf, PromptTier.l512),
      ('MLX', mlx, PromptTier.l512),
      ('GGUF', gguf, PromptTier.l1024),
      ('MLX', mlx, PromptTier.l1024),
      ('GGUF', gguf, PromptTier.l2048),
      ('MLX', mlx, PromptTier.l2048),
    ];

    for (var ci = 0; ci < combos.length; ci++) {
      final elapsedSoFar = DateTime.now().difference(budgetStart);
      if (elapsedSoFar >= kTimeboxBudget) {
        // ignore: avoid_print
        print(
          '[timebox] budget (${kTimeboxBudget.inMinutes}min) exhausted '
          'after ${elapsedSoFar.inMinutes}min, stopping before combo '
          '${ci + 1}/${combos.length}',
        );
        break;
      }

      final (backend, path, tier) = combos[ci];
      // ignore: avoid_print
      print(
        '=== combo ${ci + 1}/${combos.length}: $backend ${tier.label} '
        '(${elapsedSoFar.inMinutes}/${kTimeboxBudget.inMinutes}min used) ===',
      );

      if (ci > 0) {
        await waitForNominal(viewModel, timeout: kTimeboxNominalWaitTimeout);
      }

      final beforeCount = viewModel.samples.length;
      for (var i = 1; i <= kColdSessionsPerCombo; i++) {
        try {
          await viewModel.runProtocol(
            path,
            tiers: [tier],
            warmRepeats: kWarmRepeatsPerSession,
          );
          if (viewModel.lastError != null) {
            // ignore: avoid_print
            print(
              '[warn] $backend ${tier.label} session $i: ${viewModel.lastError}',
            );
          }
        } catch (e) {
          // ignore: avoid_print
          print(
            '[error] $backend ${tier.label} session $i threw: $e — continuing',
          );
        }
      }

      for (final s in viewModel.samples.skip(beforeCount)) {
        logSample('$backend-${tier.label}', s);
      }
      await writeCheckpointCsv(viewModel, csvPath);
    }

    final totalElapsed = DateTime.now().difference(budgetStart);
    // ignore: avoid_print
    print(
      '=== timeboxed matrix complete: ${viewModel.samples.length} samples, '
      '${totalElapsed.inMinutes}min elapsed, csv=$csvPath ===',
    );
  }, timeout: const Timeout(Duration(hours: 3)));

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
    await runCombo(
      'Android-GGUF-L128',
      await ggufPath(),
      PromptTier.l128,
      coldSessions: kAndroidColdSessionsPerCombo,
      warmRepeats: kAndroidWarmRepeatsPerSession,
    );
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L512', (tester) async {
    await runCombo(
      'Android-GGUF-L512',
      await ggufPath(),
      PromptTier.l512,
      coldSessions: kAndroidColdSessionsPerCombo,
      warmRepeats: kAndroidWarmRepeatsPerSession,
    );
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L1024', (tester) async {
    await runCombo(
      'Android-GGUF-L1024',
      await ggufPath(),
      PromptTier.l1024,
      coldSessions: kAndroidColdSessionsPerCombo,
      warmRepeats: kAndroidWarmRepeatsPerSession,
    );
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('C05 Android GGUF L2048', (tester) async {
    await runCombo(
      'Android-GGUF-L2048',
      await ggufPath(),
      PromptTier.l2048,
      coldSessions: kAndroidColdSessionsPerCombo,
      warmRepeats: kAndroidWarmRepeatsPerSession,
    );
  }, timeout: const Timeout(Duration(minutes: 25)));
}
