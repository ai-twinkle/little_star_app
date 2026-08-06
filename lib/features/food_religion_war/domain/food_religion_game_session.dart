import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';

enum FoodReligionGameStage {
  semifinalZongzi,
  semifinalCilantro,
  finalMatch,
  defense,
}

class FoodReligionGameSession extends ChangeNotifier {
  static const selectionFeedbackDuration = Duration(milliseconds: 800);

  FoodReligionGameStage _stage = FoodReligionGameStage.semifinalZongzi;
  FoodFaith? _selectedFaith;
  FoodFaith? _zongziWinner;
  FoodFaith? _cilantroWinner;
  FoodFaith? _champion;
  Timer? _transitionTimer;

  FoodReligionGameStage get stage => _stage;
  FoodFaith? get selectedFaith => _selectedFaith;
  FoodFaith? get champion => _champion;
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
    FoodReligionGameStage.defense => const [],
  };

  String get progressLabel => switch (_stage) {
    FoodReligionGameStage.semifinalZongzi => '準決賽 1/2',
    FoodReligionGameStage.semifinalCilantro => '準決賽 2/2',
    FoodReligionGameStage.finalMatch => '決賽',
    FoodReligionGameStage.defense => '終極辯護',
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
      };
      _selectedFaith = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }
}
