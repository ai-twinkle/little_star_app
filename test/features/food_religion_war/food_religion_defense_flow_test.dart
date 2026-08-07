import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('defense accepts 1–50 visible characters with inline errors', (
    tester,
  ) async {
    await pumpFixedGame(tester);
    await playToDefense(tester);

    expect(find.text('0 / 50'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.text('請輸入 1～50 字的辯護'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '👨‍👩‍👧‍👦');
    await tester.pump();
    expect(find.text('1 / 50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), List.filled(51, '粽').join());
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.text('51 / 50'), findsOneWidget);
    expect(find.text('最多只能輸入 50 字'), findsOneWidget);
  });

  for (final defense in ['粽', List.filled(50, '粽').join()]) {
    testWidgets('${defense.length} visible characters complete fallback', (
      tester,
    ) async {
      await pumpFixedGame(tester);
      await playToDefense(tester);
      await tester.enterText(find.byType(TextField), defense);
      await tester.tap(find.text('送出辯護'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('AI 主持人暫時離線，改由備援鄉民評審裁決！'), findsOneWidget);
      expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
      expect(find.text('本局信仰清單'), findsOneWidget);
      expect(find.text('北部粽派（抽中）'), findsOneWidget);
    });
  }

  testWidgets('valid defense submits only once and locks controls', (
    tester,
  ) async {
    await pumpFixedGame(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.tap(find.text('送出辯護'));
    await tester.pump();

    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '送出辯護'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('replay creates a clean session and avoids the previous draw', (
    tester,
  ) async {
    final randomizer = FixedFoodReligionRandomizer(drawIndexes: const [0, 0]);
    await pumpFixedGame(tester, randomizer: randomizer);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('再玩一次'));
    await tester.pump();
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    expect(find.text('北粽就是香'), findsNothing);

    await playToDefense(tester);
    expect(randomizer.avoidedFaith?.label, '北部粽派');
    expect(find.text('香菜退散派'), findsWidgets);
    expect(find.text('少了香菜，這道料理還有靈魂嗎？'), findsOneWidget);
  });
}
