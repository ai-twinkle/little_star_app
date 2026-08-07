import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';

import 'food_religion_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedAssets = <FoodFaith, String>{
    FoodFaith.northernZongzi:
        'assets/food_religion_war/characters/northern_zongzi.png',
    FoodFaith.southernZongzi:
        'assets/food_religion_war/characters/southern_zongzi.png',
    FoodFaith.extraCilantro:
        'assets/food_religion_war/characters/extra_cilantro.png',
    FoodFaith.noCilantro: 'assets/food_religion_war/characters/no_cilantro.png',
    FoodFaith.sweetTofuPudding:
        'assets/food_religion_war/characters/sweet_tofu_pudding.png',
    FoodFaith.soyMilkTofuPudding:
        'assets/food_religion_war/characters/soy_milk_tofu_pudding.png',
    FoodFaith.satayHotPot:
        'assets/food_religion_war/characters/satay_hot_pot.png',
    FoodFaith.brothHotPot:
        'assets/food_religion_war/characters/broth_hot_pot.png',
    FoodFaith.fullSugarBubbleTea:
        'assets/food_religion_war/characters/full_sugar_bubble_tea.png',
    FoodFaith.lessSugarBubbleTea:
        'assets/food_religion_war/characters/less_sugar_bubble_tea.png',
    FoodFaith.saltedFries:
        'assets/food_religion_war/characters/salted_fries.png',
    FoodFaith.plainFries: 'assets/food_religion_war/characters/plain_fries.png',
  };

  test('all stances have unique loadable square transparent art', () async {
    expect(expectedAssets, hasLength(FoodFaith.values.length));
    expect(expectedAssets.values.toSet(), hasLength(FoodFaith.values.length));

    for (final MapEntry(key: faith, value: expectedPath)
        in expectedAssets.entries) {
      expect(faith.characterAssetPath, expectedPath);
      final data = await rootBundle.load(expectedPath);
      expect(data.getUint32(16), 1024, reason: faith.label);
      expect(data.getUint32(20), 1024, reason: faith.label);
      expect(data.getUint8(25), 6, reason: '${faith.label} must use RGBA PNG');

      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(
        _containsTransparentAndOpaquePixels(pixels!),
        isTrue,
        reason: '${faith.label} must contain transparent padding and artwork',
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  testWidgets('all twelve stances have stable content and artwork slots', (
    tester,
  ) async {
    expect(FoodFaith.values, hasLength(12));
    expect(FoodFaith.values.map((faith) => faith.label).toSet(), hasLength(12));
    for (final faith in FoodFaith.values) {
      expect(faith.finalChallenge, isNotEmpty);
      expect(faith.fallbackCopy.steadfast, isNotEmpty);
      expect(faith.fallbackCopy.reluctant, isNotEmpty);
      expect(faith.fallbackCopy.wavering, isNotEmpty);
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

  testWidgets('four new stances keep their mascots through the full flow', (
    tester,
  ) async {
    await pumpFixedGame(tester, randomizer: _NewStanceRandomizer());
    await dismissMissingModelReminder(tester);

    for (final choice in const [
      FoodFaith.sweetTofuPudding,
      FoodFaith.brothHotPot,
      FoodFaith.fullSugarBubbleTea,
      FoodFaith.plainFries,
    ]) {
      expect(
        find.byKey(ValueKey('food-faith-art-${choice.name}')),
        findsOneWidget,
      );
      await tester.tap(find.text(choice.label));
      await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);
      await dismissMissingModelReminder(tester);
    }

    for (final choice in const [
      FoodFaith.sweetTofuPudding,
      FoodFaith.brothHotPot,
      FoodFaith.fullSugarBubbleTea,
      FoodFaith.plainFries,
    ]) {
      expect(
        find.byKey(ValueKey('belief-slate-art-${choice.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('food-faith-art-plainFries')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '原味才能吃出馬鈴薯真正的香氣');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('food-faith-art-plainFries')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('belief-slate-art-plainFries')),
      findsOneWidget,
    );
  });
}

bool _containsTransparentAndOpaquePixels(ByteData pixels) {
  var hasTransparent = false;
  var hasOpaque = false;
  for (var offset = 3; offset < pixels.lengthInBytes; offset += 4) {
    final alpha = pixels.getUint8(offset);
    hasTransparent |= alpha == 0;
    hasOpaque |= alpha == 255;
    if (hasTransparent && hasOpaque) return true;
  }
  return false;
}

class _NewStanceRandomizer extends FixedFoodReligionRandomizer {
  @override
  List<FoodStancePair> selectRounds(List<FoodStancePair> pool, int count) =>
      FoodStancePair.stancePool.skip(2).take(count).toList();

  @override
  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid}) =>
      candidates.last;
}
