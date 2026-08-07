import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';
import 'package:little_star_app/features/food_religion_war/services/food_religion_judgment_service.dart';

enum FoodReligionGameStage { choice, draw, defense, judging, result }

abstract class FoodReligionGameRandomizer {
  List<FoodFaithPair> selectRounds(List<FoodFaithPair> pool, int count);

  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid});
}

class DefaultFoodReligionGameRandomizer implements FoodReligionGameRandomizer {
  DefaultFoodReligionGameRandomizer({Random? random})
    : _random = random ?? Random();

  final Random _random;

  @override
  List<FoodFaithPair> selectRounds(List<FoodFaithPair> pool, int count) {
    final shuffled = [...pool]..shuffle(_random);
    return List.unmodifiable(shuffled.take(count));
  }

  @override
  FoodFaith draw(List<FoodFaith> candidates, {FoodFaith? avoid}) {
    final eligible =
        avoid != null && candidates.any((faith) => faith != avoid)
            ? candidates.where((faith) => faith != avoid).toList()
            : candidates;
    return eligible[_random.nextInt(eligible.length)];
  }
}

class FoodReligionGameSession extends ChangeNotifier {
  static const selectionFeedbackDuration = Duration(milliseconds: 800);
  static const fallbackJudgmentDelay = Duration(milliseconds: 500);
  static const choiceRoundCount = 4;

  FoodReligionGameSession({
    FoodReligionJudgmentService? judgmentService,
    FoodReligionGameRandomizer? randomizer,
    this.previousDrawnFaith,
  }) : _judgmentService =
           judgmentService ?? OnDeviceFoodReligionJudgmentService(),
       _randomizer = randomizer ?? DefaultFoodReligionGameRandomizer() {
    _rounds = _randomizer.selectRounds(FoodFaithPair.pool, choiceRoundCount);
    if (_rounds.length != choiceRoundCount ||
        _rounds.toSet().length != choiceRoundCount) {
      throw ArgumentError('A game requires four distinct choice rounds.');
    }
    _discovery = _discoverModels();
  }

  final FallbackJudgmentService _fallbackJudgmentService =
      FallbackJudgmentService();
  final FoodReligionJudgmentService _judgmentService;
  final FoodReligionGameRandomizer _randomizer;
  final FoodFaith? previousDrawnFaith;

  late final List<FoodFaithPair> _rounds;
  final List<FoodFaith> _beliefSlate = [];
  FoodReligionGameStage _stage = FoodReligionGameStage.choice;
  int _choiceIndex = 0;
  FoodFaith? _selectedFaith;
  FoodFaith? _drawnFaith;
  FoodReligionDefense? _defense;
  FoodReligionJudgment? _judgment;
  List<FoodReligionModel> _models = const [];
  FoodReligionModel? _selectedModel;
  bool _isDiscoveringModels = true;
  bool _isDisposed = false;
  Future<void>? _discovery;
  Timer? _transitionTimer;
  Timer? _judgmentTimer;

  FoodReligionGameStage get stage => _stage;
  int get choiceIndex => _choiceIndex;
  FoodFaithPair get currentRound => _rounds[_choiceIndex];
  List<FoodFaith> get contenders =>
      _stage == FoodReligionGameStage.choice ? currentRound.stances : const [];
  List<FoodFaith> get beliefSlate => List.unmodifiable(_beliefSlate);
  FoodFaith? get selectedFaith => _selectedFaith;
  FoodFaith? get drawnFaith => _drawnFaith;
  FoodReligionDefense? get defense => _defense;
  FoodReligionJudgment? get judgment => _judgment;
  List<FoodReligionModel> get models => _models;
  FoodReligionModel? get selectedModel => _selectedModel;
  bool get isDiscoveringModels => _isDiscoveringModels;
  bool get isSelectionLocked => _selectedFaith != null;

  String get progressLabel => switch (_stage) {
    FoodReligionGameStage.choice =>
      '飲食抉擇 ${_choiceIndex + 1}/$choiceRoundCount',
    FoodReligionGameStage.draw => '辯護抽籤',
    FoodReligionGameStage.defense => '立場辯護',
    FoodReligionGameStage.judging => '裁決中',
    FoodReligionGameStage.result => '裁決結果',
  };

  void select(FoodFaith faith) {
    if (_stage != FoodReligionGameStage.choice ||
        isSelectionLocked ||
        !contenders.contains(faith)) {
      return;
    }
    _selectedFaith = faith;
    _beliefSlate.add(faith);
    notifyListeners();

    final completedIndex = _choiceIndex;
    _transitionTimer = Timer(selectionFeedbackDuration, () {
      if (_isDisposed ||
          _stage != FoodReligionGameStage.choice ||
          _choiceIndex != completedIndex) {
        return;
      }
      if (_choiceIndex == choiceRoundCount - 1) {
        _stage = FoodReligionGameStage.draw;
      } else {
        _choiceIndex++;
      }
      _selectedFaith = null;
      notifyListeners();
    });
  }

  void drawDefense() {
    if (_stage != FoodReligionGameStage.draw || _drawnFaith != null) return;
    _drawnFaith = _randomizer.draw(_beliefSlate, avoid: previousDrawnFaith);
    if (!_beliefSlate.contains(_drawnFaith)) {
      throw StateError('The defense draw must come from the belief slate.');
    }
    _stage = FoodReligionGameStage.defense;
    notifyListeners();
  }

  void submitDefense(FoodReligionDefense defense) {
    if (_stage != FoodReligionGameStage.defense) return;
    _defense = defense;
    _stage = FoodReligionGameStage.judging;
    notifyListeners();

    _judgmentTimer = Timer(fallbackJudgmentDelay, () {
      if (_selectedModel == null || _isDiscoveringModels) {
        _completeJudgment(_fallbackJudgmentService.judge(_drawnFaith!));
      }
    });
    unawaited(_resolveJudgment());
  }

  void selectModel(FoodReligionModel? model) {
    if (_stage != FoodReligionGameStage.defense || model == null) return;
    if (!_models.any((candidate) => candidate.path == model.path)) return;
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> _discoverModels() async {
    List<FoodReligionModel> discovered;
    try {
      discovered = await _judgmentService.discoverModels();
    } catch (_) {
      discovered = const [];
    }
    if (_isDisposed) return;
    _models = List.unmodifiable(discovered);
    _selectedModel = _models.firstOrNull;
    _isDiscoveringModels = false;
    notifyListeners();
  }

  Future<void> _resolveJudgment() async {
    await _discovery;
    if (_isDisposed || _stage != FoodReligionGameStage.judging) return;
    final model = _selectedModel;
    if (model != null) {
      _judgmentTimer?.cancel();
      try {
        final result = await _judgmentService.judge(
          model: model,
          stance: _drawnFaith!,
          defense: _defense!,
        );
        _completeJudgment(result);
      } catch (_) {
        _completeJudgment(_fallbackJudgmentService.judge(_drawnFaith!));
      }
    }
  }

  void _completeJudgment(FoodReligionJudgment judgment) {
    if (_isDisposed || _stage != FoodReligionGameStage.judging) return;
    _judgmentTimer?.cancel();
    _judgment = judgment;
    _stage = FoodReligionGameStage.result;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _transitionTimer?.cancel();
    _judgmentTimer?.cancel();
    _judgmentService.dispose();
    super.dispose();
  }
}
