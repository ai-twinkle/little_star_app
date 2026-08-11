import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('Home flow completes model judgment and replays cleanly', (
    tester,
  ) async {
    final services = <_SuccessfulJudgmentService>[];
    await _pumpHome(
      tester,
      randomizer: FixedFoodReligionRandomizer(),
      judgmentServiceFactory: () {
        final service = _SuccessfulJudgmentService();
        services.add(service);
        return service;
      },
    );

    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await playFourChoices(tester);
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pumpAndSettle();

    expect(find.text('信仰堅定'), findsOneWidget);
    expect(find.text('粽葉香氣這一票，論點站穩了。'), findsOneWidget);
    expect(find.textContaining('備援鄉民評審'), findsNothing);
    expect(services.single.judgeCalls, 1);

    await tapReachable(tester, '再玩一次');
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    expect(find.text('粽葉香氣就是無法取代'), findsNothing);
    expect(find.text('信仰堅定'), findsNothing);
    expect(services, hasLength(2));
    expect(
      tester.binding.focusManager.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets('Home flow completes fallback judgment and returns Home', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      randomizer: FixedFoodReligionRandomizer(),
      judgmentServiceFactory: () => NoModelJudgmentService(),
    );

    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await dismissMissingModelReminder(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
    expect(find.textContaining('備援鄉民評審'), findsOneWidget);
    await tapReachable(tester, '回首頁');
    await tester.pumpAndSettle();

    expect(find.text('台灣食物宗教戰爭'), findsOneWidget);
    expect(find.text('裁決結果'), findsNothing);
    expect(find.text('北粽就是香'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets('system Back preserves every stage until exit is confirmed', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      randomizer: FixedFoodReligionRandomizer(),
      judgmentServiceFactory: () => NoModelJudgmentService(),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await dismissMissingModelReminder(tester);

    await _cancelSystemBack(tester);
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);

    await playFourChoices(tester);
    await _cancelSystemBack(tester);
    expect(find.text('抽出辯護立場'), findsOneWidget);

    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '取消離開後仍保留');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasPrimaryFocus,
      isTrue,
    );
    await _cancelSystemBack(tester);
    expect(find.text('送出辯護'), findsOneWidget);
    expect(find.text('取消離開後仍保留'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasPrimaryFocus,
      isTrue,
    );

    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    await _cancelSystemBack(tester);
    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await _cancelSystemBack(tester);
    expect(find.text('再玩一次'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('確定離開'));
    await tester.pumpAndSettle();
    expect(find.text('台灣食物宗教戰爭'), findsOneWidget);
    expect(find.text('裁決結果'), findsNothing);
  });

  testWidgets('confirmed exit from focused defense clears data and focus', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      randomizer: FixedFoodReligionRandomizer(),
      judgmentServiceFactory: () => NoModelJudgmentService(),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await dismissMissingModelReminder(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '離開就要清除');

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('確定離開'));
    await tester.pumpAndSettle();

    expect(find.text('台灣食物宗教戰爭'), findsOneWidget);
    expect(find.text('離開就要清除'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets(
    'player text and semantics never expose retired tournament terms',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpFixedGame(tester);
      await tester.pump();
      await dismissMissingModelReminder(tester);
      _expectNoRetiredTerms(tester);

      await playFourChoices(tester);
      _expectNoRetiredTerms(tester);
      await tester.tap(find.text('抽出辯護立場'));
      await tester.pump();
      _expectNoRetiredTerms(tester);
      await tester.enterText(find.byType(TextField), '北粽就是香');
      await tester.tap(find.text('送出辯護'));
      await tester.pump();
      _expectNoRetiredTerms(tester);
      await tester.pump(const Duration(milliseconds: 500));

      _expectNoRetiredTerms(tester);
      expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
      semantics.dispose();
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required FoodReligionGameRandomizer randomizer,
  required FoodReligionJudgmentService Function() judgmentServiceFactory,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FoodReligionGameHomeCard(
        randomizer: randomizer,
        judgmentServiceFactory: judgmentServiceFactory,
      ),
    ),
  ),
);

Future<void> _cancelSystemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.text('確定離開本局？'), findsOneWidget);
  await tester.tap(find.text('取消'));
  await tester.pump(const Duration(milliseconds: 200));
}

void _expectNoRetiredTerms(WidgetTester tester) {
  final retiredTerms = RegExp(r'準決賽|決賽|晉級|淘汰|冠軍|最高位階');
  expect(find.textContaining(retiredTerms), findsNothing);
  expect(find.bySemanticsLabel(retiredTerms), findsNothing);
}

class _SuccessfulJudgmentService implements FoodReligionJudgmentService {
  static const model = FoodReligionModel(
    path: '/models/judge.gguf',
    label: '夜市評審',
    format: ModelFormat.gguf,
  );

  int judgeCalls = 0;

  @override
  Future<List<FoodReligionModel>> discoverModels() async => const [model];

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) async {
    judgeCalls++;
    return const FoodReligionJudgment(
      verdict: FoodReligionVerdict.steadfast,
      roast: '粽葉香氣這一票，論點站穩了。',
    );
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}
