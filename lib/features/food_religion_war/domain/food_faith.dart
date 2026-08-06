enum FoodFaith {
  northernZongzi(
    '北部粽派',
    '北部粽不就是包在粽葉裡的油飯嗎？',
    'assets/food_religion_war/characters/northern_zongzi.png',
  ),
  southernZongzi(
    '南部粽派',
    '南部粽不就是水煮糯米糰嗎？',
    'assets/food_religion_war/characters/southern_zongzi.png',
  ),
  extraCilantro(
    '香菜加爆派',
    '香菜味不會把整道料理都蓋掉嗎？',
    'assets/food_religion_war/characters/extra_cilantro.png',
  ),
  noCilantro(
    '香菜退散派',
    '少了香菜，這道料理還有靈魂嗎？',
    'assets/food_religion_war/characters/no_cilantro.png',
  );

  const FoodFaith(this.label, this.finalChallenge, this.characterAssetPath);

  final String label;
  final String finalChallenge;
  final String characterAssetPath;
}
