import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/data/services/local_model_catalog.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/models/chat_message.dart';

void main() {
  late Directory root;
  late Directory ggufRoot;
  late Directory mlxRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('food_judgment_test');
    ggufRoot = Directory('${root.path}/gguf')..createSync();
    mlxRoot = Directory('${root.path}/mlx')..createSync();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('discovery is stable with GGUF before MLX', () async {
    File('${ggufRoot.path}/z.gguf').writeAsStringSync('model');
    File('${ggufRoot.path}/a.gguf').writeAsStringSync('model');
    Directory('${mlxRoot.path}/b-mlx').createSync();
    Directory('${mlxRoot.path}/a-mlx').createSync();
    final service = OnDeviceFoodReligionJudgmentService(
      catalog: LocalModelCatalog.fixed(ggufRoot: ggufRoot, mlxRoot: mlxRoot),
    );

    final models = await service.discoverModels();

    expect(models.map((model) => model.label), [
      'GGUF · a.gguf',
      'GGUF · z.gguf',
      'MLX · a-mlx',
      'MLX · b-mlx',
    ]);
  });

  final stanceCases = [
    (
      stance: FoodFaith.northernZongzi,
      opposingDefense: '其實南部粽比較好',
      steadfastRoast: '油飯只是外表，粽葉才是北粽的戰袍！',
    ),
    (
      stance: FoodFaith.southernZongzi,
      opposingDefense: '我改支持北部粽',
      steadfastRoast: '水煮不是退讓，是南粽糯米的內功修煉！',
    ),
    (
      stance: FoodFaith.extraCilantro,
      opposingDefense: '我改支持香菜退散',
      steadfastRoast: '這把香菜撒得夠高，評審席都綠了！',
    ),
    (
      stance: FoodFaith.noCilantro,
      opposingDefense: '我比較喜歡香菜加爆',
      steadfastRoast: '防香菜裝備完整，連一片葉子都過不了！',
    ),
    (
      stance: FoodFaith.sweetTofuPudding,
      opposingDefense: '我改支持豆花配豆漿',
      steadfastRoast: '糖水接住豆花，甜得很有道理！',
    ),
    (
      stance: FoodFaith.soyMilkTofuPudding,
      opposingDefense: '我比較喜歡豆花配糖水',
      steadfastRoast: '豆香疊豆香，這套組合有自己的節奏！',
    ),
    (
      stance: FoodFaith.satayHotPot,
      opposingDefense: '我改支持火鍋原湯',
      steadfastRoast: '沙茶不是遮味，是火鍋的加速器！',
    ),
    (
      stance: FoodFaith.brothHotPot,
      opposingDefense: '我比較喜歡火鍋沾沙茶',
      steadfastRoast: '原湯敢單挑，這鍋底氣很足！',
    ),
    (
      stance: FoodFaith.fullSugarBubbleTea,
      opposingDefense: '我改支持珍奶微糖',
      steadfastRoast: '全糖就是完整火力，珍珠都點頭了！',
    ),
    (
      stance: FoodFaith.lessSugarBubbleTea,
      opposingDefense: '我比較喜歡珍奶全糖',
      steadfastRoast: '微糖留住茶香，也留住了立場！',
    ),
    (
      stance: FoodFaith.saltedFries,
      opposingDefense: '我改支持原味不加鹽',
      steadfastRoast: '這撮鹽把薯條的靈魂叫醒了！',
    ),
    (
      stance: FoodFaith.plainFries,
      opposingDefense: '我比較喜歡薯條加鹽',
      steadfastRoast: '原味敢直接上桌，馬鈴薯本人很有底氣！',
    ),
  ];

  final approvedJudgments = [
    (FoodReligionVerdict.steadfast, '油飯只是外表，粽葉才是北粽的戰袍！'),
    (FoodReligionVerdict.reluctant, '這理由有拌到油，還沒包進粽葉。'),
    (FoodReligionVerdict.wavering, '北粽都站穩了，你的論點還在油飯上打滑。'),
  ];
  for (final (verdict, roast) in approvedJudgments) {
    test(
      'accepts ${verdict.label} and sends complete judgment context',
      () async {
        final modelFile = File('${ggufRoot.path}/judge.gguf')
          ..writeAsStringSync('model');
        final session = _FakeSession([
          '{"verdict":"${verdict.label}",',
          '"roast":"$roast"}',
        ]);
        final backend = _FakeBackend(session);
        final service = OnDeviceFoodReligionJudgmentService(
          backendResolver: (_) => backend,
        );
        final defense = FoodReligionDefense.validate('  粽葉香氣無法取代  ').defense!;

        final result = await service.judge(
          model: FoodReligionModel(
            label: 'GGUF · judge.gguf',
            path: modelFile.path,
            format: ModelFormat.gguf,
          ),
          stance: FoodFaith.northernZongzi,
          defense: defense,
        );

        expect(result.verdict, verdict);
        expect(result.isFallback, isFalse);
        expect(session.generateCalls, 1);
        final prompt = session.messages.single.content;
        expect(prompt, contains('北部粽派'));
        expect(prompt, contains('北部粽不就是包在粽葉裡的油飯嗎？'));
        expect(prompt, contains('粽葉香氣無法取代'));
        expect(prompt, contains('信仰堅定'));
        expect(prompt, contains('不得重述或擴大'));
        expect(session.disposeCalls, 1);
      },
    );
  }

  test('keeps the roast the model wrote when it passes validation', () async {
    final modelFile = File('${ggufRoot.path}/custom-roast.gguf')
      ..writeAsStringSync('model');
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver:
          (_) => _FakeBackend(
            _FakeSession(const [
              '{"verdict":"信仰堅定","roast":"火鍋的靈魂在湯底，沙茶只是調味師！"}',
            ]),
          ),
    );

    final result = await service.judge(
      model: FoodReligionModel(
        label: 'custom roast',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.satayHotPot,
      defense: FoodReligionDefense.validate('沙茶讓每一口都更香').defense!,
    );

    expect(result.isFallback, isFalse);
    expect(result.verdict, FoodReligionVerdict.steadfast);
    expect(result.roast, '火鍋的靈魂在湯底，沙茶只是調味師！');
  });

  test('arms the measured generation budget by default', () async {
    final modelFile = File('${ggufRoot.path}/budget-timer.gguf')
      ..writeAsStringSync('model');
    final durations = <Duration>[];
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver:
          (_) => _FakeBackend(
            _FakeSession(const ['{"verdict":"勉強護教","roast":"油飯很努力，論點還在追。"}']),
          ),
      timerFactory: (duration, callback) {
        durations.add(duration);
        return _ManualTimer(callback);
      },
    );

    await service.judge(
      model: FoodReligionModel(
        label: 'budget timer',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );

    // Measured on the target device class (Pixel 8a): a 1B model needs
    // 17-21 seconds, so the original 20-second budget cut real judgments off.
    expect(durations.single, const Duration(seconds: 40));
  });

  test('bounds the token budget to what one judgment needs', () async {
    final modelFile = File('${ggufRoot.path}/budget.gguf')
      ..writeAsStringSync('model');
    final backend = _FakeBackend(
      _FakeSession(const ['{"verdict":"勉強護教","roast":"油飯很努力，論點還在追。"}']),
    );
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => backend,
    );

    await service.judge(
      model: FoodReligionModel(
        label: 'budget',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );

    // A verdict plus a roast of at most 30 characters; anything beyond that is
    // budget the player waits through on slower phones before the timeout.
    expect(backend.settings?.maxTokens, lessThanOrEqualTo(80));
  });

  test('asks the model for both a verdict and a roast', () async {
    final modelFile = File('${ggufRoot.path}/prompt.gguf')
      ..writeAsStringSync('model');
    final session = _FakeSession(const [
      '{"verdict":"勉強護教","roast":"油飯很努力，論點還在追。"}',
    ]);
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => _FakeBackend(session),
    );

    await service.judge(
      model: FoodReligionModel(
        label: 'prompt',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );

    final prompt = session.messages.single.content;
    expect(prompt, contains('"roast"'));
    expect(prompt, contains('30'));
    expect(prompt, contains('單行'));
    expect(prompt, contains('正體中文'));
    expect(prompt, isNot(contains('只能有一個')));
  });

  test(
    'keeps the model verdict and swaps roasts that break the format',
    () async {
      final invalidRoasts = {
        'too long': '粽' * 31,
        'markdown': '**北粽最強**',
        'link': '看看 https://example.com 就懂北粽',
        'multiline': '北粽最強\\n真的很強',
        'blank': '   ',
        'simplified': '这个理由还不够浓',
        'kana': '北粽はおいしい',
        'latin': '北粽 is objectively the best',
        'verbatim copy': '北粽最好吃',
        'quotes only the defense': '北粽最',
      };

      var index = 0;
      for (final entry in invalidRoasts.entries) {
        final modelFile = File('${ggufRoot.path}/format-${index++}.gguf')
          ..writeAsStringSync('model');
        final service = OnDeviceFoodReligionJudgmentService(
          backendResolver:
              (_) => _FakeBackend(
                _FakeSession(['{"verdict":"勉強護教","roast":"${entry.value}"}']),
              ),
        );

        final result = await service.judge(
          model: FoodReligionModel(
            label: entry.key,
            path: modelFile.path,
            format: ModelFormat.gguf,
          ),
          stance: FoodFaith.northernZongzi,
          defense: FoodReligionDefense.validate('北粽最好吃').defense!,
        );

        expect(
          result.verdict,
          FoodReligionVerdict.reluctant,
          reason: entry.key,
        );
        expect(result.roast, '這理由有拌到油，還沒包進粽葉。', reason: entry.key);
        expect(result.isFallback, isTrue, reason: entry.key);
      }
    },
  );

  test('accepts a roast that sits on the length boundary', () async {
    final modelFile = File('${ggufRoot.path}/boundary.gguf')
      ..writeAsStringSync('model');
    final roast = '粽' * 30;
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver:
          (_) => _FakeBackend(
            _FakeSession(['{"verdict":"勉強護教","roast":"$roast"}']),
          ),
    );

    final result = await service.judge(
      model: FoodReligionModel(
        label: 'boundary',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );

    expect(result.roast, roast);
    expect(result.isFallback, isFalse);
  });

  test(
    'rejects malformed, missing, illegal, unexpected, and turncoat outputs',
    () async {
      final invalidOutputs = [
        ('not json', FoodReligionJudgmentFailure.parse),
        ('{"roast":"好吃！"}', FoodReligionJudgmentFailure.missingFields),
        (
          '{"verdict":"滿分","roast":"好吃！"}',
          FoodReligionJudgmentFailure.invalidVerdict,
        ),
        (
          '{"verdict":"勉強護教","extra":"好吃"}',
          FoodReligionJudgmentFailure.missingFields,
        ),
        ('{"verdict":"勉強護教"}', FoodReligionJudgmentFailure.missingFields),
        (
          '{"verdict":"勉強護教","roast":7}',
          FoodReligionJudgmentFailure.missingFields,
        ),
        (
          '{"verdict":"信仰堅定","roast":"立場穩固！"}',
          FoodReligionJudgmentFailure.contentValidation,
        ),
      ];

      for (var index = 0; index < invalidOutputs.length; index++) {
        final modelFile = File('${ggufRoot.path}/judge-$index.gguf')
          ..writeAsStringSync('model');
        final service = OnDeviceFoodReligionJudgmentService(
          backendResolver:
              (_) => _FakeBackend(_FakeSession([invalidOutputs[index].$1])),
        );
        final defense =
            FoodReligionDefense.validate(
              index == invalidOutputs.length - 1 ? '其實南部粽比較好' : '北粽最好吃',
            ).defense!;

        expect(
          () => service.judge(
            model: FoodReligionModel(
              label: 'judge',
              path: modelFile.path,
              format: ModelFormat.gguf,
            ),
            stance: FoodFaith.northernZongzi,
            defense: defense,
          ),
          throwsA(_failure(invalidOutputs[index].$2)),
        );
      }
    },
  );

  test('discards the whole judgment when the roast is unsafe', () async {
    final cases = [
      ('南粽支持者都是王八蛋', '別把南粽支持者叫王八蛋！'),
      ('不認同北粽的人滾回去', '叫別人滾回去不是食物論點！'),
      ('你是笨蛋', '別當笨蛋，拿食物說話！'),
      ('你根本沒腦', '這種沒腦筋的支持法只配退場！'),
    ];

    for (var index = 0; index < cases.length; index++) {
      final modelFile = File('${ggufRoot.path}/unsafe-reflection-$index.gguf')
        ..writeAsStringSync('model');
      final service = OnDeviceFoodReligionJudgmentService(
        backendResolver:
            (_) => _FakeBackend(
              _FakeSession(['{"verdict":"勉強護教","roast":"${cases[index].$2}"}']),
            ),
        fallbackJudgments: FallbackJudgmentService(random: _FixedRandom(2)),
      );

      final result = await service.judge(
        model: FoodReligionModel(
          label: 'unsafe reflection',
          path: modelFile.path,
          format: ModelFormat.gguf,
        ),
        stance: FoodFaith.northernZongzi,
        defense: FoodReligionDefense.validate(cases[index].$1).defense!,
      );

      expect(result.verdict, FoodReligionVerdict.wavering);
      expect(result.roast, '北粽都站穩了，你的論點還在油飯上打滑。');
      expect(result.isFallback, isTrue);
      expect(result.roast, isNot(contains(cases[index].$2)));
    }
  });

  final loyalDefenses = [
    (stance: FoodFaith.extraCilantro, defense: '不支持香菜的人才奇怪'),
    (stance: FoodFaith.northernZongzi, defense: '我絕不放棄北部粽'),
    (stance: FoodFaith.northernZongzi, defense: '說我錯了的人沒吃過北部粽'),
    (stance: FoodFaith.northernZongzi, defense: '香菜派才會倒戈，北粽永遠不倒'),
    (stance: FoodFaith.northernZongzi, defense: '不支持北部粽的人才奇怪'),
    (stance: FoodFaith.northernZongzi, defense: '我永遠不會放棄北部粽'),
    (stance: FoodFaith.northernZongzi, defense: '沒有人不支持北部粽'),
    (stance: FoodFaith.northernZongzi, defense: '誰說我討厭北部粽，我最愛北部粽'),
    (stance: FoodFaith.southernZongzi, defense: '我才不會改支持北部粽'),
  ];
  for (final loyal in loyalDefenses) {
    test('keeps 信仰堅定 for the loyal defense: ${loyal.defense}', () async {
      final modelFile = File(
        '${ggufRoot.path}/loyal-${loyalDefenses.indexOf(loyal)}.gguf',
      )..writeAsStringSync('model');
      final service = OnDeviceFoodReligionJudgmentService(
        backendResolver:
            (_) => _FakeBackend(
              _FakeSession(const ['{"verdict":"信仰堅定","roast":"這個立場守得比粽繩還牢！"}']),
            ),
      );

      final result = await service.judge(
        model: FoodReligionModel(
          label: 'loyal',
          path: modelFile.path,
          format: ModelFormat.gguf,
        ),
        stance: loyal.stance,
        defense: FoodReligionDefense.validate(loyal.defense).defense!,
      );

      expect(result.verdict, FoodReligionVerdict.steadfast);
      expect(result.roast, '這個立場守得比粽繩還牢！');
      expect(result.isFallback, isFalse);
    });
  }

  test(
    'rejects steadfast judgments after switching to the opposing stance',
    () async {
      for (var index = 0; index < stanceCases.length; index++) {
        final stanceCase = stanceCases[index];
        final modelFile = File('${ggufRoot.path}/turncoat-$index.gguf')
          ..writeAsStringSync('model');
        final service = OnDeviceFoodReligionJudgmentService(
          backendResolver:
              (_) => _FakeBackend(
                _FakeSession([
                  '{"verdict":"信仰堅定","roast":"${stanceCase.steadfastRoast}"}',
                ]),
              ),
        );

        await expectLater(
          service.judge(
            model: FoodReligionModel(
              label: 'turncoat',
              path: modelFile.path,
              format: ModelFormat.gguf,
            ),
            stance: stanceCase.stance,
            defense:
                FoodReligionDefense.validate(
                  stanceCase.opposingDefense,
                ).defense!,
          ),
          throwsA(isA<FoodReligionJudgmentException>()),
          reason: stanceCase.opposingDefense,
        );
      }
    },
  );

  for (final denial in [
    '北部粽根本不值得支持',
    '北部粽不好吃',
    '我討厭北部粽',
    '我放棄北部粽了',
    '我不支持北部粽',
  ]) {
    test('rejects steadfast judgment for explicit denial: $denial', () async {
      final modelFile = File('${ggufRoot.path}/denial.gguf')
        ..writeAsStringSync('model');
      final service = OnDeviceFoodReligionJudgmentService(
        backendResolver:
            (_) => _FakeBackend(
              _FakeSession(const [
                '{"verdict":"信仰堅定","roast":"油飯只是外表，粽葉才是北粽的戰袍！"}',
              ]),
            ),
      );

      await expectLater(
        service.judge(
          model: FoodReligionModel(
            label: 'denial',
            path: modelFile.path,
            format: ModelFormat.gguf,
          ),
          stance: FoodFaith.northernZongzi,
          defense: FoodReligionDefense.validate(denial).defense!,
        ),
        throwsA(isA<FoodReligionJudgmentException>()),
      );
    });
  }

  test(
    'timeout cancels and disposes a generation that completes late',
    () async {
      final modelFile = File('${ggufRoot.path}/slow.gguf')
        ..writeAsStringSync('model');
      final session = _FakeSession(const [], neverComplete: true);
      final service = OnDeviceFoodReligionJudgmentService(
        backendResolver: (_) => _FakeBackend(session),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.judge(
          model: FoodReligionModel(
            label: 'slow',
            path: modelFile.path,
            format: ModelFormat.gguf,
          ),
          stance: FoodFaith.northernZongzi,
          defense: FoodReligionDefense.validate('北粽最好吃').defense!,
        ),
        throwsA(isA<FoodReligionJudgmentException>()),
      );
      expect(session.cancelCalls, 1);
      expect(session.disposeCalls, 1);
    },
  );

  test('cancellation completes once and disposes the active session', () async {
    final modelFile = File('${ggufRoot.path}/cancel.gguf')
      ..writeAsStringSync('model');
    final session = _FakeSession(const [], neverComplete: true);
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => _FakeBackend(session),
    );

    final judgment = service.judge(
      model: FoodReligionModel(
        label: 'cancel',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );
    final expectation = expectLater(
      judgment,
      throwsA(_failure(FoodReligionJudgmentFailure.cancelled)),
    );
    while (session.generateCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    service.cancel();
    await expectation;

    expect(session.cancelCalls, 1);
    expect(session.disposeCalls, 1);
  });

  test('immediate cancellation prevents inference from starting', () async {
    final modelFile = File('${ggufRoot.path}/cancel-before-load.gguf')
      ..writeAsStringSync('model');
    var resolverCalls = 0;
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) {
        resolverCalls++;
        return _FakeBackend(
          _FakeSession(const [
            '{"verdict":"信仰堅定","roast":"油飯只是外表，粽葉才是北粽的戰袍！"}',
          ]),
        );
      },
    );

    final judgment = service.judge(
      model: FoodReligionModel(
        label: 'cancel before load',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );
    service.cancel();

    await expectLater(
      judgment,
      throwsA(_failure(FoodReligionJudgmentFailure.cancelled)),
    );
    expect(resolverCalls, 0);
  });

  test('immediate completion wins a simultaneous timeout race', () async {
    final modelFile = File('${ggufRoot.path}/race.gguf')
      ..writeAsStringSync('model');
    final session = _FakeSession(const [
      '{"verdict":"信仰堅定","roast":"油飯只是外表，粽葉才是北粽的戰袍！"}',
    ]);
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => _FakeBackend(session),
      timeout: Duration.zero,
    );

    final result = await service.judge(
      model: FoodReligionModel(
        label: 'race',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );

    expect(result.verdict, FoodReligionVerdict.steadfast);
    expect(session.cancelCalls, 0);
    expect(session.disposeCalls, 1);
  });

  test('timeout wins before a late successful completion', () async {
    final modelFile = File('${ggufRoot.path}/timeout-first.gguf')
      ..writeAsStringSync('model');
    final session = _ControllableSession();
    late _ManualTimer timeoutTimer;
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => _FakeBackend(session),
      timerFactory: (duration, callback) {
        timeoutTimer = _ManualTimer(callback);
        return timeoutTimer;
      },
    );

    final judgment = service.judge(
      model: FoodReligionModel(
        label: 'timeout first',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );
    final expectation = expectLater(
      judgment,
      throwsA(_failure(FoodReligionJudgmentFailure.timeout)),
    );
    while (session.generateCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    timeoutTimer.fire();
    session.succeed('{"verdict":"信仰堅定","roast":"北粽立場站得很穩！"}');
    await expectation;

    expect(session.cancelCalls, 1);
    expect(session.disposeCalls, 1);
  });

  test('generation failure wins before late timeout and completion', () async {
    final modelFile = File('${ggufRoot.path}/failure-first.gguf')
      ..writeAsStringSync('model');
    final session = _ControllableSession();
    late _ManualTimer timeoutTimer;
    final service = OnDeviceFoodReligionJudgmentService(
      backendResolver: (_) => _FakeBackend(session),
      timerFactory: (duration, callback) {
        timeoutTimer = _ManualTimer(callback);
        return timeoutTimer;
      },
    );

    final judgment = service.judge(
      model: FoodReligionModel(
        label: 'failure first',
        path: modelFile.path,
        format: ModelFormat.gguf,
      ),
      stance: FoodFaith.northernZongzi,
      defense: FoodReligionDefense.validate('北粽最好吃').defense!,
    );
    final expectation = expectLater(
      judgment,
      throwsA(_failure(FoodReligionJudgmentFailure.generation)),
    );
    while (session.generateCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    session.fail(StateError('generation failed'));
    await expectation;
    timeoutTimer.fire();
    session.succeed('{"verdict":"信仰堅定","roast":"北粽立場站得很穩！"}');

    expect(session.cancelCalls, 0);
    expect(session.disposeCalls, 1);
  });

  test(
    'a selected model that disappeared fails before backend loading',
    () async {
      var resolverCalls = 0;
      final service = OnDeviceFoodReligionJudgmentService(
        backendResolver: (_) {
          resolverCalls++;
          return _FakeBackend(_FakeSession(const []));
        },
      );

      await expectLater(
        service.judge(
          model: const FoodReligionModel(
            label: 'missing',
            path: '/missing/model.gguf',
            format: ModelFormat.gguf,
          ),
          stance: FoodFaith.northernZongzi,
          defense: FoodReligionDefense.validate('北粽最好吃').defense!,
        ),
        throwsA(_failure(FoodReligionJudgmentFailure.modelUnavailable)),
      );
      expect(resolverCalls, 0);
    },
  );

  test(
    'backend loading and token stream errors use the same safe failure',
    () async {
      final modelFile = File('${ggufRoot.path}/broken.gguf')
        ..writeAsStringSync('model');
      final model = FoodReligionModel(
        label: 'broken',
        path: modelFile.path,
        format: ModelFormat.gguf,
      );
      final defense = FoodReligionDefense.validate('北粽最好吃').defense!;
      final services = [
        (
          OnDeviceFoodReligionJudgmentService(
            backendResolver: (_) => _ThrowingBackend(),
          ),
          FoodReligionJudgmentFailure.modelLoad,
        ),
        (
          OnDeviceFoodReligionJudgmentService(
            backendResolver: (_) => _FakeBackend(_ErrorSession()),
          ),
          FoodReligionJudgmentFailure.generation,
        ),
      ];

      for (final (service, failure) in services) {
        await expectLater(
          service.judge(
            model: model,
            stance: FoodFaith.northernZongzi,
            defense: defense,
          ),
          throwsA(_failure(failure)),
        );
      }
    },
  );
}

Matcher _failure(FoodReligionJudgmentFailure failure) =>
    isA<FoodReligionJudgmentException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

class _FakeBackend implements InferenceBackend {
  _FakeBackend(this.session);

  final InferenceSession session;
  InferenceSettings? settings;

  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) {
    this.settings = settings;
    return session;
  }
}

class _FakeSession implements InferenceSession {
  _FakeSession(this.tokens, {this.neverComplete = false});

  final List<String> tokens;
  final bool neverComplete;
  int generateCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  List<ChatMessage> messages = const [];
  final _never = StreamController<String>();

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    generateCalls++;
    this.messages = messages;
    return neverComplete ? _never.stream : Stream.fromIterable(tokens);
  }

  @override
  void cancel() {
    cancelCalls++;
  }

  @override
  void dispose() {
    disposeCalls++;
    _never.close();
  }
}

class _ControllableSession implements InferenceSession {
  final _tokens = StreamController<String>(sync: true);
  int generateCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    generateCalls++;
    return _tokens.stream;
  }

  void succeed(String output) {
    _tokens.add(output);
    _tokens.close();
  }

  void fail(Object error) {
    _tokens.addError(error);
  }

  @override
  void cancel() {
    cancelCalls++;
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  var _isActive = true;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _callback();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

class _ThrowingBackend implements InferenceBackend {
  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) => throw StateError('load failed');
}

class _ErrorSession implements InferenceSession {
  @override
  Stream<String> generate(List<ChatMessage> messages) =>
      Stream.error(StateError('generation failed'));

  @override
  void cancel() {}

  @override
  void dispose() {}
}
