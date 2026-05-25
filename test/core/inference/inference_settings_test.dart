import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';

void main() {
  group('InferenceSettings', () {
    test('defaults', () {
      const s = InferenceSettings();
      expect(s.samplingParams, equals(const SamplingParams()));
      expect(s.systemPrompt, isNull);
      expect(s.maxTokens, 1024);
      expect(s.stopSequences, isEmpty);
    });

    test('copyWith overrides fields', () {
      const s = InferenceSettings();
      final t = s.copyWith(maxTokens: 512, systemPrompt: 'You are helpful.');
      expect(t.maxTokens, 512);
      expect(t.systemPrompt, 'You are helpful.');
      expect(t.samplingParams, s.samplingParams);
      expect(t.stopSequences, s.stopSequences);
    });

    test('copyWith clearSystemPrompt removes it', () {
      const s = InferenceSettings(systemPrompt: 'old');
      final t = s.copyWith(clearSystemPrompt: true);
      expect(t.systemPrompt, isNull);
    });

    test('copyWith stopSequences', () {
      const s = InferenceSettings();
      final t = s.copyWith(stopSequences: ['<|end|>', '<|user|>']);
      expect(t.stopSequences, ['<|end|>', '<|user|>']);
    });

    test('equality considers all fields', () {
      const a = InferenceSettings(
        maxTokens: 256,
        systemPrompt: 'sys',
        stopSequences: ['</s>'],
      );
      const b = InferenceSettings(
        maxTokens: 256,
        systemPrompt: 'sys',
        stopSequences: ['</s>'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when stopSequences differ', () {
      const a = InferenceSettings(stopSequences: ['</s>']);
      const b = InferenceSettings(stopSequences: ['<|end|>']);
      expect(a, isNot(equals(b)));
    });

    test('inequality when maxTokens differ', () {
      const a = InferenceSettings(maxTokens: 128);
      const b = InferenceSettings(maxTokens: 512);
      expect(a, isNot(equals(b)));
    });
  });
}
