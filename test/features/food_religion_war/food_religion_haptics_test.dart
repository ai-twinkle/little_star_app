import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

import 'food_religion_test_support.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('mobile players feel the result transition', (tester) async {
    await _pumpArena(tester);
    await _playToResultAndClear(tester, haptics);

    await tester.pump(FoodReligionGameSession.fallbackJudgmentDelay);

    expect(haptics, isNotEmpty);
  });

  testWidgets('reduced motion silences the result transition', (tester) async {
    await _pumpArena(tester, disableAnimations: true);
    await _playToResultAndClear(tester, haptics);

    await tester.pump(FoodReligionGameSession.fallbackJudgmentDelay);

    expect(haptics, isEmpty);
  });

  testWidgets('reduced motion silences the choice tap', (tester) async {
    await _pumpArena(tester, disableAnimations: true);
    await dismissMissingModelReminder(tester);

    await tester.tap(find.text('北部粽派'));
    await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);

    expect(haptics, isEmpty);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('${platform.name} has no haptics to play', (tester) async {
      await _pumpArena(tester, platform: platform);
      await _playToResultAndClear(tester, haptics);

      await tester.pump(FoodReligionGameSession.fallbackJudgmentDelay);

      expect(haptics, isEmpty);
    });
  }
}

Future<void> _pumpArena(
  WidgetTester tester, {
  bool disableAnimations = false,
  TargetPlatform? platform,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder:
            (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: FoodReligionGameScreen(
                judgmentServiceFactory: () => NoModelJudgmentService(),
                randomizer: FixedFoodReligionRandomizer(),
              ),
            ),
      ),
    ),
  );
  await tester.pump();
}

/// Clears the taps and the draw so only the result transition is left.
Future<void> _playToResultAndClear(
  WidgetTester tester,
  List<String> haptics,
) async {
  await playToDefense(tester);
  await tester.enterText(find.byType(TextField), '北粽最好吃');
  await tester.tap(find.text('送出辯護'));
  await tester.pump();
  haptics.clear();
}
