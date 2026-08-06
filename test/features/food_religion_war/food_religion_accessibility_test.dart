import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';

void main() {
  testWidgets(
    'compact phone keeps both contenders reachable without overflow',
    (tester) async {
      await _setViewport(tester, const Size(320, 568));
      await tester.pumpWidget(
        const MaterialApp(home: FoodReligionGameScreen()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('準決賽 1/2'), findsOneWidget);
      expect(find.text('北部粽派'), findsOneWidget);
      expect(find.text('南部粽派'), findsOneWidget);

      await tester.ensureVisible(find.text('南部粽派'));
      await tester.tap(find.text('南部粽派'));
      await tester.pump();

      expect(find.text('南部粽派晉級！'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const [Size(320, 568), Size(430, 932)]) {
    testWidgets('${viewport.width.toInt()} px phone can complete every stage', (
      tester,
    ) async {
      await _setViewport(tester, viewport);
      await tester.pumpWidget(
        const MaterialApp(home: FoodReligionGameScreen()),
      );

      await _tapReachable(tester, '北部粽派');
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);

      await _tapReachable(tester, '香菜加爆派');
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);

      await _tapReachable(tester, '北部粽派');
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
      await _tapReachable(tester, '送出辯護');
      expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('回首頁'));
      expect(find.text('再玩一次'), findsOneWidget);
      expect(find.text('回首頁'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keyboard leaves the fixed question, count, and submit reachable',
    (tester) async {
      await _setViewport(tester, const Size(320, 568));
      await tester.pumpWidget(
        const MaterialApp(home: FoodReligionGameScreen()),
      );
      await _playToDefense(tester);

      await tester.enterText(
        find.byType(TextField),
        List.filled(50, '粽').join(),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      expect(find.text('北部粽不就是包在粽葉裡的油飯嗎？'), findsOneWidget);
      expect(find.text('50 / 50'), findsOneWidget);
      await tester.dragFrom(const Offset(160, 260), const Offset(0, -300));
      await tester.pump();

      final submitRect = tester.getRect(find.text('送出辯護'));
      expect(submitRect.bottom, lessThanOrEqualTo(568 - 280));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('screen reader receives progress, state, and outcome semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: FoodReligionGameScreen()));

    expect(find.bySemanticsLabel('對戰進度：準決賽 1/2'), findsOneWidget);
    final northern = find.bySemanticsLabel('北部粽派，未選擇');
    expect(northern, findsOneWidget);
    expect(tester.getSemantics(northern).rect.height, greaterThanOrEqualTo(48));

    await tester.tap(northern);
    await tester.pump();
    expect(find.bySemanticsLabel('北部粽派，已選擇並晉級，已鎖定'), findsOneWidget);
    expect(find.bySemanticsLabel('南部粽派，已鎖定'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.bySemanticsLabel('香菜加爆派，未選擇'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.bySemanticsLabel('北部粽派，未選擇'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.bySemanticsLabel('固定質疑：北部粽不就是包在粽葉裡的油飯嗎？'), findsOneWidget);
    expect(find.bySemanticsLabel('字數：0 / 50'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.bySemanticsLabel('錯誤：請輸入 1～50 字的辯護'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.bySemanticsLabel('等待裁決：AI 鄉民評審正在審判…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel(RegExp('^判決：')), findsOneWidget);
    expect(
      find.bySemanticsLabel('備援提示：AI 主持人暫時離線，改由備援鄉民評審裁決！'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('再玩一次'), findsOneWidget);
    expect(find.bySemanticsLabel('回首頁'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('再玩一次'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('對戰進度：準決賽 1/2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^判決：')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^備援提示：')), findsNothing);
    semantics.dispose();
  });

  testWidgets('system Back confirms exit throughout the game states', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodReligionGameScreen()));

    await _cancelSystemBack(tester);
    expect(find.text('準決賽 1/2'), findsOneWidget);

    await _playToDefense(tester);
    await _cancelSystemBack(tester);
    expect(find.text('送出辯護'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    await _cancelSystemBack(tester);
    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('再玩一次'), findsOneWidget);
    await _cancelSystemBack(tester);
    expect(find.text('再玩一次'), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _tapReachable(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _playToDefense(WidgetTester tester) async {
  await _tapReachable(tester, '北部粽派');
  await tester.pump(const Duration(milliseconds: 800));
  await _tapReachable(tester, '香菜加爆派');
  await tester.pump(const Duration(milliseconds: 800));
  await _tapReachable(tester, '北部粽派');
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _cancelSystemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.text('確定離開本局？'), findsOneWidget);
  await tester.tap(find.text('取消'));
  await tester.pump(const Duration(milliseconds: 200));
}
