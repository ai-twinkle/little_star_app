這是以正體中文翻譯的 `docs/develop_notes/alpha.2-01_home_screen_accordion_ui.md` 內容：

# Alpha 2.1 - 首頁手風琴式 (Accordion) UI 實作

## 日期
2025-12-20

## 概述
在首頁的「已下載模型」和「推薦模型」區塊實作了可折疊的手風琴式 UI，以提升介面整潔度與使用者體驗。

## 修改內容

### 1. 已下載模型區塊 (Downloaded Models Section)
**檔案：** `lib/ui/home/widgets/downloaded_models_section.dart`

#### 修改細節：
- 將 `Column` 佈局替換為 `ExpansionTile` 元件。
- 新增 `initiallyExpanded` 參數（預設為 `true`），用於控制初始展開狀態。
- 使用 `Theme` 元件包裝 `ExpansionTile` 以移除分隔線。
- 設定 `dividerColor: Colors.transparent` 來隱藏頂部與底部的預設分隔線。

#### 新功能：
- 具備流暢動畫的可折疊/展開區塊。
- 保留所有現有功能（聊天、測試、管理按鈕）。
- 維持原始樣式與佈局。
- 折疊時圖示與標題仍保持可見。

#### 程式碼結構：
```dart
return Theme(
  data: theme.copyWith(dividerColor: Colors.transparent),
  child: ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    leading: Icon(Icons.folder, ...),
    title: Text('已下載模型 (${models.length})', ...),
    trailing: Row(
      children: [
        TextButton(onPressed: onManage, child: Text('管理')),
        Icon(Icons.expand_more),
      ],
    ),
    children: [
      SizedBox(
        height: 140,
        child: ListView.separated(...),
      ),
    ],
  ),
);
```

### 2. 推薦模型區塊 (Recommended Models Section)
**檔案：** `lib/ui/home/widgets/home_screen.dart` (第 210-261 行)

#### 修改細節：
- 將 `Column` 佈局轉換為 `ExpansionTile` 元件。
- 套用相同的 `Theme` 包裝技術來移除分隔線。
- 設定 `initiallyExpanded: true` 為預設展開狀態。
- 保留骨架屏 (Skeleton) 載入狀態與模型卡片佈局。

#### 程式碼結構：
```dart
return Theme(
  data: theme.copyWith(dividerColor: Colors.transparent),
  child: ExpansionTile(
    initiallyExpanded: true,
    leading: Icon(Icons.star, color: Colors.amber),
    title: Text('推薦模型', ...),
    children: [
      if (_viewModel.isLoadingLocal)
        const SkeletonRecommendedModels()
      else
        SizedBox(
          height: 200,
          child: ListView.separated(...),
        ),
    ],
  ),
);
```

## 技術細節

### ExpansionTile 元件
- 使用 Flutter 內建的 `ExpansionTile` 元件，而非自定義手風琴組件。
- 提供原生的 Material Design 展開動畫。
- 自動處理展開/折疊的狀態管理。
- 包含預設的箭頭旋轉動畫。

### 移除分隔線
- 使用 `Theme` 元件包裝 `ExpansionTile`。
- 覆寫 `dividerColor` 屬性為 `Colors.transparent`。
- 移除 `ExpansionTile` 在展開時預設顯示的頂部與底部線條。

### 新增參數
- `initiallyExpanded: bool`：控制初始展開狀態。
  - 兩個區塊目前皆預設為 `true`。
  - 方便未來自定義預設顯示狀態。

## UI/UX 改進

### 優點：
1. **介面更整潔**：使用者可以折疊不需要的區塊。
2. **更好的空間管理**：減少區塊折疊時的垂直捲動距離。
3. **改進組織結構**：透過可擴展區塊建立清晰的視覺層級。
4. **流暢動畫**：原生 Material Design 轉場效果。
5. **無視覺分隔線**：外觀更清爽，減少干擾。

### 使用者互動：
- 點擊區塊標題即可展開/折疊。
- 箭頭圖示會旋轉以指示展開狀態。
- 展開時所有按鈕（聊天、測試、管理）均可正常運作。
- 內容會以流暢動畫滑入/滑出。

## 測試考量

### 手動測試項目：
- [ ] 驗證兩個區塊是否能正確展開與折疊。
- [ ] 檢查展開時所有按鈕是否仍具備功能。
- [ ] 確認沒有出現分隔線。
- [ ] 測試動畫效能是否流暢。
- [ ] 驗證在不同螢幕尺寸下的佈局表現。

### 邊界情況：
- 模型列表為空（已透過 `SizedBox.shrink()` 處理）。
- 載入狀態（骨架屏顯示正常）。
- 模型名稱過長（已處理省略號溢出）。

## 未來展望

### 潛在改進：
1. 將展開狀態儲存至 `shared_preferences` 以達成持久化。
2. 在展開/折疊時加入觸覺回饋 (Haptic Feedback)。
3. 自定義展開動畫的持續時間或曲線。
4. 在 AppBar 加入選用的「全部展開 / 全部折疊」按鈕。

### 無障礙輔助 (Accessibility)：
- 考慮為螢幕閱讀器添加語義標籤。
- 確保支援鍵盤導覽。
- 為展開控制項添加工具提示 (Tooltips)。

## 相關檔案
- `lib/ui/home/widgets/downloaded_models_section.dart`
- `lib/ui/home/widgets/home_screen.dart`
- `lib/models/gguf_model_info.dart`

## 依賴項
未新增任何依賴項 — 使用 Flutter 內建 Material 元件。

## 破壞性變更 (Breaking Changes)
無 — 保留了所有現有功能。

## 遷移指南
對於任何實例化 `DownloadedModelsSection` 的程式碼，`initiallyExpanded` 參數是可選的（預設為 `true`），因此無需修改現有程式碼。