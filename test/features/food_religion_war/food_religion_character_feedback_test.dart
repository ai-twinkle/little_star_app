import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';

import 'food_religion_test_support.dart';

void main() {
  const expectedAssets = {
    FoodFaith.northernZongzi:
        'assets/food_religion_war/characters/northern_zongzi.png',
    FoodFaith.southernZongzi:
        'assets/food_religion_war/characters/southern_zongzi.png',
    FoodFaith.extraCilantro:
        'assets/food_religion_war/characters/extra_cilantro.png',
    FoodFaith.noCilantro: 'assets/food_religion_war/characters/no_cilantro.png',
  };

  testWidgets('existing stances retain their loadable square character art', (
    tester,
  ) async {
    for (final MapEntry(key: faith, value: expectedPath)
        in expectedAssets.entries) {
      expect(faith.characterAssetPath, expectedPath);
      final data = await rootBundle.load(expectedPath);
      expect(data.getUint32(16), 1024, reason: faith.label);
      expect(data.getUint32(20), 1024, reason: faith.label);
    }
  });

  testWidgets('all twelve stances have stable content and artwork slots', (
    tester,
  ) async {
    expect(FoodFaith.values, hasLength(12));
    expect(FoodFaith.values.map((faith) => faith.label).toSet(), hasLength(12));
    for (final faith in FoodFaith.values) {
      expect(faith.finalChallenge, isNotEmpty);
      expect(faith.fallbackRoasts, hasLength(3));
    }

    await pumpFixedGame(tester);
    expect(
      find.byKey(const ValueKey('food-faith-art-northernZongzi')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('food-faith-art-southernZongzi')),
      findsOneWidget,
    );
  });

  testWidgets('recorded choice uses text, icon, border, and a locked state', (
    tester,
  ) async {
    await pumpFixedGame(tester);
    await tester.tap(find.text('北部粽派'));
    await tester.pump();

    expect(find.text('立場已記錄'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.bySemanticsLabel('北部粽派，立場已記錄，已鎖定'), findsOneWidget);
    expect(find.bySemanticsLabel('南部粽派，已鎖定'), findsOneWidget);
  });

  testWidgets('drawn stance art is reused as the primary fallback result', (
    tester,
  ) async {
    await pumpFixedGame(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('food-faith-art-northernZongzi')),
      findsOneWidget,
    );
    expect(find.text('本次抽中'), findsOneWidget);
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
  });
}
