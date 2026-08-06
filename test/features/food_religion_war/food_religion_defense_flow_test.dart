import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

void main() {
  testWidgets('辯護輸入依使用者可見字元驗證 1 到 50 字', (tester) async {
    await _reachDefense(tester);

    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('北部粽不就是包在粽葉裡的油飯嗎？'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('0 / 50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.text('請輸入 1～50 字的辯護'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '👨‍👩‍👧‍👦');
    await tester.pump();
    expect(find.text('1 / 50'), findsOneWidget);
    expect(find.text('請輸入 1～50 字的辯護'), findsNothing);

    await tester.enterText(find.byType(TextField), List.filled(50, '粽').join());
    await tester.pump();
    expect(find.text('50 / 50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), List.filled(51, '粽').join());
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.text('51 / 50'), findsOneWidget);
    expect(find.text('最多只能輸入 50 字'), findsOneWidget);
    expect(find.text('AI 鄉民評審正在審判…'), findsNothing);
  });

  for (final defense in ['粽', List.filled(50, '粽').join()]) {
    testWidgets('${defense.length} 個可見字元可完成備援裁決', (tester) async {
      await _reachDefense(tester);
      await tester.enterText(find.byType(TextField), defense);
      await tester.tap(find.text('送出辯護'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('AI 主持人暫時離線，改由備援鄉民評審裁決！'), findsOneWidget);
    });
  }

  testWidgets('有效辯護只提交一次並顯示冠軍專屬備援結果', (tester) async {
    await _reachDefense(tester);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');

    await tester.tap(find.text('送出辯護'));
    await tester.tap(find.text('送出辯護'));
    await tester.pump();

    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('AI 主持人暫時離線，改由備援鄉民評審裁決！'), findsOneWidget);
    expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
    expect(find.textContaining(RegExp('北粽|粽葉|油飯')), findsOneWidget);
    expect(find.text('粽葉香氣就是無法取代'), findsNothing);
  });

  testWidgets('再玩一次會清除本局並回到第一場', (tester) async {
    await _reachDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('再玩一次'), findsOneWidget);
    expect(find.text('回首頁'), findsOneWidget);
    expect(find.text('送出辯護'), findsNothing);

    await tester.tap(find.text('再玩一次'));
    await tester.pumpAndSettle();

    expect(find.text('準決賽 1/2'), findsOneWidget);
    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('南部粽派'), findsOneWidget);
    expect(find.text('北粽就是香'), findsNothing);
    expect(find.text('AI 主持人暫時離線，改由備援鄉民評審裁決！'), findsNothing);
  });

  testWidgets('回首頁會清除本局且再次進入從第一場開始', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await _playToDefense(tester);
    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('回首頁'));
    await tester.pumpAndSettle();

    expect(find.text('台灣食物宗教戰爭'), findsOneWidget);
    expect(find.text('AI 主持人暫時離線，改由備援鄉民評審裁決！'), findsNothing);

    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    expect(find.text('準決賽 1/2'), findsOneWidget);
  });

  for (final path in const [
    (
      zongzi: '北部粽派',
      cilantro: '香菜加爆派',
      champion: '北部粽派',
      roasts: ['油飯只是外表，粽葉才是北粽的戰袍！', '這理由有拌到油，還沒包進粽葉。', '北粽都站穩了，你的論點還在油飯上打滑。'],
    ),
    (
      zongzi: '南部粽派',
      cilantro: '香菜加爆派',
      champion: '南部粽派',
      roasts: ['水煮不是退讓，是南粽糯米的內功修煉！', '粽葉都聽懂了，南粽糯米還在想。', '南粽還在鍋裡撐著，你的理由先散開了。'],
    ),
    (
      zongzi: '北部粽派',
      cilantro: '香菜加爆派',
      champion: '香菜加爆派',
      roasts: ['這把香菜撒得夠高，評審席都綠了！', '香菜有加爆，論點只加了一小撮。', '香菜堆成山，你的理由卻只剩一片葉。'],
    ),
    (
      zongzi: '北部粽派',
      cilantro: '香菜退散派',
      champion: '香菜退散派',
      roasts: ['防香菜裝備完整，連一片葉子都過不了！', '香菜是退了，你的理由也差點退場。', '嘴上說退散，論點卻替香菜留了後門。'],
    ),
  ]) {
    testWidgets('${path.champion}會使用自己的安全備援文案池', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FoodReligionGameScreen()),
      );
      await _playToDefense(
        tester,
        zongzi: path.zongzi,
        cilantro: path.cilantro,
        champion: path.champion,
      );
      await tester.enterText(find.byType(TextField), '我支持這個冠軍');
      await tester.tap(find.text('送出辯護'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(path.champion), findsOneWidget);
      expect(
        path.roasts.any((roast) => find.text(roast).evaluate().isNotEmpty),
        isTrue,
      );
      expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
    });
  }
}

Future<void> _reachDefense(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: FoodReligionGameScreen()));
  await _playToDefense(tester);
}

Future<void> _playToDefense(
  WidgetTester tester, {
  String zongzi = '北部粽派',
  String cilantro = '香菜加爆派',
  String champion = '北部粽派',
}) async {
  await tester.tap(find.text(zongzi));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.text(cilantro));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.tap(find.text(champion));
  await tester.pump(const Duration(milliseconds: 800));
}
