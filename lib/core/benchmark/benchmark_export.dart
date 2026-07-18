import 'dart:convert';

import 'package:little_star_app/core/benchmark/benchmark_sample.dart';

/// Column order for [benchmarkSamplesToCsv] — also documents the schema.
const List<String> benchmarkCsvColumns = [
  'timestamp',
  'format',
  'modelId',
  'label',
  'modelLoadMs',
  'ttftMs',
  'decodeTokensPerSecond',
  'prefillTokensPerSecond',
  'promptTokenCount',
  'tokenCount',
  'stopReason',
  'peakMemoryBytes',
  'thermalStateBefore',
  'thermalStateAfter',
  'batteryLevelBefore',
  'batteryLevelAfter',
  'generatedText',
];

/// Serializes [samples] to RFC4127-style CSV (header row + one row per
/// sample), for both backends alike — task-C01.
String benchmarkSamplesToCsv(List<BenchmarkSample> samples) {
  final buffer = StringBuffer()..writeln(benchmarkCsvColumns.map(_csvField).join(','));
  for (final s in samples) {
    buffer.writeln(_rowFor(s).map(_csvField).join(','));
  }
  return buffer.toString();
}

/// Serializes [samples] to a JSON array of objects — task-C01.
String benchmarkSamplesToJson(List<BenchmarkSample> samples) {
  final list = samples.map((s) {
    final row = _rowFor(s);
    return {for (var i = 0; i < benchmarkCsvColumns.length; i++) benchmarkCsvColumns[i]: row[i]};
  }).toList();
  return const JsonEncoder.withIndent('  ').convert(list);
}

List<Object?> _rowFor(BenchmarkSample s) => [
      s.timestamp.toIso8601String(),
      s.format.name,
      s.modelId,
      s.label,
      s.modelLoadDuration.inMilliseconds,
      s.generation.ttft?.inMilliseconds,
      s.generation.tokensPerSecond,
      s.generation.prefillTokensPerSecond,
      s.generation.promptTokenCount,
      s.generation.tokenCount,
      s.generation.stopReason.name,
      s.peakMemoryBytes,
      s.thermalStateBefore.name,
      s.thermalStateAfter.name,
      s.batteryLevelBefore,
      s.batteryLevelAfter,
      s.generatedText,
    ];

String _csvField(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
