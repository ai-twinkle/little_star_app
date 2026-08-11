import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('Variant A arena chrome frames the phone choice flow', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await pumpFixedGame(tester);
    await dismissMissingModelReminder(tester);

    expect(find.byKey(const ValueKey('night-market-arena')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-marquee')), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsNWidgets(2));
    expect(find.byKey(const ValueKey('red-choice-seat')), findsOneWidget);
    expect(find.byKey(const ValueKey('cyan-choice-seat')), findsOneWidget);
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide arena presents the same choice task side by side', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    await pumpFixedGame(tester);
    await dismissMissingModelReminder(tester);

    final northern = tester.getRect(find.text('北部粽派'));
    final southern = tester.getRect(find.text('南部粽派'));
    expect((northern.center.dy - southern.center.dy).abs(), lessThan(20));
    expect(northern.center.dx, lessThan(southern.center.dx));
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide draw, defense, and result keep task and context columns', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 900));
    await pumpFixedGame(tester);
    await playFourChoices(tester);

    expect(
      tester.getCenter(find.text('本局信仰清單')).dx,
      lessThan(tester.getCenter(find.text('現在抽出辯護立場')).dx),
    );
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(
      tester.getCenter(find.text('本次抽中')).dx,
      lessThan(tester.getCenter(find.text('本局信仰清單')).dx),
    );

    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.getCenter(find.text('本次抽中')).dx,
      lessThan(tester.getCenter(find.text('本局信仰清單')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps locked feedback static and explicit', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _setViewport(tester, const Size(430, 932));
    await pumpFixedGame(tester);
    await dismissMissingModelReminder(tester);

    await tester.tap(find.text('北部粽派'));
    await tester.pump();

    expect(find.text('立場已記錄'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final animations = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(animations, isNotEmpty);
    expect(
      animations.every((animation) => animation.duration == Duration.zero),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion replaces judging movement with a static marker', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _setViewport(tester, const Size(430, 932));
    await pumpFixedGame(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');

    await tester.tap(find.text('送出辯護'));
    await tester.pump();

    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AI 鄉民評審正在審判…'), findsOneWidget);
  });

  testWidgets('reduced motion preserves draw and result state', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _setViewport(tester, const Size(430, 932));
    await pumpFixedGame(tester);
    await playFourChoices(tester);

    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(find.text('本次抽中'), findsOneWidget);
    expect(find.text('北部粽派（抽中）'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pump();
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel(RegExp('^判決：')), findsOneWidget);
    expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
    expect(find.text('再玩一次'), findsOneWidget);
    expect(find.text('回首頁'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arena styling persists through draw, defense, and result', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await pumpFixedGame(tester);
    await playFourChoices(tester);

    expect(find.text('本局信仰清單'), findsOneWidget);
    expect(find.byKey(const ValueKey('night-market-arena')), findsOneWidget);
    await tester.tap(find.text('抽出辯護立場'));
    await tester.pump();
    expect(find.text('本次抽中'), findsOneWidget);
    expect(find.byKey(const ValueKey('night-market-arena')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('本次抽中；四個選擇都會保留。'), findsOneWidget);
    expect(find.byKey(const ValueKey('night-market-arena')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result arrival provides short native feedback', (tester) async {
    final platformCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpFixedGame(tester);
    await playToDefense(tester);
    await tester.enterText(find.byType(TextField), '粽葉香氣就是無法取代');

    await tester.tap(find.text('送出辯護'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having((call) => call.method, 'method', 'HapticFeedback.vibrate')
            .having(
              (call) => call.arguments,
              'arguments',
              'HapticFeedbackType.mediumImpact',
            ),
      ),
    );
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
