import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
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
import 'package:little_star_app/utils/logger.dart';

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

/// The slice of text generation this service needs: one cancellable token
/// stream per prompt. Declared here so the service depends on nothing above
/// it — a caller that wants richer generation (metrics, shared cancellation)
/// adapts its own runner into this interface.
abstract class FoodReligionTextGenerator {
  Stream<String> run(InferenceSession session, List<ChatMessage> messages);

  void cancel();
}

class _SessionTextGenerator implements FoodReligionTextGenerator {
  InferenceSession? _activeSession;

  @override
  Stream<String> run(InferenceSession session, List<ChatMessage> messages) {
    _activeSession = session;
    return session.generate(messages);
  }

  @override
  void cancel() {
    _activeSession?.cancel();
    _activeSession = null;
  }
}

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
    FallbackJudgmentService? fallbackJudgments,
    FoodReligionTextGenerator Function()? textGeneratorFactory,
    // The spec's 20 seconds was a first-version suggestion to be re-set from
    // device measurements (spec.md:236). On the target device class — mid-range
    // Android rather than a flagship — a 1B model takes 17-21 seconds, so 20
    // cut real judgments off at random. A slower judgment beats a fallback one.
    this.timeout = const Duration(seconds: 40),
  }) : _catalog = catalog ?? LocalModelCatalog(),
       _backendResolver =
           backendResolver ?? (backendSelector ?? BackendSelector()).select,
       _timerFactory = timerFactory ?? Timer.new,
       _fallbackJudgments = fallbackJudgments ?? FallbackJudgmentService(),
       _textGeneratorFactory =
           textGeneratorFactory ?? _SessionTextGenerator.new;

  final LocalModelCatalog _catalog;
  final InferenceBackend Function(ModelProfile) _backendResolver;
  final FoodReligionJudgmentTimerFactory _timerFactory;
  final FallbackJudgmentService _fallbackJudgments;
  final FoodReligionTextGenerator Function() _textGeneratorFactory;
  final Duration timeout;
  final Logger _log = Logger('FoodReligionJudgment');
  FoodReligionTextGenerator? _activeGenerator;
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
    StreamSubscription<String>? subscription;
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
      final generator = _textGeneratorFactory();
      _activeGenerator = generator;
      final operation = Completer<String>();
      _activeOperation = operation;
      final output = StringBuffer();
      subscription = generator
          .run(session, [
            ChatMessage(
              content: _buildPrompt(stance: stance, defense: defense),
              isUser: true,
            ),
          ])
          .listen(
            output.write,
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
        generator.cancel();
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
      _activeGenerator = null;
      _activeOperation = null;
      _isJudging = false;
      _isCancellationRequested = false;
    }
  }

  static const _settings = InferenceSettings(
    // One verdict plus a roast of at most [_maxRoastCharacters] characters.
    // Every token past that is time the player spends watching a spinner on a
    // slower phone; measured on a Pixel 8a it took a 1B model from just over
    // the timeout to comfortably inside it.
    maxTokens: 80,
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

安全護欄：
只吐槽食物、飲食立場或論點漏洞；不人身攻擊，不推測人格或智力，不攻擊地區、族群、文化或信仰。
不得重述或擴大玩家輸入中的攻擊性內容；不用髒話、歧視、仇恨、性暗示或暴力威脅。

只輸出一個 JSON object，且必須包含 "verdict" 與 "roast" 兩個必填字串欄位：
{"verdict":"信仰堅定|勉強護教|叛教邊緣","roast":"一句吐槽"}
roast 規則：1 到 30 個字、單行、純文字、正體中文，符合上面的安全護欄，
不得使用 Markdown 標記或網址，也不得逐字複製玩家辯護。
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
      _logRejection('parse', () => 'raw=${_quoted(raw)}');
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.parse,
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['verdict'] is! String ||
        decoded['roast'] is! String ||
        decoded.keys.any((key) => key != 'verdict' && key != 'roast')) {
      _logRejection('missingFields', () => 'raw=${_quoted(raw)}');
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.missingFields,
      );
    }
    final verdictLabel = decoded['verdict'] as String;
    final verdict =
        FoodReligionVerdict.values
            .where((candidate) => candidate.label == verdictLabel)
            .firstOrNull;
    if (verdict == null) {
      _logRejection('invalidVerdict', () => 'verdict=${_quoted(verdictLabel)}');
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.invalidVerdict,
      );
    }
    if (verdict == FoodReligionVerdict.steadfast &&
        _isExplicitTurncoat(defense.text, stance)) {
      _log.debug(
        'rejected: contentValidation | steadfast for a turned defence',
      );
      throw const FoodReligionJudgmentException(
        FoodReligionJudgmentFailure.contentValidation,
      );
    }
    return _judgmentWithValidatedRoast(
      decoded['roast'] as String,
      stance: stance,
      verdict: verdict,
      defense: defense,
    );
  }

  /// An unsafe roast discards the whole judgment, because a model that wrote
  /// one cannot be trusted with the verdict either. A merely malformed roast
  /// keeps the verdict and swaps in approved copy. Both are disclosed as
  /// fallbacks, so [FoodReligionJudgment.isFallback] means exactly "this roast
  /// did not come from the model".
  FoodReligionJudgment _judgmentWithValidatedRoast(
    String rawRoast, {
    required FoodFaith stance,
    required FoodReligionVerdict verdict,
    required FoodReligionDefense defense,
  }) {
    if (_isUnsafe(rawRoast)) {
      _logRejection('unsafeRoast', () => 'roast=${_quoted(rawRoast)}');
      return _fallbackJudgments.judge(stance);
    }
    if (!_hasValidRoastFormat(rawRoast, defense)) {
      _logRejection('roastFormat', () => 'roast=${_quoted(rawRoast)}');
      return FoodReligionJudgment(
        verdict: verdict,
        roast: FallbackJudgmentService.approvedRoastFor(stance, verdict),
        isFallback: true,
      );
    }
    return FoodReligionJudgment(verdict: verdict, roast: rawRoast.trim());
  }

  /// Why a judgment fell back. The class alone always ships, because it is
  /// the question a bug report has to answer. The model's own words are only
  /// quoted in debug builds: `Logger.minLevel` keeps DEBUG in release and the
  /// log-export dialog would carry them off the device, and a roast can quote
  /// the player's defence back — see [_copiesDefense].
  void _logRejection(String rule, String Function() quote) => _log.debugf(
    () => kDebugMode ? 'rejected: $rule | ${quote()}' : 'rejected: $rule',
  );

  static String _quoted(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.characters.length <= 120
        ? singleLine
        : '${singleLine.characters.take(120)}…';
  }

  static const _maxRoastCharacters = 30;

  /// Only a structural backstop: semantic attacks cannot be detected on device,
  /// so the prompt's safety rules remain the primary guard.
  static final _denyList = RegExp(
    '幹你|幹妳|他媽|媽的|去死|該死|王八蛋|混蛋|渾蛋|白痴|白癡|智障|低能|腦殘|沒腦|'
    '笨蛋|蠢貨|廢物|神經病|滾回去|滾出去|婊|賤|支那|番仔|做愛|上床|裸體|性行為|'
    '打死|揍你|殺了你|殺光|'
    r'\b(fuck|shit|bitch|idiot|stupid|moron|retard)\b',
    caseSensitive: false,
  );
  static final _markupOrLink = RegExp(
    r'[*_`#\[\]<>|~]|https?://|www\.|\S+\.(com|net|org|io)\b',
    caseSensitive: false,
  );
  static final _han = RegExp(r'[一-鿿]');
  static final _foreignScript = RegExp(r'[぀-ヿ가-힯Ѐ-ӿ]');

  /// Short Latin tokens such as CP or Q read as Chinese slang; a longer run
  /// means the model answered in another language.
  static final _latinWord = RegExp(r'[A-Za-z]{3,}');

  /// A sample of the simplified characters most likely to show up in a roast,
  /// not the whole simplified set: one hit is enough to reject the roast.
  static final _commonSimplifiedCharacters = RegExp(
    '[们这个发经说汤盘脑爱灵齿点种样对开关门问题实产业务东车马鸟鱼贝见风飞龙尽应图价书华亲讲论证识语读认为觉过还从战术传统营养]',
  );

  bool _isUnsafe(String roast) => _denyList.hasMatch(roast);

  bool _hasValidRoastFormat(String rawRoast, FoodReligionDefense defense) {
    if (rawRoast.contains('\n') || rawRoast.contains('\r')) return false;
    final roast = rawRoast.trim();
    final length = roast.characters.length;
    if (length == 0 || length > _maxRoastCharacters) return false;
    if (_markupOrLink.hasMatch(roast)) return false;
    if (!_han.hasMatch(roast) ||
        _foreignScript.hasMatch(roast) ||
        _latinWord.hasMatch(roast) ||
        _commonSimplifiedCharacters.hasMatch(roast)) {
      return false;
    }
    return !_copiesDefense(roast, defense);
  }

  /// Only a roast made entirely of the player's own words counts as copying;
  /// quoting part of the defence inside a longer roast is fair game.
  bool _copiesDefense(String roast, FoodReligionDefense defense) {
    final normalizedRoast = _withoutWhitespace(roast);
    final normalizedDefense = _withoutWhitespace(defense.text);
    return normalizedRoast.contains(normalizedDefense) ||
        normalizedDefense.contains(normalizedRoast);
  }

  static String _withoutWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), '');

  static final _clauseSeparator = RegExp(r'[，。！？；：、,.!?;:]');
  static final _turnTrigger = RegExp(
    '放棄|倒戈|不再支持|拒絕支持|不想支持|無法支持|沒辦法支持|不支持|討厭|不喜歡|不愛|拒吃',
  );

  /// A defence only turns when the player says so about the drawn stance, so
  /// each denial is read clause by clause: the clause needs a first-person
  /// subject before the trigger, the drawn stance right after it, and nothing
  /// negating or quoting the trigger just before it. Bare 「不支持」「放棄」
  /// 「倒戈」 stay legal — 「不支持香菜的人才奇怪」 defends 香菜加爆派.
  bool _isExplicitTurncoat(String defense, FoodFaith stance) {
    final ownLabel = RegExp.escape(
      stance.label.replaceFirst(RegExp(r'派$'), ''),
    );
    final clauses = _withoutWhitespace(
      defense,
    ).split(_clauseSeparator).where((clause) => clause.isNotEmpty);
    return clauses.any(
      (clause) =>
          _deniesOwnStance(clause, ownLabel) ||
          _turnsToOwnStanceOpposite(clause, stance),
    );
  }

  bool _deniesOwnStance(String clause, String ownLabel) {
    // Statements about the stance itself need no speaker, e.g. 北部粽不好吃.
    if (RegExp(
      '$ownLabel.{0,4}(不值得支持|不該支持|不想支持|無法支持|沒辦法支持|不再支持|拒絕支持|不好吃|難吃)|'
      '這個?立場(不好|難吃)',
    ).hasMatch(clause)) {
      return true;
    }
    final subject = clause.indexOf('我');
    if (subject < 0) return false;
    return _turnTrigger.allMatches(clause).any((match) {
      if (match.start < subject) return false;
      if (_isNegatedOrQuoted(clause, match.start)) return false;
      return RegExp('^(這個?立場|$ownLabel)').hasMatch(clause.substring(match.end));
    });
  }

  static final _negation = RegExp('不|沒|別|莫|勿|絕|誰|怎|哪|才');

  bool _isNegatedOrQuoted(String clause, int triggerStart) {
    final windowStart = triggerStart - 4;
    return _negation.hasMatch(
      clause.substring(windowStart < 0 ? 0 : windowStart, triggerStart),
    );
  }

  bool _turnsToOwnStanceOpposite(String clause, FoodFaith stance) {
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
      final turn = RegExp(
        '($escapedLabel.{0,4}(更好|比較好|才是|最好|贏))|'
        '((改|轉而|現在)?(支持|選|站)$escapedLabel)|'
        '((比較|更)?喜歡|偏愛)$escapedLabel',
      );
      return turn
          .allMatches(clause)
          .any((match) => !_isNegatedOrQuoted(clause, match.start));
    });
  }

  @override
  void cancel() {
    if (!_isJudging) return;
    _isCancellationRequested = true;
    _activeGenerator?.cancel();
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
