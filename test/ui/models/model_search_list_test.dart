import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/ui/models/widgets/model_search_list.dart';

void main() {
  testWidgets('search results below the fold are built only once scrolled to', (
    tester,
  ) async {
    await _pumpSearchList(tester, [
      for (var index = 0; index < 40; index++) _model(index),
    ]);

    expect(find.text('model-00'), findsOneWidget);
    expect(find.text('model-39'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pump();

    expect(find.text('model-39'), findsOneWidget);
  });

  testWidgets('an empty search says so', (tester) async {
    await _pumpSearchList(tester, const []);

    expect(find.text('找不到模型'), findsOneWidget);
  });

  testWidgets('tapping a result selects that model', (tester) async {
    final selected = <String>[];
    await _pumpSearchList(tester, [
      _model(0),
      _model(1),
    ], onSelect: (model) => selected.add(model.id));

    await tester.tap(find.text('model-01'));

    expect(selected, ['author/model-01']);
  });
}

HFModelInfo _model(int index) {
  final name = 'model-${index.toString().padLeft(2, '0')}';
  return HFModelInfo(id: 'author/$name', author: 'author', modelName: name);
}

Future<void> _pumpSearchList(
  WidgetTester tester,
  List<HFModelInfo> models, {
  void Function(HFModelInfo)? onSelect,
}) async {
  // A phone-sized viewport: the whole result list cannot fit on screen.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            ModelSearchList(models: models, onSelect: onSelect ?? (_) {}),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}
