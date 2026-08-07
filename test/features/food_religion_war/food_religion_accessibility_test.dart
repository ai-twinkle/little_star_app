import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('compact phone keeps each choice reachable without overflow', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 568));
    await pumpFixedGame(tester);
    await tester.pump();
    await dismissMissingModelReminder(tester);

    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    await tester.ensureVisible(find.text('南部粽派'));
    await tester.tap(find.text('南部粽派'));
    await tester.pump();

    expect(find.text('立場已記錄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone can complete the fallback flow', (tester) async {
    await _setViewport(tester, const Size(320, 568));
    await pumpFixedGame(tester);
    await tester.pump();
    await dismissMissingModelReminder(tester);

    await _playReachableChoices(tester);
    await tapReachable(tester, '抽出辯護立場');
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tapReachable(tester, '送出辯護');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.text('回首頁'));
    expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
    expect(find.text('再玩一次'), findsOneWidget);
    expect(find.text('回首頁'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(430, 932),
    Size(480, 960),
    Size(1280, 900),
  ]) {
    testWidgets('${viewport.width.toInt()} px viewport completes every stage', (
      tester,
    ) async {
      await _setViewport(tester, viewport);
      await pumpFixedGame(tester);
      await tester.pump();
      await dismissMissingModelReminder(tester);

      await _playReachableChoices(tester);
      await tapReachable(tester, '抽出辯護立場');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
      await tapReachable(tester, '送出辯護');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.ensureVisible(find.text('回首頁'));
      expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
      expect(find.text('再玩一次'), findsOneWidget);
      expect(find.text('回首頁'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard keeps a 50-character defense flow reachable', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 568));
    await pumpFixedGame(tester);
    await tester.pump();
    await dismissMissingModelReminder(tester);
    await _playReachableChoices(tester);
    await tapReachable(tester, '抽出辯護立場');
    await tester.enterText(find.byType(TextField), List.filled(50, '粽').join());
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final visibleBottom = 568 - 280;

    for (final label in const [
      '北部粽不就是包在粽葉裡的油飯嗎？',
      '50 / 50',
      '目前沒有已安裝模型，送出後將使用備援裁決。',
      '前往推薦模型',
      '送出辯護',
    ]) {
      final target = find.text(label);
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.pump();
      final targetRect = tester.getRect(target);
      expect(targetRect.top, greaterThanOrEqualTo(0));
      expect(targetRect.bottom, lessThanOrEqualTo(visibleBottom));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('large text keeps the semantic task order reachable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _setViewport(tester, const Size(320, 568));
    final semantics = tester.ensureSemantics();
    await pumpFixedGame(tester);
    await tester.pump();
    await dismissMissingModelReminder(tester);

    expect(find.bySemanticsLabel('台灣食物宗教戰爭'), findsOneWidget);
    expect(find.bySemanticsLabel('遊戲進度：飲食抉擇 1/4'), findsOneWidget);
    expect(find.bySemanticsLabel('北部粽派，未選擇'), findsOneWidget);
    await _playReachableChoices(tester);
    expect(find.bySemanticsLabel('遊戲進度：辯護抽籤'), findsOneWidget);
    expect(find.bySemanticsLabel('本局信仰清單'), findsOneWidget);
    await tapReachable(tester, '抽出辯護立場');
    expect(find.bySemanticsLabel(RegExp('^固定質疑：')), findsOneWidget);
    expect(find.bySemanticsLabel('字數：0 / 50'), findsOneWidget);
    await tester.ensureVisible(find.text('前往推薦模型'));
    await tester.enterText(find.byType(TextField), '北粽就是香');
    await tapReachable(tester, '送出辯護');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.bySemanticsLabel('遊戲進度：裁決結果'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^判決：')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^備援提示：')), findsOneWidget);
    await tester.ensureVisible(find.text('再玩一次'));
    await tester.ensureVisible(find.text('回首頁'));
    expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('screen reader receives choice, draw, and result semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFixedGame(tester);
    await tester.pump();
    await dismissMissingModelReminder(tester);

    expect(
      _traversalLabels(tester),
      containsAllInOrder(['台灣食物宗教戰爭', '遊戲進度：飲食抉擇 1/4', '北部粽派，未選擇', '南部粽派，未選擇']),
    );
    expect(find.bySemanticsLabel('遊戲進度：飲食抉擇 1/4'), findsOneWidget);
    final northern = find.bySemanticsLabel('北部粽派，未選擇');
    expect(northern, findsOneWidget);
    expect(tester.getSemantics(northern).rect.height, greaterThanOrEqualTo(48));
    await tester.tap(northern);
    await tester.pump();
    expect(find.bySemanticsLabel('北部粽派，立場已記錄，已鎖定'), findsOneWidget);
    expect(find.bySemanticsLabel('南部粽派，已鎖定'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    for (final choice in const ['香菜退散派', '豆花配糖水', '火鍋原湯派']) {
      await tester.tap(find.text(choice));
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(find.bySemanticsLabel('遊戲進度：辯護抽籤'), findsOneWidget);
    expect(tester.getSemantics(find.text('北部粽派')).label, '北部粽派');
    expect(
      _traversalLabels(tester),
      containsAllInOrder([
        '遊戲進度：辯護抽籤',
        '本局信仰清單',
        '北部粽派',
        '香菜退散派',
        '豆花配糖水',
        '火鍋原湯派',
        '抽出辯護立場',
      ]),
    );
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(find.bySemanticsLabel('本次抽中'), findsOneWidget);
    expect(find.bySemanticsLabel('固定質疑：北部粽不就是包在粽葉裡的油飯嗎？'), findsOneWidget);
    expect(find.bySemanticsLabel('字數：0 / 50'), findsOneWidget);
    expect(find.bySemanticsLabel('目前沒有已安裝模型，送出後將使用備援裁決。'), findsOneWidget);
    expect(
      _traversalLabels(tester),
      containsAllInOrder([
        '遊戲進度：立場辯護',
        '本次抽中',
        '固定質疑：北部粽不就是包在粽葉裡的油飯嗎？',
        '你的辯護',
        '字數：0 / 50',
        '送出辯護',
        '本局信仰清單',
        '目前沒有已安裝模型，送出後將使用備援裁決。',
        '前往推薦模型',
      ]),
    );

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
    expect(find.bySemanticsLabel(RegExp('^備援提示：')), findsOneWidget);
    expect(find.bySemanticsLabel('再玩一次'), findsOneWidget);
    expect(find.bySemanticsLabel('回首頁'), findsOneWidget);
    expect(
      _traversalLabels(tester),
      containsAllInOrder([
        '遊戲進度：裁決結果',
        '本次抽中',
        '固定質疑：北部粽不就是包在粽葉裡的油飯嗎？',
        '判決：信仰堅定',
        '備援提示：AI 主持人暫時離線，改由備援鄉民評審裁決！',
        '再玩一次',
        '回首頁',
        '本次抽中；四個選擇都會保留。',
        '本局信仰清單',
      ]),
    );

    await tapReachable(tester, '再玩一次');
    expect(find.bySemanticsLabel('遊戲進度：飲食抉擇 1/4'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^判決：')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^備援提示：')), findsNothing);
    semantics.dispose();
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _playReachableChoices(WidgetTester tester) async {
  for (final choice in const ['北部粽派', '香菜退散派', '豆花配糖水', '火鍋原湯派']) {
    await tapReachable(tester, choice);
    await tester.pump(const Duration(milliseconds: 800));
  }
}

List<String> _traversalLabels(WidgetTester tester) =>
    tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.getSemanticsData().label)
        .where((label) => label.isNotEmpty)
        .toList();
