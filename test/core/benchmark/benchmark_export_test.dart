import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/benchmark/benchmark_export.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/device_telemetry.g.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

BenchmarkSample _sample({String? label, String generatedText = 'hello'}) => BenchmarkSample(
      timestamp: DateTime.utc(2026, 7, 19, 12, 0, 0),
      format: ModelFormat.gguf,
      modelId: 'model-1',
      label: label,
      modelLoadDuration: const Duration(milliseconds: 250),
      generation: const GenerationMetrics(
        tokenCount: 256,
        stopReason: StopReason.completed,
        ttft: Duration(milliseconds: 158),
        tokensPerSecond: 22.84,
        promptTokenCount: 14,
        prefillTokensPerSecond: 2642.51,
      ),
      generatedText: generatedText,
      peakMemoryBytes: 920000000,
      thermalStateBefore: ThermalStatus.nominal,
      thermalStateAfter: ThermalStatus.fair,
      batteryLevelBefore: 90,
      batteryLevelAfter: 88,
    );

void main() {
  group('benchmarkSamplesToCsv', () {
    test('emits a header row and one data row per sample', () {
      final csv = benchmarkSamplesToCsv([_sample()]);
      final lines = const LineSplitter().convert(csv.trim());

      expect(lines, hasLength(2));
      expect(lines.first, benchmarkCsvColumns.join(','));
      expect(lines[1], contains('gguf'));
      expect(lines[1], contains('model-1'));
      expect(lines[1], contains('158'));
      expect(lines[1], contains('22.84'));
    });

    test('quotes fields containing commas', () {
      final csv = benchmarkSamplesToCsv([_sample(label: 'L512, cold')]);
      expect(csv, contains('"L512, cold"'));
    });

    test('escapes embedded quotes by doubling them', () {
      final csv = benchmarkSamplesToCsv([_sample(generatedText: 'he said "hi"')]);
      expect(csv, contains('"he said ""hi"""'));
    });

    test('empty sample list still emits just the header', () {
      final csv = benchmarkSamplesToCsv([]);
      expect(csv.trim(), benchmarkCsvColumns.join(','));
    });
  });

  group('benchmarkSamplesToJson', () {
    test('round-trips key fields', () {
      final json = benchmarkSamplesToJson([_sample(label: 'L128-cold')]);
      final decoded = jsonDecode(json) as List<dynamic>;

      expect(decoded, hasLength(1));
      final row = decoded.first as Map<String, dynamic>;
      expect(row['format'], 'gguf');
      expect(row['modelId'], 'model-1');
      expect(row['label'], 'L128-cold');
      expect(row['ttftMs'], 158);
      expect(row['decodeTokensPerSecond'], 22.84);
      expect(row['promptTokenCount'], 14);
      expect(row['stopReason'], 'completed');
      expect(row['thermalStateBefore'], 'nominal');
      expect(row['thermalStateAfter'], 'fair');
    });

    test('null label survives as JSON null, not the string "null"', () {
      final json = benchmarkSamplesToJson([_sample()]);
      final row = (jsonDecode(json) as List<dynamic>).first as Map<String, dynamic>;
      expect(row['label'], isNull);
    });
  });
}
