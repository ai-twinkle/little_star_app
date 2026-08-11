import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_home_card.dart';

import 'food_religion_test_support.dart';

/// Surfaces opened in the [Overlay] build their own [Material] outside the
/// arena page tree, so the page-level checks in
/// `food_religion_readability_test.dart` cannot see them. These tests sample
/// the pixels the player actually looks at instead.
void main() {
  testWidgets('Expanded judgment model menu renders readable options', (
    tester,
  ) async {
    await _pumpGameToDefense(tester);
    await ensureReachableWithin(tester, find.text('GGUF · judge.gguf'));

    await tester.tap(find.text('GGUF · judge.gguf'));
    await tester.pumpAndSettle();

    // The unselected option is the one that disappeared into the arena
    // background on device; the selected one only survived thanks to its
    // highlight.
    await _expectArenaTextIsReadable(tester, 'MLX · judge-mlx');
    await _expectArenaTextIsReadable(tester, 'GGUF · judge.gguf');
  });

  testWidgets('Exit confirmation dialog renders readable text', (tester) async {
    await _pumpGameToDefense(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _expectArenaTextIsReadable(tester, '確定離開本局？');
    await _expectArenaTextIsReadable(tester, '離開後，本局進度將會清除。');
    await _expectArenaTextIsReadable(tester, '取消');
  });

  testWidgets('Missing model reminder dialog renders readable text', (
    tester,
  ) async {
    await _pumpGameFromHome(
      tester,
      judgmentServiceFactory: NoModelJudgmentService.new,
    );
    await tester.pumpAndSettle();

    await _expectArenaTextIsReadable(tester, 'AI 評審還沒來報到');
    await _expectArenaTextIsReadable(tester, '目前沒有可用模型，但不影響遊戲；你仍可完成整局並取得備援裁決。');
    await _expectArenaTextIsReadable(tester, '前往推薦模型');
  });
}

const _rootKey = ValueKey<String>('readability-capture-root');

Future<void> _pumpGameFromHome(
  WidgetTester tester, {
  required FoodReligionJudgmentService Function() judgmentServiceFactory,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: MaterialApp(
        home: Scaffold(
          body: FoodReligionGameHomeCard(
            judgmentServiceFactory: judgmentServiceFactory,
            randomizer: FixedFoodReligionRandomizer(),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('台灣食物宗教戰爭'));
  await tester.pumpAndSettle();
}

Future<void> _pumpGameToDefense(WidgetTester tester) async {
  await _pumpGameFromHome(
    tester,
    judgmentServiceFactory: InstalledModelJudgmentService.new,
  );
  await playToDefense(tester);
  await tester.pumpAndSettle();
}

/// Asserts that [label], as actually painted on screen, sits on a dark arena
/// surface and clears the WCAG 4.5:1 bar for normal text against it.
///
/// The surface is sampled from just beside the glyphs rather than guessed from
/// pixel frequency, so the glyph colour is unambiguous however much of the text
/// rect the glyphs happen to cover.
Future<void> _expectArenaTextIsReadable(
  WidgetTester tester,
  String label,
) async {
  final target = find.text(label).hitTestable();
  expect(target, findsOneWidget, reason: 'No visible "$label"');
  final rect = tester.getRect(target);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_rootKey),
  );
  late final int width;
  ByteData? pixels;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
  });
  final data = pixels!;

  Color pixelAt(int x, int y) {
    final offset = (y * width + x) * 4;
    expect(
      offset >= 0 && offset + 3 < data.lengthInBytes,
      isTrue,
      reason: 'Sampled "$label" outside the captured frame',
    );
    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  // A few pixels left of the text is still inside the menu item's or dialog's
  // own padding, so it is the surface the player reads the glyphs against.
  final surface = pixelAt(rect.left.floor() - 3, rect.center.dy.round());

  final glyphCounts = <int, int>{};
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
      final pixel = pixelAt(x, y);
      if (pixel == surface) continue;
      glyphCounts.update(
        pixel.toARGB32(),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }
  expect(glyphCounts, isNotEmpty, reason: 'Nothing was painted for "$label"');
  final glyph = Color(
    (glyphCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key,
  );

  expect(
    surface.computeLuminance(),
    lessThan(0.2),
    reason: 'Expected "$label" on a dark arena surface, got $surface',
  );
  expect(
    contrastRatio(glyph, surface),
    greaterThanOrEqualTo(minimumNormalTextContrast),
    reason: 'Rendered "$label" as $glyph against $surface',
  );
}
