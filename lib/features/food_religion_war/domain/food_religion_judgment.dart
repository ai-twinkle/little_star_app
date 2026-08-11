import 'dart:math';

import 'package:little_star_app/features/food_religion_war/domain/food_faith.dart';

enum FoodReligionVerdict {
  steadfast('信仰堅定'),
  reluctant('勉強護教'),
  wavering('叛教邊緣');

  const FoodReligionVerdict(this.label);

  final String label;
}

class FoodReligionJudgment {
  const FoodReligionJudgment({
    required this.verdict,
    required this.roast,
    this.isFallback = false,
  });

  final FoodReligionVerdict verdict;
  final String roast;
  final bool isFallback;
}

class FallbackJudgmentService {
  FallbackJudgmentService({Random? random}) : _random = random ?? Random();

  final Random _random;

  FoodReligionJudgment judge(FoodFaith stance) {
    final pool = _judgmentsFor(stance);
    return pool[_random.nextInt(pool.length)];
  }

  static String approvedRoastFor(
    FoodFaith stance,
    FoodReligionVerdict verdict,
  ) =>
      _judgmentsFor(
        stance,
      ).singleWhere((judgment) => judgment.verdict == verdict).roast;

  static List<FoodReligionJudgment> _judgmentsFor(FoodFaith stance) => [
    FoodReligionJudgment(
      verdict: FoodReligionVerdict.steadfast,
      roast: stance.fallbackCopy.steadfast,
      isFallback: true,
    ),
    FoodReligionJudgment(
      verdict: FoodReligionVerdict.reluctant,
      roast: stance.fallbackCopy.reluctant,
      isFallback: true,
    ),
    FoodReligionJudgment(
      verdict: FoodReligionVerdict.wavering,
      roast: stance.fallbackCopy.wavering,
      isFallback: true,
    ),
  ];
}
