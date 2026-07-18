import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

/// Drives [BenchmarkViewModel] through a set of [PromptTier]s following the
/// standardized protocol (task-C02): each tier gets one cold sample (a
/// freshly opened session) followed by [warmRepeats] warm samples on that
/// same session, before closing it and moving to the next tier.
///
/// Cold-start semantics (2026-07-18 finding — both backends show a
/// session's first generation is measurably slower than its second,
/// suspected GPU/Metal kernel JIT warm-up; see construction.md task-B03):
/// - **app-cold**: the very first session opened right after a fresh app
///   launch. Only the first tier's first session, and only when
///   [appJustLaunched] is true, gets this label — the caller must have
///   force-quit and relaunched the app immediately before calling [runAll],
///   since this class cannot do that from within a running process.
/// - **session-cold**: a fresh session opened while the app process is
///   already warm (every other tier's first session, or the first tier's
///   first session when [appJustLaunched] is false).
/// - **session-warm**: a repeat generation on an already-open session.
///
/// These are recorded as separate [BenchmarkSample]s (distinct `label`s),
/// never averaged together — mixing them would hide the effect this
/// protocol exists to measure.
class BenchmarkProtocolRunner {
  final BenchmarkViewModel viewModel;

  BenchmarkProtocolRunner(this.viewModel);

  Future<void> runTier(
    String modelPath,
    PromptTier tier, {
    required int warmRepeats,
    required bool isFirstSessionThisLaunch,
  }) async {
    final coldLabel =
        isFirstSessionThisLaunch ? '${tier.label}-app-cold' : '${tier.label}-session-cold';
    await viewModel.openSessionAndRun(modelPath, tier.toMessages(), label: coldLabel);

    for (var i = 1; i <= warmRepeats; i++) {
      await viewModel.runOnOpenSession(tier.toMessages(), label: '${tier.label}-session-warm-$i');
    }
    viewModel.closeSession();
  }

  /// Runs every tier in [tiers] (default: [PromptTier.all]).
  ///
  /// [appJustLaunched] should be true only on the very first call after a
  /// fresh app launch — pass false (the default) for any run started while
  /// the app was already open, so "app-cold" is never mislabeled onto an
  /// already-warm process.
  Future<void> runAll(
    String modelPath, {
    List<PromptTier>? tiers,
    int warmRepeats = 2,
    bool appJustLaunched = false,
  }) async {
    final list = tiers ?? PromptTier.all;
    for (var i = 0; i < list.length; i++) {
      await runTier(
        modelPath,
        list[i],
        warmRepeats: warmRepeats,
        isFirstSessionThisLaunch: appJustLaunched && i == 0,
      );
    }
  }
}
