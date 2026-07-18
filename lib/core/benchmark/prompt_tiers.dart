import 'package:little_star_app/models/chat_message.dart';

/// One controlled-length benchmark prompt tier (task-C02).
///
/// Canonical source for docs/benchmark/zh-tw-prompt-set.md Part 2 — the
/// tokenizer only reports `promptTokenCount` for llama.cpp today (MLX's
/// `PromptMetricsSource` gap is tracked separately), so [targetTokenCount]
/// here is a draft estimate (~1.8 tokens/zh-tw-char, taken from the single
/// real on-device data point recorded in construction.md task-B03:
/// "很盤是什麼意思？" measured at 14 tokens for 8 characters). Calibrate
/// against the real T1 tokenizer via the Benchmark screen and update both
/// this file and the doc together — see task-C02 in construction.md.
class PromptTier {
  final String label;
  final int targetTokenCount;
  final List<ChatMessage> Function() _buildMessages;

  const PromptTier._(this.label, this.targetTokenCount, this._buildMessages);

  List<ChatMessage> toMessages() => _buildMessages();

  static ChatMessage _user(String content) => ChatMessage(content: content, isUser: true);
  static ChatMessage _assistant(String content) => ChatMessage(content: content, isUser: false);

  static final l128 = PromptTier._(
    'L128',
    128,
    () => [
      _user(
        '我下個月要帶爸媽去台南玩兩天一夜,他們比較不能走太多路,但很喜歡吃小吃、看老街建築。'
        '請幫我推薦一份輕鬆的行程,並簡單說明兩天要怎麼安排比較順路。',
      ),
    ],
  );

  static final l512 = PromptTier._(
    'L512',
    512,
    () => [
      _user(
        '台灣便利商店密度居全球前列,平均每兩千多人就有一間門市,無論是都市巷弄還是鄉間小鎮,'
        '幾乎都能在步行範圍內找到一間。這樣的普及程度不只是提供日常採買的方便,便利商店也逐漸'
        '承擔起繳費、代收包裹、影印文件、甚至提供簡易餐飲座位區等多重功能,成為許多人生活中'
        '不可或缺的一環。近年來,便利商店更積極導入自助結帳、行動支付與生鮮即食餐點,試圖因應'
        '人口結構老化與獨居人口增加所帶來的需求變化。對外國旅客而言,便利商店的密集與服務'
        '多樣性,也常被視為台灣生活機能便利的重要象徵之一。不過也有論者指出,便利商店的高度'
        '普及,某種程度上也反映了台灣中小型雜貨店與傳統市場逐漸式微的現象,兩者之間的消長,'
        '值得長期觀察。\n\n請將以上內容摘要成三點。',
      ),
    ],
  );

  static final l1024 = PromptTier._(
    'L1024',
    1024,
    () => [
      _user(
        '部分縣市近年積極推動夜市改建計畫,將原本路邊攤形式的夜市,整合進設有遮雨棚、公廁與'
        '消防通道的室內或半室內市集。支持者認為,這樣的改造能有效改善食品衛生與環境衛生問題,'
        '也讓攤商在颱風季或雨天仍可正常營業,減少收入的不穩定性。此外,統一規劃的動線與座位區,'
        '也被認為有助於提升觀光客的整體用餐體驗,間接延長遊客在當地停留與消費的時間。對地方'
        '政府而言,改建後的夜市園區也較容易進行租金管理與稅籍登記,長期而言有助於攤商經營的'
        '正常化。\n\n'
        '然而,也有在地文史工作者與長期經營的老攤商對改建計畫抱持保留態度。他們認為,夜市之'
        '所以吸引人,很大一部分來自於那種隨性、擁擠又充滿人情味的街頭氛圍,一旦搬進制式化的'
        '室內空間,攤位間距、動線與招牌設計都被統一規範,反而容易讓夜市失去原本雜亂卻鮮活的'
        '個性。此外,部分老攤商也擔心,新建園區的租金與管理費用可能高於原本路邊攤位,對長年'
        '薄利多銷的小吃攤而言,恐怕會壓縮原本就不寬裕的獲利空間,甚至迫使部分家族經營數十年'
        '的老店退出市場。\n\n請比較以上兩段文字對夜市改建計畫的觀點差異。',
      ),
    ],
  );

  static final l2048 = PromptTier._(
    'L2048',
    2048,
    () => [
      _user('我在規劃一趟兩週的台灣環島旅行,想從台北出發,順時針繞一圈,主要交通工具是台鐵和客運,'
          '請問這樣的路線大致上可以怎麼安排?'),
      _assistant('順時針環島的話,大致可以規劃成:台北 → 宜蘭/花蓮(東部) → 台東 → 高雄/屏東(南部) '
          '→ 台南 → 嘉義 → 台中 → 苗栗/新竹 → 回台北。台鐵的東部幹線(北迴、南迴)班次較少,'
          '建議先查好時刻表再排每日行程,西部因為有台鐵和高鐵雙重選擇,彈性會比較大。'),
      _user('東部那段如果想多留一天在花蓮玩太魯閣,對後面南部的行程會不會太趕?'),
      _assistant('會有一定影響,建議把花蓮到台東這段的停留天數抓寬鬆一點,例如花蓮留兩晚、太魯閣'
          '安排一整天,台東可以縮短為一晚,把多出來的彈性留給後面墾丁或台南想多待的地方,'
          '整體天數不變,只是內部天數重新分配。'),
      _user('那墾丁的部分,我們家有長輩同行,行動比較不方便,有沒有比較適合輪椅或不良於行的人的'
          '景點安排建議?比方說看海但不用走太多路的地方。'),
      _assistant('墾丁那邊像是後壁湖遊艇碼頭、白沙灣、關山夕陽平台都有鋪面完整的步道或停車場離'
          '觀景點很近,適合行動不便的長輩;砂島貝殼沙展示館也是室內平地,不太需要走路。'
          '鵝鑾鼻燈塔園區腹地較大,建議搭電動代步車或安排較短的動線。'),
      _user('了解,那如果最後這一段從南部要回台北,想留一天在台南,行程重點應該放在小吃還是古蹟?'
          '我們家人對兩者興趣差不多。'),
    ],
  );

  static final all = [l128, l512, l1024, l2048];
}
