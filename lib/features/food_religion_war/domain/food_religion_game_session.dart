import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_defense.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_religion_judgment.dart';

enum FoodReligionGameStage {
  semifinalZongzi,
  semifinalCilantro,
  finalMatch,
  defense,
  judging,
  result,
}

class FoodReligionGameSession extends ChangeNotifier {
  static const selectionFeedbackDuration = Duration(milliseconds: 800);
  static const fallbackJudgmentDelay = Duration(milliseconds: 500);

  final FallbackJudgmentService _fallbackJudgmentService =
      FallbackJudgmentService();

  FoodReligionGameStage _stage = FoodReligionGameStage.semifinalZongzi;
  FoodFaith? _selectedFaith;
  FoodFaith? _zongziWinner;
  FoodFaith? _cilantroWinner;
  FoodFaith? _champion;
  FoodReligionDefense? _defense;
  FoodReligionJudgment? _judgment;
  Timer? _transitionTimer;
  Timer? _judgmentTimer;

  FoodReligionGameStage get stage => _stage;
  FoodFaith? get selectedFaith => _selectedFaith;
  FoodFaith? get champion => _champion;
  FoodReligionDefense? get defense => _defense;
  FoodReligionJudgment? get judgment => _judgment;
  bool get isSelectionLocked => _selectedFaith != null;

  List<FoodFaith> get contenders => switch (_stage) {
    FoodReligionGameStage.semifinalZongzi => const [
      FoodFaith.northernZongzi,
      FoodFaith.southernZongzi,
    ],
    FoodReligionGameStage.semifinalCilantro => const [
      FoodFaith.extraCilantro,
      FoodFaith.noCilantro,
    ],
    FoodReligionGameStage.finalMatch => [_zongziWinner!, _cilantroWinner!],
    FoodReligionGameStage.defense ||
    FoodReligionGameStage.judging ||
    FoodReligionGameStage.result => const [],
  };

  String get progressLabel => switch (_stage) {
    FoodReligionGameStage.semifinalZongzi => '準決賽 1/2',
    FoodReligionGameStage.semifinalCilantro => '準決賽 2/2',
    FoodReligionGameStage.finalMatch => '決賽',
    FoodReligionGameStage.defense => '終極辯護',
    FoodReligionGameStage.judging => '裁決中',
    FoodReligionGameStage.result => '裁決結果',
  };

  void select(FoodFaith faith) {
    if (isSelectionLocked || !contenders.contains(faith)) return;

    _selectedFaith = faith;
    switch (_stage) {
      case FoodReligionGameStage.semifinalZongzi:
        _zongziWinner = faith;
      case FoodReligionGameStage.semifinalCilantro:
        _cilantroWinner = faith;
      case FoodReligionGameStage.finalMatch:
        _champion = faith;
      case FoodReligionGameStage.defense:
      case FoodReligionGameStage.judging:
      case FoodReligionGameStage.result:
        return;
    }
    notifyListeners();

    final completedStage = _stage;
    _transitionTimer = Timer(selectionFeedbackDuration, () {
      if (_stage != completedStage) return;
      _stage = switch (completedStage) {
        FoodReligionGameStage.semifinalZongzi =>
          FoodReligionGameStage.semifinalCilantro,
        FoodReligionGameStage.semifinalCilantro =>
          FoodReligionGameStage.finalMatch,
        FoodReligionGameStage.finalMatch => FoodReligionGameStage.defense,
        FoodReligionGameStage.defense => FoodReligionGameStage.defense,
        FoodReligionGameStage.judging => FoodReligionGameStage.judging,
        FoodReligionGameStage.result => FoodReligionGameStage.result,
      };
      _selectedFaith = null;
      notifyListeners();
    });
  }

  void submitDefense(FoodReligionDefense defense) {
    if (_stage != FoodReligionGameStage.defense) return;

    _defense = defense;
    _stage = FoodReligionGameStage.judging;
    notifyListeners();

    _judgmentTimer = Timer(fallbackJudgmentDelay, () {
      if (_stage != FoodReligionGameStage.judging) return;
      _judgment = _fallbackJudgmentService.judge(_champion!);
      _stage = FoodReligionGameStage.result;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _judgmentTimer?.cancel();
    super.dispose();
  }
}
