import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/config/recommended_models.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';

void main() {
  // ── ModelProfile defaults ─────────────────────────────────────────────────
  group('ModelProfile defaults', () {
    const p = ModelProfile(
      id: 'test/model-gguf',
      displayName: 'Test',
      format: ModelFormat.gguf,
    );

    test('hfRepoId defaults to id', () => expect(p.hfRepoId, 'test/model-gguf'));
    test('chatTemplateHint defaults to unknown', () => expect(p.chatTemplateHint, ChatTemplateHint.unknown));
    test('ctxLen defaults to 2048', () => expect(p.ctxLen, 2048));
    test('backendHint defaults to auto', () => expect(p.backendHint, BackendHint.auto));
    test('defaultSamplingParams defaults match SamplingParams()', () {
      expect(p.defaultSamplingParams, const SamplingParams());
    });
    test('localPath defaults to null', () => expect(p.localPath, isNull));
    test('useCases defaults to empty', () => expect(p.useCases, isEmpty));
  });

  // ── ModelProfile copyWith ─────────────────────────────────────────────────
  group('ModelProfile copyWith', () {
    const base = ModelProfile(
      id: 'a',
      displayName: 'A',
      format: ModelFormat.gguf,
      ctxLen: 2048,
    );

    test('overrides localPath', () {
      final p = base.copyWith(localPath: '/tmp/a.gguf');
      expect(p.localPath, '/tmp/a.gguf');
    });

    test('clearLocalPath removes localPath', () {
      final withPath = base.copyWith(localPath: '/tmp/a.gguf');
      final cleared = withPath.copyWith(clearLocalPath: true);
      expect(cleared.localPath, isNull);
    });

    test('preserves unspecified fields', () {
      final p = base.copyWith(ctxLen: 4096);
      expect(p.id, base.id);
      expect(p.format, base.format);
    });
  });

  // ── JSON round-trip ───────────────────────────────────────────────────────
  group('ModelProfile JSON round-trip', () {
    const profile = ModelProfile(
      id: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      displayName: 'Qwen 2.5 1.5B',
      format: ModelFormat.gguf,
      hfRepoId: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.qwen2,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 20, topP: 0.9, temperature: 0.7),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Multilingual',
      useCases: ['Chat', 'Multilingual'],
      badge: 'Versatile',
      localPath: '/models/qwen.gguf',
    );

    test('toJson preserves all fields', () {
      final j = profile.toJson();
      expect(j['id'], 'Qwen/Qwen2.5-1.5B-Instruct-GGUF');
      expect(j['format'], 'gguf');
      expect(j['chatTemplateHint'], 'qwen2');
      expect(j['ctxLen'], 4096);
      expect(j['backendHint'], 'llamaCpp');
      expect(j['recommendedQuantization'], 'Q4_K_M');
      expect(j['badge'], 'Versatile');
      expect(j['localPath'], '/models/qwen.gguf');
    });

    test('fromJson restores profile', () {
      final restored = ModelProfile.fromJson(profile.toJson());
      expect(restored.id, profile.id);
      expect(restored.format, profile.format);
      expect(restored.chatTemplateHint, profile.chatTemplateHint);
      expect(restored.ctxLen, profile.ctxLen);
      expect(restored.backendHint, profile.backendHint);
      expect(restored.recommendedQuantization, profile.recommendedQuantization);
      expect(restored.badge, profile.badge);
      expect(restored.localPath, profile.localPath);
      expect(restored.useCases, profile.useCases);
    });

    test('round-trip for MLX profile', () {
      const mlx = ModelProfile(
        id: 'mlx-community/Llama-3.2-1B-Instruct-4bit',
        displayName: 'Llama 1B MLX',
        format: ModelFormat.mlx,
        chatTemplateHint: ChatTemplateHint.llama3,
        backendHint: BackendHint.mlx,
        ctxLen: 4096,
      );
      final restored = ModelProfile.fromJson(mlx.toJson());
      expect(restored.format, ModelFormat.mlx);
      expect(restored.chatTemplateHint, ChatTemplateHint.llama3);
      expect(restored.backendHint, BackendHint.mlx);
      expect(restored.recommendedQuantization, isNull);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final minimal = ModelProfile.fromJson({
        'id': 'x',
        'displayName': 'X',
        'format': 'gguf',
        'hfRepoId': 'x',
      });
      expect(minimal.ctxLen, 2048);
      expect(minimal.backendHint, BackendHint.auto);
      expect(minimal.chatTemplateHint, ChatTemplateHint.unknown);
    });
  });

  // ── SamplingParams JSON ───────────────────────────────────────────────────
  group('SamplingParams JSON round-trip', () {
    test('toJson / fromJson', () {
      const sp = SamplingParams(topK: 20, topP: 0.8, temperature: 0.5, seed: 42);
      final restored = SamplingParams.fromJson(sp.toJson());
      expect(restored, sp);
    });
  });

  // ── RecommendedModels.profiles ────────────────────────────────────────────
  group('RecommendedModels.profiles', () {
    test('contains 7 entries', () {
      expect(RecommendedModels.profiles, hasLength(7));
    });

    test('first 6 are GGUF', () {
      final gguf = RecommendedModels.profiles
          .where((p) => p.format == ModelFormat.gguf)
          .toList();
      expect(gguf, hasLength(6));
    });

    test('contains one MLX profile', () {
      final mlx = RecommendedModels.profiles
          .where((p) => p.format == ModelFormat.mlx)
          .toList();
      expect(mlx, hasLength(1));
      expect(mlx.first.id, 'mlx-community/Llama-3.2-1B-Instruct-4bit');
    });

    test('MLX profile has correct fields', () {
      final mlx = RecommendedModels.profileById(
        'mlx-community/Llama-3.2-1B-Instruct-4bit',
      )!;
      expect(mlx.format, ModelFormat.mlx);
      expect(mlx.backendHint, BackendHint.mlx);
      expect(mlx.chatTemplateHint, ChatTemplateHint.llama3);
      expect(mlx.recommendedQuantization, isNull);
      expect(mlx.badge, 'MLX');
    });

    test('all GGUF profiles have recommendedQuantization set', () {
      for (final p in RecommendedModels.profiles
          .where((p) => p.format == ModelFormat.gguf)) {
        expect(p.recommendedQuantization, isNotNull,
            reason: '${p.id} missing recommendedQuantization');
      }
    });

    test('all profiles have valid chatTemplateHint', () {
      for (final p in RecommendedModels.profiles) {
        expect(ChatTemplateHint.values.contains(p.chatTemplateHint), isTrue);
      }
    });

    test('profileById returns null for unknown id', () {
      expect(RecommendedModels.profileById('no-such-model'), isNull);
    });

    test('profileById finds existing profile', () {
      final p = RecommendedModels.profileById('unsloth/gemma-3-270m-it-GGUF');
      expect(p, isNotNull);
      expect(p!.badge, 'Fastest');
    });

    test('Llama 3.2 3B has llama3 chat template hint', () {
      final p = RecommendedModels.profileById(
        'twinkle-ai/Llama-3.2-3B-F1-Reasoning-Instruct-GGUF',
      )!;
      expect(p.chatTemplateHint, ChatTemplateHint.llama3);
    });

    test('Gemma profiles have gemma chat template hint', () {
      for (final id in [
        'unsloth/gemma-3-270m-it-GGUF',
        'twinkle-ai/gemma-3-4B-T1-it-GGUF',
      ]) {
        expect(
          RecommendedModels.profileById(id)!.chatTemplateHint,
          ChatTemplateHint.gemma,
          reason: '$id should have gemma hint',
        );
      }
    });

    test('Llama profiles have llama3 chat template hint', () {
      for (final id in [
        'twinkle-ai/Llama-3.2-3B-F1-Reasoning-Instruct-GGUF',
        'unsloth/Llama-3.2-1B-Instruct-GGUF',
      ]) {
        expect(
          RecommendedModels.profileById(id)!.chatTemplateHint,
          ChatTemplateHint.llama3,
          reason: '$id should have llama3 hint',
        );
      }
    });
  });
}
