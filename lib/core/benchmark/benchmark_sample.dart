import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/inference/generation_metrics.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';

/// One completed benchmark run: load time + the existing TTFT/decode-tps/
/// prefill metrics from [GenerationController], plus device telemetry
/// (memory, thermal, battery) sampled around it.
///
/// Reused unchanged by the standardized protocol (task-C02), sustained-load
/// (task-C03) and full-matrix (task-C05) runners — only [label] and how many
/// samples get collected differs between them.
class BenchmarkSample {
  final DateTime timestamp;

  /// Which backend/model format produced this sample. Reuses [ModelFormat]
  /// rather than a free-form string so it can only ever be one of the two
  /// backends the app actually has.
  final ModelFormat format;

  final String modelId;

  /// Free-form context tag — e.g. prompt tier + cold/warm state
  /// ("L512-session-cold"). Filled in by the protocol runner (task-C02);
  /// null for one-off ad-hoc runs.
  final String? label;

  /// Wall-clock time spent in [InferenceBackend.createSession].
  ///
  /// For llama.cpp this is a real load cost (model mmap + createContext +
  /// createSampler, all done eagerly in the constructor — see
  /// `LlamaCppSession`). For MLX this is near-zero: `MlxSession` loads
  /// lazily on the first `generate()` call, so MLX's true load cost is
  /// folded into that first call's [GenerationMetrics.ttft] instead. This
  /// is a real architectural difference between the two backends, not a
  /// measurement gap — see construction.md task-B03 (MlxSession lazy load)
  /// and the 2026-07-18 cold-start findings.
  final Duration modelLoadDuration;

  final GenerationMetrics generation;

  final String generatedText;

  /// Peak `dart:io` `ProcessInfo.currentRss` sample observed during this run
  /// (whole-process RSS, matching how this cycle's on-device memory
  /// measurements were taken manually — see task-A02/A03).
  final int? peakMemoryBytes;

  final ThermalStatus thermalStateBefore;
  final ThermalStatus thermalStateAfter;

  /// Battery percentage (0-100) before/after, or null if unavailable.
  final int? batteryLevelBefore;
  final int? batteryLevelAfter;

  const BenchmarkSample({
    required this.timestamp,
    required this.format,
    required this.modelId,
    required this.modelLoadDuration,
    required this.generation,
    required this.generatedText,
    required this.thermalStateBefore,
    required this.thermalStateAfter,
    this.label,
    this.peakMemoryBytes,
    this.batteryLevelBefore,
    this.batteryLevelAfter,
  });
}
