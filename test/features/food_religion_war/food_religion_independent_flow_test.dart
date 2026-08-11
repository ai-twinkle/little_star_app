import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

void main() {
  testWidgets(
    'four independent choices remain visible before a one-time draw',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodReligionGameScreen(randomizer: _FixedRandomizer()),
        ),
      );

      for (final choice in const ['北部粽派', '香菜退散派', '豆花配糖水', '火鍋原湯派']) {
        await tester.tap(find.text(choice));
        await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);
      }

      expect(find.text('本局信仰清單'), findsOneWidget);
      for (final choice in const ['北部粽派', '香菜退散派', '豆花配糖水', '火鍋原湯派']) {
        expect(find.text(choice), findsOneWidget);
      }
      expect(find.text('抽出辯護立場'), findsOneWidget);
      expect(find.text('北部粽派不就是包在粽葉裡的油飯嗎？'), findsNothing);

      await tester.tap(find.text('抽出辯護立場'));
      await tester.pump();

      expect(find.text('火鍋原湯派'), findsWidgets);
      expect(find.text('湯都不沾醬，味道真的夠嗎？'), findsOneWidget);
      expect(find.text('抽出辯護立場'), findsNothing);
    },
  );
}

class _FixedRandomizer implements FoodReligionGameRandomizer {
  @override
  List<FoodStancePair> selectRounds(List<FoodStancePair> pool, int count) =>
      FoodStancePair.stancePool.take(count).toList();

  @override
  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid}) =>
      candidates.last;
}
