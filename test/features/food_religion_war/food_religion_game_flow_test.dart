import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';

void main() {
  testWidgets('玩家從 Home 卡片直接進入第一場粽子準決賽', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );

    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();

    expect(find.text('準決賽 1/2'), findsOneWidget);
    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('南部粽派'), findsOneWidget);
    expect(find.text('點擊你支持的飲食信仰'), findsOneWidget);
  });

  testWidgets('每場只接受第一個選擇並在 800 ms 後前進', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('北部粽派'));
    await tester.tap(find.text('南部粽派'));
    await tester.pump(const Duration(milliseconds: 799));

    expect(find.text('準決賽 1/2'), findsOneWidget);
    expect(find.text('香菜加爆派'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('準決賽 2/2'), findsOneWidget);
    expect(find.text('香菜加爆派'), findsOneWidget);
    expect(find.text('香菜退散派'), findsOneWidget);

    await tester.tap(find.text('香菜加爆派'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('南部粽派'), findsNothing);
  });

  testWidgets('兩場準決賽勝方進入決賽並產生正確冠軍質疑', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('北部粽派'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('香菜加爆派'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('決賽'), findsOneWidget);
    expect(find.text('北部粽派'), findsOneWidget);
    expect(find.text('香菜加爆派'), findsOneWidget);
    expect(find.text('南部粽派'), findsNothing);
    expect(find.text('香菜退散派'), findsNothing);

    await tester.tap(find.text('香菜加爆派'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('你的終極飲食信仰'), findsOneWidget);
    expect(find.text('香菜加爆派'), findsOneWidget);
    expect(find.text('香菜味不會把整道料理都蓋掉嗎？'), findsOneWidget);
  });

  testWidgets('離開需確認，取消保留進度而確認會清除本局', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
    );
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('北部粽派'));
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('確定離開本局？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('準決賽 2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定離開'));
    await tester.pumpAndSettle();

    expect(find.text('台灣食物宗教戰爭'), findsOneWidget);
    await tester.tap(find.text('台灣食物宗教戰爭'));
    await tester.pumpAndSettle();
    expect(find.text('準決賽 1/2'), findsOneWidget);
  });

  for (final path in const [
    (
      zongzi: '北部粽派',
      cilantro: '香菜加爆派',
      champion: '北部粽派',
      challenge: '北部粽不就是包在粽葉裡的油飯嗎？',
    ),
    (
      zongzi: '南部粽派',
      cilantro: '香菜加爆派',
      champion: '南部粽派',
      challenge: '南部粽不就是水煮糯米糰嗎？',
    ),
    (
      zongzi: '北部粽派',
      cilantro: '香菜退散派',
      champion: '香菜退散派',
      challenge: '少了香菜，這道料理還有靈魂嗎？',
    ),
  ]) {
    testWidgets('${path.champion}冠軍會顯示對應的終極質疑', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: FoodReligionGameHomeCard())),
      );
      await tester.tap(find.text('台灣食物宗教戰爭'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(path.zongzi));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text(path.cilantro));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text(path.champion));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text(path.champion), findsOneWidget);
      expect(find.text(path.challenge), findsOneWidget);
    });
  }
}
