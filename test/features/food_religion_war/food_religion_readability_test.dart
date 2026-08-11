import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('Home flow renders choice names with readable arena text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodReligionGameHomeCard(
            judgmentServiceFactory: () => NoModelJudgmentService(),
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await dismissMissingModelReminder(tester);

    final style = _effectiveTextStyle(tester, find.text('北部粽派'));
    expect(style.fontSize, greaterThanOrEqualTo(18));
    expect(
      contrastRatio(style.color!, const Color(0xFF182A30)),
      greaterThanOrEqualTo(minimumNormalTextContrast),
    );
  });

  testWidgets('Home flow keeps draw and defense information readable', (
    tester,
  ) async {
    await _pumpGameFromHome(
      tester,
      judgmentServiceFactory: () => InstalledModelJudgmentService(),
    );
    await playFourChoices(tester);

    _expectReadableText(
      tester,
      find.text('本局信仰清單'),
      background: const Color(0xFF122329),
      minimumSize: 16,
    );
    final chipTheme =
        Theme.of(tester.element(find.widgetWithText(Chip, '北部粽派'))).chipTheme;
    expect(chipTheme.backgroundColor, const Color(0xFF182A30));
    expect(chipTheme.labelStyle?.fontSize, greaterThanOrEqualTo(16));
    expect(
      contrastRatio(chipTheme.labelStyle!.color!, chipTheme.backgroundColor!),
      greaterThanOrEqualTo(minimumNormalTextContrast),
    );
    _expectReadableText(
      tester,
      find.text('抽出辯護立場'),
      background: const Color(0xFFF5BE5B),
      minimumSize: 18,
    );

    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();

    _expectReadableText(
      tester,
      find.text('北部粽不就是包在粽葉裡的油飯嗎？'),
      background: const Color(0xFF071419),
      minimumSize: 18,
    );
    _expectReadableText(
      tester,
      find.text('0 / 50'),
      background: const Color(0xFF122329),
      minimumSize: 16,
    );
    _expectReadableText(
      tester,
      find.text('GGUF · judge.gguf'),
      background: const Color(0xFF071419),
      minimumSize: 16,
    );
    _expectReadableText(
      tester,
      find.text('送出辯護'),
      background: const Color(0xFFF5BE5B),
      minimumSize: 18,
    );
  });

  testWidgets('Home flow renders result copy and actions readably', (
    tester,
  ) async {
    await _pumpGameFromHome(
      tester,
      judgmentServiceFactory: () => InstalledModelJudgmentService(),
    );
    await playFourChoices(tester);
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pumpAndSettle();

    _expectReadableText(
      tester,
      find.text('食物論點安全過關！'),
      background: const Color(0xFF122329),
      minimumSize: 16,
    );
    _expectReadableText(
      tester,
      find.text('本次抽中；四個選擇都會保留。'),
      background: const Color(0xFF122329),
      minimumSize: 16,
    );
    _expectReadableText(
      tester,
      find.text('再玩一次'),
      background: const Color(0xFFF5BE5B),
      minimumSize: 18,
    );
    _expectReadableText(
      tester,
      find.text('回首頁'),
      background: const Color(0xFF122329),
      minimumSize: 18,
    );
  });

  testWidgets('Home flow keeps input hints and locked controls readable', (
    tester,
  ) async {
    final service = _PendingJudgmentService();
    await _pumpGameFromHome(tester, judgmentServiceFactory: () => service);
    await playFourChoices(tester);
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();

    _expectReadableText(
      tester,
      find.text('用一句話捍衛這個立場'),
      background: const Color(0xFF071419),
      minimumSize: 16,
    );
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tapReachable(tester, '送出辯護');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);

    final defenseStyle =
        tester.widget<EditableText>(find.byType(EditableText)).style;
    expect(defenseStyle.fontSize, greaterThanOrEqualTo(16));
    expect(
      contrastRatio(defenseStyle.color!, const Color(0xFF071419)),
      greaterThanOrEqualTo(minimumNormalTextContrast),
    );

    _expectReadableText(
      tester,
      find.text('GGUF · judge.gguf'),
      background: const Color(0xFF071419),
      minimumSize: 16,
    );
    _expectReadableText(
      tester,
      find.text('送出辯護'),
      background: const Color(0xFF182A30),
      minimumSize: 18,
    );
  });
}

Future<void> _pumpGameFromHome(
  WidgetTester tester, {
  required InstalledModelJudgmentService Function() judgmentServiceFactory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FoodReligionGameHomeCard(
          judgmentServiceFactory: judgmentServiceFactory,
          randomizer: FixedFoodReligionRandomizer(),
        ),
      ),
    ),
  );
  await tester.tap(find.text('台灣食物宗教戰爭'));
  await tester.pumpAndSettle();
}

void _expectReadableText(
  WidgetTester tester,
  Finder finder, {
  required Color background,
  required double minimumSize,
}) {
  final style = _effectiveTextStyle(tester, finder);
  expect(style.fontSize, greaterThanOrEqualTo(minimumSize));
  expect(
    contrastRatio(style.color!, background),
    greaterThanOrEqualTo(minimumNormalTextContrast),
    reason: 'Rendered style $style on $background',
  );
}

TextStyle _effectiveTextStyle(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final inherited = DefaultTextStyle.of(tester.element(finder)).style;
  return inherited.merge(text.style);
}

class _PendingJudgmentService extends InstalledModelJudgmentService {
  final result = Completer<FoodReligionJudgment>();

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) => result.future;
}
