import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

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

  testWidgets('四個信仰對應可載入的 1024 方形角色資產', (tester) async {
    for (final MapEntry(key: faith, value: expectedPath)
        in expectedAssets.entries) {
      expect(faith.characterAssetPath, expectedPath);

      final data = await rootBundle.load(expectedPath);
      expect(data.getUint32(16), 1024, reason: faith.label);
      expect(data.getUint32(20), 1024, reason: faith.label);
    }
  });

  testWidgets('準決賽依信仰呈現正確角色', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FoodReligionGameScreen()));

    expect(
      _assetName(tester, FoodFaith.northernZongzi),
      expectedAssets[FoodFaith.northernZongzi],
    );
    expect(
      _assetName(tester, FoodFaith.southernZongzi),
      expectedAssets[FoodFaith.southernZongzi],
    );
    expect(
      find.byKey(const ValueKey('food-faith-art-extraCilantro')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('food-faith-art-noCilantro')),
      findsNothing,
    );
  });

  testWidgets('勝方回饋持續 800 ms 並鎖定兩張卡片', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FoodReligionGameScreen()));

    await tester.tap(find.text('北部粽派'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('南部粽派'));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('winner-motion-northernZongzi')),
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.02));
    expect(transform.transform.getTranslation().y, lessThan(-4));

    final glow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('winner-glow-northernZongzi')),
    );
    expect((glow.decoration as BoxDecoration).boxShadow, isNotEmpty);
    expect(find.text('北部粽派晉級！'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('準決賽 1/2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('準決賽 2/2'), findsOneWidget);
  });

  testWidgets('從 Home 到備援結果重用角色並以原生 UI 呈現冠軍感', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('北部粽派'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      _assetName(tester, FoodFaith.extraCilantro),
      expectedAssets[FoodFaith.extraCilantro],
    );
    expect(
      _assetName(tester, FoodFaith.noCilantro),
      expectedAssets[FoodFaith.noCilantro],
    );

    await tester.tap(find.text('香菜加爆派'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('final-match-versus')), findsOneWidget);
    expect(
      _assetName(tester, FoodFaith.northernZongzi),
      expectedAssets[FoodFaith.northernZongzi],
    );
    expect(
      _assetName(tester, FoodFaith.extraCilantro),
      expectedAssets[FoodFaith.extraCilantro],
    );

    await tester.tap(find.text('北部粽派'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('冠軍'), findsOneWidget);
    expect(find.byKey(const ValueKey('champion-confetti')), findsOneWidget);
    expect(
      _assetName(tester, FoodFaith.northernZongzi),
      expectedAssets[FoodFaith.northernZongzi],
    );
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
  });
}

String _assetName(WidgetTester tester, FoodFaith faith) {
  final image = tester.widget<Image>(
    find.byKey(ValueKey('food-faith-art-${faith.name}')),
  );
  return (image.image as AssetImage).assetName;
}
