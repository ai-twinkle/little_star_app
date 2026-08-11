import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_game_session.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';
import 'package:little_star_app/features/food_religion_war/widgets/food_religion_game_screen.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/ui/models/view_model/model_manager_viewmodel.dart';
import 'package:little_star_app/ui/models/widgets/model_manager_screen.dart';

import 'food_religion_test_support.dart';

void main() {
  testWidgets('missing-model reminder appears only once per app run', (
    tester,
  ) async {
    final runState = FoodReligionGameRunState();

    await _pumpGame(tester, runState: runState);

    expect(find.text('AI 評審還沒來報到'), findsOneWidget);
    expect(find.textContaining('不影響遊戲'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '先玩再說'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '前往推薦模型'), findsOneWidget);

    await tester.tap(find.text('先玩再說'));
    await tester.pumpAndSettle();
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpGame(tester, runState: runState);

    expect(find.text('AI 評審還沒來報到'), findsNothing);
    expect(find.text('飲食抉擇 1/4'), findsOneWidget);
  });

  testWidgets(
    'reminder opens the recommended-model area and returns in place',
    (tester) async {
      final service = _RediscoveringJudgmentService(
        discoveries: [const [], const []],
      );

      await _pumpGame(tester, service: service);
      await tester.tap(find.text('前往推薦模型'));
      await tester.pumpAndSettle();
      expect(find.text('推薦模型區'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(service.discoverCalls, 2);
      expect(find.text('飲食抉擇 1/4'), findsOneWidget);
      expect(find.text('AI 評審還沒來報到'), findsNothing);
    },
  );

  testWidgets(
    'model-manager round trip preserves the game and rediscovers models',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final service = _RediscoveringJudgmentService(
        discoveries: [
          const [],
          const [
            FoodReligionModel(
              label: 'GGUF · newly-installed.gguf',
              path: '/models/newly-installed.gguf',
              format: ModelFormat.gguf,
            ),
          ],
        ],
      );
      final modelManager = _ControllableSearchModelManagerViewModel();

      await _pumpGame(
        tester,
        service: service,
        recommendedModelsPageBuilder:
            (_) => ModelManagerScreen(
              viewModel: modelManager,
              initialSection: ModelManagerSection.recommendedModels,
            ),
      );
      await tester.tap(find.text('先玩再說'));
      await tester.pumpAndSettle();
      await playToDefense(tester);
      await tester.enterText(find.byType(TextField), '往返模型管理仍保留');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasPrimaryFocus,
        isTrue,
      );

      expect(find.text('前往推薦模型'), findsOneWidget);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('前往推薦模型'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Model Manager'), findsOneWidget);
      expect(find.text('Search GGUF models...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);

      modelManager.completeSearch();
      await tester.pumpAndSettle();
      expect(find.text('Recommended Models'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Popular Model 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Popular Model 8'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(service.discoverCalls, 2);
      expect(find.text('立場辯護'), findsOneWidget);
      expect(find.text('北部粽派（抽中）'), findsOneWidget);
      expect(find.text('GGUF · newly-installed.gguf'), findsOneWidget);
      expect(find.text('前往推薦模型'), findsOneWidget);
      expect(find.text('往返模型管理仍保留'), findsOneWidget);
    },
  );

  testWidgets(
    'failed download remains hidden and fallback completes the game',
    (tester) async {
      var downloadFailed = false;
      final service = _RediscoveringJudgmentService(
        discoveries: [const [], const []],
      );

      await _pumpGame(
        tester,
        service: service,
        recommendedModelsPageBuilder:
            (_) => _FakeRecommendedModelsPage(
              onDownloadFailed: () => downloadFailed = true,
            ),
      );
      await tester.tap(find.text('先玩再說'));
      await tester.pumpAndSettle();
      await playToDefense(tester);
      await tester.tap(find.text('前往推薦模型'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模擬下載失敗'));
      await tester.pump();
      expect(find.text('DOWNLOAD_FAILED E_MODEL_42'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(downloadFailed, isTrue);
      expect(find.textContaining('DOWNLOAD_FAILED'), findsNothing);
      expect(find.textContaining('E_MODEL_42'), findsNothing);
      await tester.enterText(find.byType(TextField), '沒有模型也能完成辯護');
      await tester.tap(find.text('送出辯護'));
      await tester.pump(FoodReligionGameSession.fallbackJudgmentDelay);

      expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
      expect(find.textContaining(RegExp('信仰堅定|勉強護教|叛教邊緣')), findsOneWidget);
    },
  );

  testWidgets('cancelled download still allows fallback completion', (
    tester,
  ) async {
    var downloadCancelled = false;
    final service = _RediscoveringJudgmentService(
      discoveries: [const [], const []],
    );

    await _pumpGame(
      tester,
      service: service,
      recommendedModelsPageBuilder:
          (_) => _FakeRecommendedModelsPage(
            onDownloadCancelled: () => downloadCancelled = true,
          ),
    );
    await tester.tap(find.text('先玩再說'));
    await tester.pumpAndSettle();
    await playToDefense(tester);
    await tester.tap(find.text('前往推薦模型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模擬取消下載'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(downloadCancelled, isTrue);
    await tester.enterText(find.byType(TextField), '取消下載也不影響辯護');
    await tester.tap(find.text('送出辯護'));
    await tester.pump(FoodReligionGameSession.fallbackJudgmentDelay);
    expect(find.textContaining('AI 主持人暫時離線'), findsOneWidget);
  });
}

Future<void> _pumpGame(
  WidgetTester tester, {
  FoodReligionGameRunState? runState,
  _RediscoveringJudgmentService? service,
  WidgetBuilder? recommendedModelsPageBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FoodReligionGameScreen(
        judgmentServiceFactory:
            () =>
                service ??
                _RediscoveringJudgmentService(discoveries: [const []]),
        randomizer: FixedFoodReligionRandomizer(),
        runState: runState,
        recommendedModelsPageBuilder:
            recommendedModelsPageBuilder ??
            (_) => const Scaffold(body: Center(child: Text('推薦模型區'))),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeRecommendedModelsPage extends StatefulWidget {
  const _FakeRecommendedModelsPage({
    this.onDownloadFailed,
    this.onDownloadCancelled,
  });

  final VoidCallback? onDownloadFailed;
  final VoidCallback? onDownloadCancelled;

  @override
  State<_FakeRecommendedModelsPage> createState() =>
      _FakeRecommendedModelsPageState();
}

class _FakeRecommendedModelsPageState
    extends State<_FakeRecommendedModelsPage> {
  String? _technicalError;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('推薦模型區')),
    body: Column(
      children: [
        if (widget.onDownloadFailed != null)
          FilledButton(
            onPressed: () {
              widget.onDownloadFailed!();
              setState(() => _technicalError = 'DOWNLOAD_FAILED E_MODEL_42');
            },
            child: const Text('模擬下載失敗'),
          ),
        if (widget.onDownloadCancelled != null)
          FilledButton(
            onPressed: widget.onDownloadCancelled,
            child: const Text('模擬取消下載'),
          ),
        if (_technicalError != null) Text(_technicalError!),
      ],
    ),
  );
}

class _RediscoveringJudgmentService implements FoodReligionJudgmentService {
  _RediscoveringJudgmentService({required this.discoveries});

  final List<Object> discoveries;
  int discoverCalls = 0;

  @override
  Future<List<FoodReligionModel>> discoverModels() async {
    final result =
        discoveries[(discoverCalls++).clamp(0, discoveries.length - 1)];
    if (result is Error) throw result;
    return result as List<FoodReligionModel>;
  }

  @override
  Future<FoodReligionJudgment> judge({
    required FoodReligionModel model,
    required FoodFaith stance,
    required FoodReligionDefense defense,
  }) => throw UnimplementedError();

  @override
  void cancel() {}

  @override
  void dispose() {}
}

class _ControllableSearchModelManagerViewModel extends ModelManagerViewModel {
  _ControllableSearchModelManagerViewModel()
    : super(
        hfService: HuggingFaceService(),
        downloadService: DownloadService(),
        downloadRepository: DownloadRepository(),
        directoryService: _EmptyDirectoryService(),
      );

  bool _isSearchPending = true;

  @override
  bool get isSearching => _isSearchPending;

  @override
  List<HFModelInfo> get searchResults => List.generate(
    8,
    (index) => HFModelInfo(
      id: 'example/popular-${index + 1}',
      author: 'example',
      modelName: 'Popular Model ${index + 1}',
      downloads: 1000 - index,
    ),
  );

  @override
  Future<void> init() async {}

  void completeSearch() {
    _isSearchPending = false;
    notifyListeners();
  }
}

class _EmptyDirectoryService implements DirectoryService {
  @override
  Future<int> getAvailableStorageSpace() async => 0;

  @override
  Future<Directory> getModelsDirectory() async => Directory.systemTemp;

  @override
  Future<List<String>> findFiles({
    required List<DirectoryType> directoryTypes,
    String? fileName,
    String? extension,
  }) async => const [];

  @override
  Future<Map<String, List<String>>> listDirectories({
    required List<DirectoryType> directoryTypes,
  }) async => const {};

  @override
  Future<bool> requestPermissions({required BuildContext context}) async =>
      false;
}
