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
    final pool = _judgmentsByFaith[stance]!;
    return pool[_random.nextInt(pool.length)];
  }

  static String approvedRoastFor(
    FoodFaith stance,
    FoodReligionVerdict verdict,
  ) =>
      _judgmentsByFaith[stance]!
          .singleWhere((judgment) => judgment.verdict == verdict)
          .roast;

  static const _judgmentsByFaith = <FoodFaith, List<FoodReligionJudgment>>{
    FoodFaith.northernZongzi: [
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.steadfast,
        roast: '油飯只是外表，粽葉才是北粽的戰袍！',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.reluctant,
        roast: '這理由有拌到油，還沒包進粽葉。',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.wavering,
        roast: '北粽都站穩了，你的論點還在油飯上打滑。',
        isFallback: true,
      ),
    ],
    FoodFaith.southernZongzi: [
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.steadfast,
        roast: '水煮不是退讓，是南粽糯米的內功修煉！',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.reluctant,
        roast: '粽葉都聽懂了，南粽糯米還在想。',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.wavering,
        roast: '南粽還在鍋裡撐著，你的理由先散開了。',
        isFallback: true,
      ),
    ],
    FoodFaith.extraCilantro: [
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.steadfast,
        roast: '這把香菜撒得夠高，評審席都綠了！',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.reluctant,
        roast: '香菜有加爆，論點只加了一小撮。',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.wavering,
        roast: '香菜堆成山，你的理由卻只剩一片葉。',
        isFallback: true,
      ),
    ],
    FoodFaith.noCilantro: [
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.steadfast,
        roast: '防香菜裝備完整，連一片葉子都過不了！',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.reluctant,
        roast: '香菜是退了，你的理由也差點退場。',
        isFallback: true,
      ),
      FoodReligionJudgment(
        verdict: FoodReligionVerdict.wavering,
        roast: '嘴上說退散，論點卻替香菜留了後門。',
        isFallback: true,
      ),
    ],
  };
}
