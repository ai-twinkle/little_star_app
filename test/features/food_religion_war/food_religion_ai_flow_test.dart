import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

import 'food_religion_test_support.dart';

void main() {
  for (final drawnStance in FoodFaith.values) {
    testWidgets(
      'passes ${drawnStance.label} and the raw defense to the judgment service',
      (tester) async {
        final service = _FakeJudgmentService();
        final randomizer = _DrawnStanceRandomizer(drawnStance);
        await tester.pumpWidget(
          MaterialApp(
            home: FoodReligionGameScreen(
              judgmentServiceFactory: () => service,
              randomizer: randomizer,
            ),
          ),
        );
        await tester.pump();

        for (final (index, round) in randomizer.rounds.indexed) {
          final choice = index == 0 ? drawnStance : round.left;
          await tester.tap(find.text(choice.label));
          await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);
        }
        await tester.tap(find.text('抽出辯護立場'));
        await tester.pump();
        expect(find.text(drawnStance.finalChallenge), findsOneWidget);

        const rawDefense = '  這是玩家原始辯護  ';
        await tester.enterText(find.byType(TextField), rawDefense);
        await tester.tap(find.text('送出辯護'));
        await tester.pump();

        expect(service.judgeCalls, 1);
        expect(service.selectedStance, drawnStance);
        expect(service.defense?.text, rawDefense);
        service.complete(
          const FoodReligionJudgment(
            verdict: FoodReligionVerdict.reluctant,
            roast: '食物論點還能再加一匙！',
          ),
        );
        await tester.pump();
      },
    );
  }

  for (final verdict in FoodReligionVerdict.values) {
    testWidgets('renders the legal ${verdict.label} model judgment', (
      tester,
    ) async {
      final service = _FakeJudgmentService();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            judgmentServiceFactory: () => service,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      );
      await tester.pump();
      await _playToDefense(tester);
      await tester.enterText(find.byType(TextField), '北粽最好吃');
      await tester.tap(find.text('送出辯護'));
      service.complete(
        FoodReligionJudgment(verdict: verdict, roast: '食物論點安全過關！'),
      );
      await tester.pump();

      expect(find.text(verdict.label), findsOneWidget);
      expect(find.text('食物論點安全過關！'), findsOneWidget);
      expect(find.textContaining('AI 主持人暫時離線'), findsNothing);
    });
  }

  testWidgets(
    'player switches model, submit locks it, and valid AI result wins',
    (tester) async {
      final service = _FakeJudgmentService();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            judgmentServiceFactory: () => service,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      );
      await tester.pump();
      await _playToDefense(tester);

      expect(find.text('GGUF · a.gguf'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<FoodReligionModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MLX · b-mlx').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  這是我的原始辯護  ');
      await tester.tap(find.text('送出辯護'));
      await tester.pump();

      expect(service.judgeCalls, 1);
      expect(service.selectedModel?.label, 'MLX · b-mlx');
      expect(service.defense?.text, '  這是我的原始辯護  ');
      expect(
        tester
            .widget<DropdownButtonFormField<FoodReligionModel>>(
              find.byType(DropdownButtonFormField<FoodReligionModel>),
            )
            .onChanged,
        isNull,
      );

      service.complete(
        const FoodReligionJudgment(
          verdict: FoodReligionVerdict.reluctant,
          roast: '論點有包好，粽葉還想再聞一下！',
        ),
      );
      await tester.pump();

      expect(find.text('勉強護教'), findsOneWidget);
      expect(find.text('論點有包好，粽葉還想再聞一下！'), findsOneWidget);
      expect(find.textContaining('AI 主持人暫時離線'), findsNothing);
    },
  );

  testWidgets(
    'replay creates a new session and rediscovers the default model',
    (tester) async {
      final services = <_FakeJudgmentService>[];
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            randomizer: FixedFoodReligionRandomizer(),
            judgmentServiceFactory: () {
              final service = _FakeJudgmentService();
              services.add(service);
              return service;
            },
          ),
        ),
      );
      await tester.pump();
      await _playToDefense(tester);
      await tester.enterText(find.byType(TextField), '北粽最好吃');
      await tester.tap(find.text('送出辯護'));
      services.single.complete(
        const FoodReligionJudgment(
          verdict: FoodReligionVerdict.steadfast,
          roast: '北粽今天站得很穩！',
        ),
      );
      await tester.pump();
      await tester.tap(find.text('再玩一次'));
      await tester.pump();

      expect(services, hasLength(2));
      expect(services.first.disposeCalls, 1);
      expect(services.last.discoverCalls, 1);
    },
  );

  for (final failure in FoodReligionJudgmentFailure.values) {
    testWidgets('${failure.name} transparently renders only fallback', (
      tester,
    ) async {
      final service = _FakeJudgmentService(judgmentFailure: failure);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            judgmentServiceFactory: () => service,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      );
      await tester.pump();
      await _playToDefense(tester);
      await tester.enterText(find.byType(TextField), '北粽最好吃');
      await tester.tap(find.text('送出辯護'));
      await tester.pump();

      expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
      expect(find.textContaining(failure.name), findsNothing);
      expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
    });
  }

  testWidgets('model discovery failure still completes with fallback', (
    tester,
  ) async {
    final service = _FakeJudgmentService(failDiscovery: true);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(
          judgmentServiceFactory: () => service,
          randomizer: FixedFoodReligionRandomizer(),
        ),
      ),
    );
    await tester.pump();
    await _playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽最好吃');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.judgeCalls, 0);
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
    expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
  });

  testWidgets(
    'submit waits for discovery and then locks the discovered default model',
    (tester) async {
      final discovery = Completer<List<FoodReligionModel>>();
      final service = _FakeJudgmentService(discovery: discovery);
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            judgmentServiceFactory: () => service,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      );
      await _playToDefense(tester);
      expect(find.text('正在發現已安裝模型…'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '北粽最好吃');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '送出辯護'))
            .onPressed,
        isNull,
      );
      discovery.complete(service.models);
      await tester.pump();
      await tester.tap(find.text('送出辯護'));
      await tester.pump();

      expect(service.judgeCalls, 1);
      expect(service.selectedModel?.label, 'GGUF · a.gguf');
    },
  );

  testWidgets('stalled model discovery releases submit to safe fallback', (
    tester,
  ) async {
    final service = _FakeJudgmentService(
      discovery: Completer<List<FoodReligionModel>>(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(
          judgmentServiceFactory: () => service,
          randomizer: FixedFoodReligionRandomizer(),
        ),
      ),
    );
    await _playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽最好吃');

    await tester.pump(FoodReligionGameSession.modelDiscoveryTimeout);

    expect(find.text('目前沒有已安裝模型，送出後將使用備援裁決。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '送出辯護'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
  });

  testWidgets('leaving during model discovery cancels the timeout', (
    tester,
  ) async {
    final service = _FakeJudgmentService(
      discovery: Completer<List<FoodReligionModel>>(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(
          judgmentServiceFactory: () => service,
          randomizer: FixedFoodReligionRandomizer(),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(service.disposeCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no installed model still completes with fallback', (
    tester,
  ) async {
    final service = _FakeJudgmentService(models: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(
          judgmentServiceFactory: () => service,
          randomizer: FixedFoodReligionRandomizer(),
        ),
      ),
    );
    await tester.pump();
    await _playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽最好吃');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.judgeCalls, 0);
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
    expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
  });

  testWidgets(
    'leaving during judgment disposes service and ignores late result',
    (tester) async {
      final service = _FakeJudgmentService();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(
            judgmentServiceFactory: () => service,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      );
      await tester.pump();
      await _playToDefense(tester);
      await tester.enterText(find.byType(TextField), '北粽最好吃');
      await tester.tap(find.text('送出辯護'));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(service.disposeCalls, 1);

      service.complete(
        const FoodReligionJudgment(
          verdict: FoodReligionVerdict.steadfast,
          roast: '晚到的結果不應更新畫面！',
        ),
      );
      await tester.pump();

      expect(find.text('晚到的結果不應更新畫面！'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _playToDefense(WidgetTester tester) async {
  await playToDefense(tester);
}

class _FakeJudgmentService implements FoodReligionJudgmentService {
  _FakeJudgmentService({
    this.judgmentFailure,
    this.failDiscovery = false,
    this.discovery,
    this.models = const [
      FoodReligionModel(
        label: 'GGUF · a.gguf',
        path: '/models/a.gguf',
        format: ModelFormat.gguf,
      ),
      FoodReligionModel(
        label: 'MLX · b-mlx',
        path: '/models/b-mlx',
        format: ModelFormat.mlx,
      ),
    ],
  });

  final FoodReligionJudgmentFailure? judgmentFailure;
  final bool failDiscovery;
  final Completer<List<FoodReligionModel>>? discovery;
  final List<FoodReligionModel> models;
  int discoverCalls = 0;
  int judgeCalls = 0;
  int disposeCalls = 0;
  FoodReligionModel? selectedModel;
  FoodFaith? selectedStance;
  FoodReligionDefense? defense;
  Completer<FoodReligionJudgment>? _result;

  @override
  Future<List<FoodReligionModel>> discoverModels() async {
    discoverCalls++;
    if (failDiscovery) throw StateError('discovery failed');
    if (discovery != null) return discovery!.future;
    return models;
  }

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) {
    judgeCalls++;
    selectedModel = model;
    selectedStance = stance;
    this.defense = defense;
    if (judgmentFailure != null) {
      return Future.error(FoodReligionJudgmentException(judgmentFailure!));
    }
    _result = Completer<FoodReligionJudgment>();
    return _result!.future;
  }

  void complete(FoodReligionJudgment judgment) => _result!.complete(judgment);

  @override
  void cancel() {}

  @override
  void dispose() {
    disposeCalls++;
  }
}

class _DrawnStanceRandomizer implements FoodReligionGameRandomizer {
  _DrawnStanceRandomizer(this.drawnStance);

  final FoodFaith drawnStance;
  late final List<FoodStancePair> rounds;

  @override
  List<FoodStancePair> selectRounds(List<FoodStancePair> pool, int count) {
    final drawnPair = pool.singleWhere(
      (pair) => pair.stances.contains(drawnStance),
    );
    rounds = [
      drawnPair,
      ...pool.where((pair) => pair != drawnPair).take(count - 1),
    ];
    return rounds;
  }

  @override
  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid}) {
    expect(candidates, contains(drawnStance));
    return drawnStance;
  }
}
