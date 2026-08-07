enum FoodFaith {
  northernZongzi(
    '北部粽派',
    '北部粽不就是包在粽葉裡的油飯嗎？',
    'assets/food_religion_war/characters/northern_zongzi.png',
    FoodFaithFallbackCopy(
      steadfast: '油飯只是外表，粽葉才是北粽的戰袍！',
      reluctant: '這理由有拌到油，還沒包進粽葉。',
      wavering: '北粽都站穩了，你的論點還在油飯上打滑。',
    ),
  ),
  southernZongzi(
    '南部粽派',
    '南部粽不就是水煮糯米糰嗎？',
    'assets/food_religion_war/characters/southern_zongzi.png',
    FoodFaithFallbackCopy(
      steadfast: '水煮不是退讓，是南粽糯米的內功修煉！',
      reluctant: '粽葉都聽懂了，南粽糯米還在想。',
      wavering: '南粽還在鍋裡撐著，你的理由先散開了。',
    ),
  ),
  extraCilantro(
    '香菜加爆派',
    '香菜味不會把整道料理都蓋掉嗎？',
    'assets/food_religion_war/characters/extra_cilantro.png',
    FoodFaithFallbackCopy(
      steadfast: '這把香菜撒得夠高，評審席都綠了！',
      reluctant: '香菜有加爆，論點只加了一小撮。',
      wavering: '香菜堆成山，你的理由卻只剩一片葉。',
    ),
  ),
  noCilantro(
    '香菜退散派',
    '少了香菜，這道料理還有靈魂嗎？',
    'assets/food_religion_war/characters/no_cilantro.png',
    FoodFaithFallbackCopy(
      steadfast: '防香菜裝備完整，連一片葉子都過不了！',
      reluctant: '香菜是退了，你的理由也差點退場。',
      wavering: '嘴上說退散，論點卻替香菜留了後門。',
    ),
  ),
  sweetTofuPudding(
    '豆花配糖水',
    '只有糖水撐場，豆花不會太單調嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '糖水接住豆花，甜得很有道理！',
      reluctant: '甜度到位，理由還能再加一匙。',
      wavering: '豆花都泡甜了，你的論點還沒入味。',
    ),
  ),
  soyMilkTofuPudding(
    '豆花配豆漿',
    '豆漿配豆花，不會像同一件事做兩次嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '豆香疊豆香，這套組合有自己的節奏！',
      reluctant: '豆味很完整，論點還差一點濃度。',
      wavering: '豆漿和豆花都到齊，理由卻還在路上。',
    ),
  ),
  satayHotPot(
    '火鍋沾沙茶',
    '每一口都沾沙茶，還吃得到湯底嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '沙茶不是遮味，是火鍋的加速器！',
      reluctant: '醬有拌勻，理由只拌到一半。',
      wavering: '沙茶香氣衝線了，你的論點還在撈料。',
    ),
  ),
  brothHotPot(
    '火鍋原湯派',
    '湯都不沾醬，味道真的夠嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '原湯敢單挑，這鍋底氣很足！',
      reluctant: '湯頭有層次，理由還要再熬一下。',
      wavering: '原湯守住了，你的論點卻先被稀釋。',
    ),
  ),
  fullSugarBubbleTea(
    '珍奶全糖',
    '全糖喝到最後，不會只剩甜味嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '全糖就是完整火力，珍珠都點頭了！',
      reluctant: '甜度滿格，理由還差一格。',
      wavering: '糖已經全開，你的論點還在半糖。',
    ),
  ),
  lessSugarBubbleTea(
    '珍奶微糖',
    '微糖的珍奶，還有喝甜品的快樂嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '微糖留住茶香，也留住了立場！',
      reluctant: '甜度克制，理由也稍微克制了。',
      wavering: '茶香很清楚，你的論點卻有點淡。',
    ),
  ),
  saltedFries(
    '薯條加鹽',
    '薯條本來就有味道，還需要再加鹽嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '這撮鹽把薯條的靈魂叫醒了！',
      reluctant: '鹽有撒到，理由只撒了一點。',
      wavering: '薯條夠鹹了，你的論點還不夠有味。',
    ),
  ),
  plainFries(
    '原味不加鹽',
    '不加鹽的薯條，不會像少做最後一步嗎？',
    null,
    FoodFaithFallbackCopy(
      steadfast: '原味敢直接上桌，馬鈴薯本人很有底氣！',
      reluctant: '原味站得住，理由還能更酥一點。',
      wavering: '鹽是省下了，你的論點也省得太多。',
    ),
  );

  const FoodFaith(
    this.label,
    this.finalChallenge,
    this.characterAssetPath,
    this.fallbackCopy,
  );

  final String label;
  final String finalChallenge;
  final String? characterAssetPath;
  final FoodFaithFallbackCopy fallbackCopy;
}

class FoodFaithFallbackCopy {
  const FoodFaithFallbackCopy({
    required this.steadfast,
    required this.reluctant,
    required this.wavering,
  });

  final String steadfast;
  final String reluctant;
  final String wavering;
}

class FoodStancePair {
  const FoodStancePair({
    required this.topic,
    required this.left,
    required this.right,
  });

  final String topic;
  final FoodFaith left;
  final FoodFaith right;

  List<FoodFaith> get stances => [left, right];

  static const stancePool = [
    FoodStancePair(
      topic: '粽子口味',
      left: FoodFaith.northernZongzi,
      right: FoodFaith.southernZongzi,
    ),
    FoodStancePair(
      topic: '香菜偏好',
      left: FoodFaith.extraCilantro,
      right: FoodFaith.noCilantro,
    ),
    FoodStancePair(
      topic: '豆花搭配',
      left: FoodFaith.sweetTofuPudding,
      right: FoodFaith.soyMilkTofuPudding,
    ),
    FoodStancePair(
      topic: '火鍋沾醬',
      left: FoodFaith.satayHotPot,
      right: FoodFaith.brothHotPot,
    ),
    FoodStancePair(
      topic: '珍奶甜度',
      left: FoodFaith.fullSugarBubbleTea,
      right: FoodFaith.lessSugarBubbleTea,
    ),
    FoodStancePair(
      topic: '薯條調味',
      left: FoodFaith.saltedFries,
      right: FoodFaith.plainFries,
    ),
  ];
}
