import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';

void main() {
  group('SamplingParams', () {
    test('defaults', () {
      const p = SamplingParams();
      expect(p.topK, 40);
      expect(p.topP, 0.95);
      expect(p.temperature, 0.8);
      expect(p.seed, -1);
    });

    test('copyWith overrides fields', () {
      const p = SamplingParams();
      final q = p.copyWith(temperature: 0.0, seed: 42);
      expect(q.temperature, 0.0);
      expect(q.seed, 42);
      expect(q.topK, p.topK);
      expect(q.topP, p.topP);
    });

    test('copyWith with no args returns equal value', () {
      const p = SamplingParams(topK: 20, topP: 0.9, temperature: 0.5, seed: 7);
      expect(p.copyWith(), equals(p));
    });

    test('equality', () {
      const a = SamplingParams(topK: 10, topP: 0.8, temperature: 0.4, seed: 0);
      const b = SamplingParams(topK: 10, topP: 0.8, temperature: 0.4, seed: 0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when any field differs', () {
      const base = SamplingParams();
      expect(base, isNot(equals(base.copyWith(topK: 1))));
      expect(base, isNot(equals(base.copyWith(topP: 0.5))));
      expect(base, isNot(equals(base.copyWith(temperature: 0.0))));
      expect(base, isNot(equals(base.copyWith(seed: 0))));
    });
  });
}
