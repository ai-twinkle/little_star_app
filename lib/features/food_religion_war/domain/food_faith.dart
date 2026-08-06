enum FoodFaith {
  northernZongzi('北部粽派', '北部粽不就是包在粽葉裡的油飯嗎？'),
  southernZongzi('南部粽派', '南部粽不就是水煮糯米糰嗎？'),
  extraCilantro('香菜加爆派', '香菜味不會把整道料理都蓋掉嗎？'),
  noCilantro('香菜退散派', '少了香菜，這道料理還有靈魂嗎？');

  const FoodFaith(this.label, this.finalChallenge);

  final String label;
  final String finalChallenge;
}
