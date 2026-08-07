import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/data/services/local_model_catalog.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

class FoodReligionModel {
  const FoodReligionModel({
    required this.label,
    required this.path,
    required this.format,
  });

  final String label;
  final String path;
  final ModelFormat format;

  ModelProfile get profile => ModelProfile.fromLocalPath(path);
}

enum FoodReligionJudgmentFailure {
  modelUnavailable,
  modelLoad,
  generation,
  timeout,
  parse,
  missingFields,
  invalidVerdict,
  contentValidation,
  cancelled,
}

class FoodReligionJudgmentException implements Exception {
  const FoodReligionJudgmentException(this.failure);

  final FoodReligionJudgmentFailure failure;
}

typedef FoodReligionJudgmentTimerFactory =
    Timer Function(Duration duration, void Function() callback);

abstract class FoodReligionJudgmentService {
  Future<List<FoodReligionModel>> discoverModels();

  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  });

  void cancel();
  void dispose();
}

class OnDeviceFoodReligionJudgmentService
    implements FoodReligionJudgmentService {
  OnDeviceFoodReligionJudgmentService({
    LocalModelCatalog? catalog,
    BackendSelector? backendSelector,
    InferenceBackend Function(ModelProfile)? backendResolver,
    FoodReligionJudgmentTimerFactory? timerFactory,
    this.timeout = const Duration(seconds: 20),
  }) : _catalog = catalog ?? LocalModelCatalog(),
       _backendResolver =
           backendResolver ?? (backendSelector ?? BackendSelector()).select,
       _timerFactory = timerFactory ?? Timer.new;

  final LocalModelCatalog _catalog;
  final InferenceBackend Function(ModelProfile) _backendResolver;
  final FoodReligionJudgmentTimerFactory _timerFactory;
  final Duration timeout;
  GenerationController? _activeController;
  Completer<String>? _activeOperation;
  bool _isJudging = false;
  bool _isCancellationRequested = false;
  bool _isDisposed = false;

  @override
  Future<List<FoodReligionModel>> discoverModels() async {
    if (_isDisposed) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.cancelled,
      );
    }
    final entries = await _catalog.discover();
    final models = [
      for (final entry in entries)
        FoodReligionModel(
          label: entry.label,
          path: entry.path,
          format: ModelFormat.fromLocalPath(entry.path),
        ),
    ];
    models.sort((left, right) {
      final formatOrder = left.format.index.compareTo(right.format.index);
      if (formatOrder != 0) return formatOrder;
      final labelOrder = left.label.toLowerCase().compareTo(
        right.label.toLowerCase(),
      );
      return labelOrder != 0 ? labelOrder : left.path.compareTo(right.path);
    });
    return models;
  }

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) async {
    if (_isDisposed || _isJudging) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.cancelled,
      );
    }
    _isJudging = true;
    _isCancellationRequested = false;

    InferenceSession? session;
    StreamSubscription<GenerationEvent>? subscription;
    Timer? timer;
    try {
      if (!await _isAvailable(model)) {
        throw const FoodReligionJudgmentException(
          FoodReligionJudgmentFailure.modelUnavailable,
        );
      }
      if (_isCancellationRequested) {
        throw const FoodReligionJudgmentException(
          FoodReligionJudgmentFailure.cancelled,
        );
      }
      final profile = model.profile;
      late final InferenceBackend backend;
      try {
        backend = _backendResolver(profile);
        if (!backend.canHandle(profile)) {
          throw const FoodReligionJudgmentException(
            FoodReligionJudgmentFailure.modelLoad,
          );
        }
        session = backend.createSession(profile, _settings);
      } on FoodReligionJudgmentException {
        rethrow;
      } catch (_) {
        throw const FoodReligionJudgmentException(
          FoodReligionJudgmentFailure.modelLoad,
        );
      }
      final controller = GenerationController();
      _activeController = controller;
      final operation = Completer<String>();
      _activeOperation = operation;
      final output = StringBuffer();
      subscription = controller
          .run(session, [
            ChatMessage(
              content: _buildPrompt(stance: stance, defense: defense),
              isUser: true,
            ),
          ])
          .listen(
            (event) {
              switch (event) {
                case GenerationToken():
                  output.write(event.token);
                case GenerationDone():
                  if (!operation.isCompleted) {
                    operation.complete(output.toString());
                  }
                case GenerationError():
                  if (!operation.isCompleted) {
                    operation.completeError(
                      const FoodReligionJudgmentException(
                        FoodReligionJudgmentFailure.generation,
                      ),
                    );
                  }
              }
            },
            onError: (Object _, StackTrace __) {
              if (!operation.isCompleted) {
                operation.completeError(
                  const FoodReligionJudgmentException(
                    FoodReligionJudgmentFailure.generation,
                  ),
                );
              }
            },
            onDone: () {
              if (!operation.isCompleted) operation.complete(output.toString());
            },
            cancelOnError: true,
          );
      timer = _timerFactory(timeout, () {
        if (operation.isCompleted) return;
        controller.cancel();
        operation.completeError(
          const FoodReligionJudgmentException(
            FoodReligionJudgmentFailure.timeout,
          ),
        );
      });

      final raw = await operation.future;
      return _parseAndValidate(raw, stance: stance, defense: defense);
    } on FoodReligionJudgmentException {
      rethrow;
    } catch (_) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.generation,
      );
    } finally {
      timer?.cancel();
      final cancellation = subscription?.cancel();
      session?.dispose();
      await cancellation;
      _activeController = null;
      _activeOperation = null;
      _isJudging = false;
      _isCancellationRequested = false;
    }
  }

  static const _settings = InferenceSettings(
    maxTokens: 128,
    systemPrompt: '你是台灣食物宗教戰爭的安全 AI 鄉民評審。只輸出指定 JSON。',
    stopSequences: ['</s>', '<|eot_id|>', '<|im_end|>'],
  );

  Future<bool> _isAvailable(FoodReligionModel model) async {
    try {
      final type = await FileSystemEntity.type(model.path, followLinks: true);
      return switch (model.format) {
        ModelFormat.gguf => type == FileSystemEntityType.file,
        ModelFormat.mlx => type == FileSystemEntityType.directory,
      };
    } catch (_) {
      return false;
    }
  }

  String _buildPrompt({
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) => '''
你要根據玩家的實際辯護進行一次裁決。
飲食立場：${stance.label}
固定質疑：${stance.finalChallenge}
玩家原始辯護：${defense.text}

判決準則：
1. 明確支持該立場、正面回應質疑，且理由具體或有梗：「信仰堅定」。
2. 大致支持但理由薄弱、偏題或矛盾：「勉強護教」。
3. 明顯動搖、倒戈、否定該立場或無法支持：「叛教邊緣」。
明確承認對立立場更好或否定該立場時，不得判為「信仰堅定」。

安全 roast 必須逐字使用 verdict 對應文案：
- 信仰堅定：${FallbackJudgmentService.approvedRoastFor(stance, FoodReligionVerdict.steadfast)}
- 勉強護教：${FallbackJudgmentService.approvedRoastFor(stance, FoodReligionVerdict.reluctant)}
- 叛教邊緣：${FallbackJudgmentService.approvedRoastFor(stance, FoodReligionVerdict.wavering)}

安全護欄：
只吐槽食物、飲食立場或論點漏洞；不人身攻擊，不推測人格或智力，不攻擊地區、族群、文化或信仰。
不得重述或擴大玩家輸入中的攻擊性內容；不用髒話、歧視、仇恨、性暗示或暴力威脅。

只輸出一個 JSON object，且只能有兩個必填字串欄位：
{"verdict":"信仰堅定|勉強護教|叛教邊緣","roast":"一句 50 字內的正體中文食物梗"}
不得輸出 Markdown、前後說明、額外判決或技術資訊。
''';

  FoodReligionJudgment _parseAndValidate(
    String raw, {
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.parse,
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        !decoded.containsKey('verdict') ||
        !decoded.containsKey('roast') ||
        decoded['verdict'] is! String ||
        decoded['roast'] is! String) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.missingFields,
      );
    }
    final verdictLabel = decoded['verdict'] as String;
    final roast = decoded['roast'] as String;
    final verdict =
        FoodReligionVerdict.values
            .where((candidate) => candidate.label == verdictLabel)
            .firstOrNull;
    if (verdict == null) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.invalidVerdict,
      );
    }
    if (!_isSafeSingleSentence(roast) ||
        roast != FallbackJudgmentService.approvedRoastFor(stance, verdict)) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.contentValidation,
      );
    }
    if (verdict == FoodReligionVerdict.steadfast &&
        _isExplicitTurncoat(defense.text, stance)) {
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.contentValidation,
      );
    }
    return FoodReligionJudgment(verdict: verdict, roast: roast);
  }

  bool _isSafeSingleSentence(String roast) {
    final trimmed = roast.trim();
    if (trimmed != roast ||
        trimmed.isEmpty ||
        trimmed.characters.length > 50 ||
        trimmed.contains(RegExp(r'[\r\n`*_#<>]'))) {
      return false;
    }
    final endings = RegExp(r'[。！？!?]').allMatches(trimmed).toList();
    if (endings.length > 1 ||
        (endings.length == 1 && endings.single.end != trimmed.length)) {
      return false;
    }
    const blockedTerms = [
      '白痴',
      '智障',
      '廢物',
      '垃圾',
      '低能',
      '腦殘',
      '幹你',
      '去死',
      '殺了',
      '歧視',
      '性交',
      '模型',
      'JSON',
      'error',
      'exception',
    ];
    return !blockedTerms.any(
      (term) => trimmed.toLowerCase().contains(term.toLowerCase()),
    );
  }

  bool _isExplicitTurncoat(String defense, FoodFaith stance) {
    final normalized = defense.replaceAll(RegExp(r'\s+'), '');
    final ownLabel = RegExp.escape(
      stance.label.replaceFirst(RegExp(r'派$'), ''),
    );
    if (RegExp(
      '不支持|放棄|倒戈|我錯了|這立場(不好|難吃)|'
      '$ownLabel.*(不值得支持|不該支持|不想支持|無法支持|沒辦法支持|不再支持|拒絕支持|不好吃|難吃)|'
      '(討厭|不喜歡|不愛|拒吃).*$ownLabel',
    ).hasMatch(normalized)) {
      return true;
    }
    final opposingLabels = switch (stance) {
      FoodFaith.northernZongzi => const ['南部粽', '南粽'],
      FoodFaith.southernZongzi => const ['北部粽', '北粽'],
      FoodFaith.extraCilantro => const ['香菜退散', '不加香菜'],
      FoodFaith.noCilantro => const ['香菜加爆', '加香菜'],
      FoodFaith.sweetTofuPudding => const ['豆花配豆漿'],
      FoodFaith.soyMilkTofuPudding => const ['豆花配糖水'],
      FoodFaith.satayHotPot => const ['火鍋原湯'],
      FoodFaith.brothHotPot => const ['火鍋沾沙茶'],
      FoodFaith.fullSugarBubbleTea => const ['珍奶微糖'],
      FoodFaith.lessSugarBubbleTea => const ['珍奶全糖'],
      FoodFaith.saltedFries => const ['原味不加鹽'],
      FoodFaith.plainFries => const ['薯條加鹽'],
    };
    return opposingLabels.any((label) {
      final escapedLabel = RegExp.escape(label);
      return RegExp(
        '($escapedLabel.*(更好|比較好|才是|最好|贏))|'
        '((改|轉而|現在)?(支持|選|站)$escapedLabel)|'
        '((比較|更)?喜歡|偏愛)$escapedLabel',
      ).hasMatch(normalized);
    });
  }

  @override
  void cancel() {
    if (!_isJudging) return;
    _isCancellationRequested = true;
    _activeController?.cancel();
    final operation = _activeOperation;
    if (operation != null && !operation.isCompleted) {
      operation.completeError(
        const FoodReligionJudgmentException(
          FoodReligionJudgmentFailure.cancelled,
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    cancel();
  }
}
