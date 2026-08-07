import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('Home entry starts the first independent choice immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );

    expect(find.text('四次飲食抉擇，一次辯護抽籤'), findsOneWidget);
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();

    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    expect(find.text('選一個你支持的飲食立場'), findsOneWidget);
  });

  testWidgets('a choice locks both cards and advances only after feedback', (
    tester,
  ) async {
    await pumpFixedGame(tester);

    await tester.tap(find.text('北部粽派'));
    await tester.tap(find.text('南部粽派'));
    await tester.pump(const Duration(milliseconds: 799));

    expect(find.text('立場已記錄'), findsOneWidget);
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('飲食抉擇 2/4'), findsOneWidget);
    expect(find.text('香菜退散派'), findsOneWidget);
  });

  testWidgets('draw comes from the slate and cannot be repeated', (
    tester,
  ) async {
    final randomizer = FixedFoodReligionRandomizer(drawIndexes: const [2]);
    await pumpFixedGame(tester, randomizer: randomizer);
    await playFourChoices(tester);

    expect(find.text('本局信仰清單'), findsOneWidget);
    expect(find.text('抽出辯護立場'), findsOneWidget);
    expect(randomizer.drawCalls, 0);

    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(randomizer.drawCalls, 1);
    expect(find.text('豆花配糖水'), findsOneWidget);
    expect(find.text('只有糖水撐場，豆花不會太單調嗎？'), findsOneWidget);
    expect(find.text('抽出辯護立場'), findsNothing);
  });

  testWidgets('canceling exit keeps the current choices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _GameLauncher()));
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('北部粽派'));
    await tester.pump(FoodReligionGameSession.selectionFeedbackDuration);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('飲食抉擇 2/4'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定離開'));
    await tester.pumpAndSettle();
    expect(find.text('開始'), findsOneWidget);
  });

  test('the approved pool contains six distinct comparable pairs', () {
    expect(FoodReligionGameSession.choiceRoundCount, 4);
    expect(FoodFaithPair.pool, hasLength(6));
    expect(FoodFaithPair.pool.map((pair) => pair.topic).toSet(), hasLength(6));
    for (final pair in FoodFaithPair.pool) {
      expect(pair.left, isNot(pair.right));
    }
  });
}

class _GameLauncher extends StatelessWidget {
  const _GameLauncher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder:
                    (_) => FoodReligionGameScreen(
                      randomizer: FixedFoodReligionRandomizer(),
                    ),
              ),
            ),
        child: const Text('開始'),
      ),
    ),
  );
}
