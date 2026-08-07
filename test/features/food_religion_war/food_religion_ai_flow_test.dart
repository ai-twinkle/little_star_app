import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

void main() {
  testWidgets(
    'player switches model, submit locks it, and valid AI result wins',
    (tester) async {
      final service = _FakeJudgmentService();
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(judgmentServiceFactory: () => service),
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

  testWidgets('judgment failure transparently renders only a fallback result', (
    tester,
  ) async {
    final service = _FakeJudgmentService(failJudgment: true);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(judgmentServiceFactory: () => service),
      ),
    );
    await tester.pump();
    await _playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽最好吃');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();

    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
    expect(find.textContaining('technical failure'), findsNothing);
    expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
  });

  testWidgets('model discovery failure still completes with fallback', (
    tester,
  ) async {
    final service = _FakeJudgmentService(failDiscovery: true);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(judgmentServiceFactory: () => service),
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

  testWidgets('no installed model still completes with fallback', (
    tester,
  ) async {
    final service = _FakeJudgmentService(models: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodReligionGameScreen(judgmentServiceFactory: () => service),
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
          home: FoodReligionGameScreen(judgmentServiceFactory: () => service),
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
  await tester.tap(find.text('北部粽派'));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.text('香菜加爆派'));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.text('北部粽派'));
  await tester.pump(const Duration(milliseconds: 800));
}

class _FakeJudgmentService implements FoodReligionJudgmentService {
  _FakeJudgmentService({
    this.failJudgment = false,
    this.failDiscovery = false,
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

  final bool failJudgment;
  final bool failDiscovery;
  final List<FoodReligionModel> models;
  int discoverCalls = 0;
  int judgeCalls = 0;
  int disposeCalls = 0;
  FoodReligionModel? selectedModel;
  FoodReligionDefense? defense;
  Completer<FoodReligionJudgment>? _result;

  @override
  Future<List<FoodReligionModel>> discoverModels() async {
    discoverCalls++;
    if (failDiscovery) throw StateError('discovery failed');
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
    this.defense = defense;
    if (failJudgment) {
      return Future.error(StateError('technical failure'));
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
