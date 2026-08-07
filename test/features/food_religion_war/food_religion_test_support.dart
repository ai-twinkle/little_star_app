import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

class FixedFoodReligionRandomizer implements FoodReligionGameRandomizer {
  FixedFoodReligionRandomizer({this.drawIndexes = const [0]});

  final List<int> drawIndexes;
  int drawCalls = 0;
  FoodFaith? avoidedFaith;

  @override
  List<FoodStancePair> selectRounds(List<FoodStancePair> pool, int count) =>
      FoodStancePair.stancePool.take(count).toList();

  @override
  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid}) {
    avoidedFaith = avoid;
    final index = drawIndexes[drawCalls.clamp(0, drawIndexes.length - 1)];
    drawCalls++;
    final selected = candidates[index.clamp(0, candidates.length - 1)];
    if (selected == avoid && candidates.length > 1) {
      return candidates.firstWhere((faith) => faith != avoid);
    }
    return selected;
  }
}

Future<void> pumpFixedGame(
  WidgetTester tester, {
  FoodReligionJudgmentService Function()? judgmentServiceFactory,
  FixedFoodReligionRandomizer? randomizer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FoodReligionGameScreen(
        judgmentServiceFactory:
            judgmentServiceFactory ?? () => NoModelJudgmentService(),
        randomizer: randomizer ?? FixedFoodReligionRandomizer(),
      ),
    ),
  );
  await tester.pump();
}

class NoModelJudgmentService implements FoodReligionJudgmentService {
  @override
  Future<List<FoodReligionModel>> discoverModels() async => const [];

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) => Future.error(
    const FoodReligionJudgmentException(
      FoodReligionJudgmentFailure.modelUnavailable,
    ),
  );

  @override
  void cancel() {}

  @override
  void dispose() {}
}

Future<void> playFourChoices(
  WidgetTester tester, {
  List<String> choices = const ['北部粽派', '香菜退散派', '豆花配糖水', '火鍋原湯派'],
}) async {
  await tester.pump();
  await dismissMissingModelReminder(tester);
  for (final choice in choices) {
    await dismissMissingModelReminder(tester);
    await tester.tap(find.text(choice));
    await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);
    await dismissMissingModelReminder(tester);
  }
}

Future<void> dismissMissingModelReminder(WidgetTester tester) async {
  final continueWithoutModel = find.text('先玩再說');
  if (continueWithoutModel.evaluate().isEmpty) return;
  await tester.tap(continueWithoutModel);
  await tester.pumpAndSettle();
}

Future<void> tapReachable(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pump();

  final viewportSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  var targetRect = tester.getRect(target);
  final overflow = targetRect.bottom - viewportSize.height;
  if (overflow > 0) {
    await tester.dragFrom(
      Offset(viewportSize.width / 2, viewportSize.height * 0.75),
      Offset(0, -overflow - 24),
    );
    await tester.pump();
  }
  targetRect = tester.getRect(target);
  if (targetRect.top < 24) {
    await tester.dragFrom(
      Offset(viewportSize.width / 2, viewportSize.height * 0.25),
      Offset(0, 48 - targetRect.top),
    );
    await tester.pump();
  }
  await tester.tap(target);
  await tester.pump();
}

Future<void> playToDefense(WidgetTester tester) async {
  await playFourChoices(tester);
  await tester.tap(find.text('抽出辯護立場'));
  await tester.pump();
}
