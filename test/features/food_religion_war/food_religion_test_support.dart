import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

class FixedFoodReligionRandomizer implements FoodReligionGameRandomizer {
  FixedFoodReligionRandomizer({this.drawIndexes = const [0]});

  final List<int> drawIndexes;
  int drawCalls = 0;
  FoodFaith? avoidedFaith;

  @override
  List<FoodFaithPair> selectRounds(List<FoodFaithPair> pool, int count) =>
      FoodFaithPair.pool.take(count).toList();

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
        judgmentServiceFactory: judgmentServiceFactory,
        randomizer: randomizer ?? FixedFoodReligionRandomizer(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> playFourChoices(
  WidgetTester tester, {
  List<String> choices = const ['北部粽派', '香菜退散派', '豆花配糖水', '火鍋原湯派'],
}) async {
  for (final choice in choices) {
    await tester.tap(find.text(choice));
    await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);
  }
}

Future<void> playToDefense(WidgetTester tester) async {
  await playFourChoices(tester);
  await tester.tap(find.text('抽出辯護立場'));
  await tester.pump();
}
