# Little Star App 技術架構筆記

> 一個在手機上運行本地 LLM 的 Flutter 應用程式架構剖析

## 前言

Little Star 是一款讓使用者能在手機上運行大型語言模型 (LLM) 的應用程式。本文將分享這個專案的技術架構設計，希望能給正在開發類似應用的開發者一些參考。

**核心挑戰：**
- 如何在行動裝置上高效運行 LLM？
- 如何管理大型模型檔案的下載與儲存？
- 如何設計一個可擴展的跨平台架構？

## 專案概覽

| 項目 | 說明 |
|------|------|
| 框架 | Flutter 3.7.2+ |
| 推理引擎 | llama.cpp (via FFI) |
| 支援平台 | Android / iOS / Desktop |
| 模型來源 | HuggingFace Hub |
| 模型格式 | GGUF (量化格式) |

## 架構全景圖

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Home   │  │   Chat   │  │Completion│  │  Models  │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│  ┌────┴─────────────┴─────────────┴─────────────┴────┐     │
│  │              ViewModel Layer                       │     │
│  │   (ChangeNotifier + ListenableBuilder)            │     │
│  └────────────────────────┬──────────────────────────┘     │
└───────────────────────────┼─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                    Service Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ HuggingFace │  │  Download   │  │   Directory         │  │
│  │   Service   │  │  Service    │  │   Service           │  │
│  └─────────────┘  └─────────────┘  │ (Platform-Specific) │  │
│                                    └─────────────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                     Core Layer                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    UnifiedLM                          │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │              llama.cpp FFI Bindings             │  │   │
│  │  │          (Native C/C++ via Dart FFI)           │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 核心設計決策

### 1. 狀態管理：ChangeNotifier + ViewModel

選擇輕量級的 `ChangeNotifier` 而非 BLoC 或 Riverpod，原因是：

- 應用程式狀態相對單純
- 減少學習曲線和套件依賴
- 足夠滿足需求且容易測試

```dart
class ChatViewModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  StreamSubscription<String>? _subscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;

  Future<void> sendMessage(String content) async {
    _messages.add(ChatMessage.user(content));
    _isGenerating = true;
    notifyListeners();

    // 流式生成回應
    _subscription = _lm.completionStream(content).listen(
      (token) {
        _messages.last.content += token;
        notifyListeners();
      },
      onDone: () {
        _isGenerating = false;
        notifyListeners();
      },
    );
  }
}
```

UI 綁定使用 `ListenableBuilder`：

```dart
ListenableBuilder(
  listenable: _viewModel,
  builder: (context, _) {
    return ListView.builder(
      itemCount: _viewModel.messages.length,
      itemBuilder: (context, index) => MessageBubble(
        message: _viewModel.messages[index],
      ),
    );
  },
)
```

### 2. 本地 LLM 推理：llama.cpp FFI

這是整個專案最核心的技術挑戰。透過 Dart FFI 直接調用 llama.cpp 的 C API。

**架構層次：**

```
┌─────────────────────────────────────┐
│            UnifiedLM                │  ← 統一介面
│  (隱藏底層複雜度，提供簡潔 API)      │
├─────────────────────────────────────┤
│          LlamaCppFFI                │  ← FFI 綁定層
│  (1300+ 行 Dart FFI 定義)           │
├─────────────────────────────────────┤
│       llama.cpp (C/C++)             │  ← 原生推理引擎
│  (GGML, Metal, CUDA support)        │
└─────────────────────────────────────┘
```

**UnifiedLM 提供的簡潔 API：**

```dart
class UnifiedLM {
  // 載入模型
  factory UnifiedLM(String modelPath, {bool verbose = false});

  // 文字補全
  String completion(String prompt);
  Stream<String> completionStream(String prompt);

  // 聊天對話
  String chat(List<ChatMessage> messages);
  Stream<String> chatStream(List<ChatMessage> messages);

  // 動態調整參數（無需重載模型）
  void updateSamplerParams({
    double? temperature,
    int? topK,
    double? topP,
  });
}
```

**為什麼要封裝 UnifiedLM？**

1. **隱藏 FFI 複雜度** - 開發者不需要知道 Native 記憶體管理細節
2. **統一 Chat/Completion 介面** - 根據模型自動選擇最佳格式
3. **支援流式輸出** - 即時顯示生成結果，提升使用者體驗
4. **參數動態調整** - 不需重載模型即可改變採樣參數

### 3. 跨平台目錄管理

不同平台對檔案存取有不同的限制，因此設計了抽象的 `DirectoryService`：

```dart
abstract class DirectoryService {
  Future<Directory> getModelsDirectory();
  Future<bool> requestPermissions({required BuildContext context});
  Future<List<FileSystemEntity>> listModels();
}
```

**各平台實作：**

| 平台 | 儲存位置 | 權限需求 |
|------|---------|---------|
| Android | `/storage/emulated/0/Download/LittleStar/models` | Storage + ManageExternalStorage |
| iOS | `Documents/Models` | 無（沙箱環境） |
| Desktop | `./models` | 無 |

```dart
// 根據平台選擇實作
DirectoryService _directoryService = Platform.isAndroid
    ? AndroidDirectoryService()
    : Platform.isIOS
        ? IOSDirectoryService()
        : DesktopDirectoryService();
```

### 4. 智慧下載管理

模型檔案通常有數 GB，需要穩健的下載機制。

**功能特點：**
- ✅ 斷點續傳（HTTP Range header）
- ✅ 下載進度即時回報
- ✅ 暫停/繼續/取消
- ✅ 任務持久化（Hive 儲存）
- ✅ 應用重啟後可恢復

```dart
class DownloadService {
  Stream<DownloadProgress> startDownload({
    required DownloadTask task,
    required Function(DownloadTask) onStatusChanged,
  }) async* {
    final file = File(task.destinationPath);
    int downloadedBytes = 0;

    // 檢查是否有部分下載的檔案
    if (await file.exists()) {
      downloadedBytes = await file.length();
    }

    // 使用 Range header 實現斷點續傳
    final response = await _dio.get(
      task.url,
      options: Options(
        headers: downloadedBytes > 0
            ? {'Range': 'bytes=$downloadedBytes-'}
            : null,
        responseType: ResponseType.stream,
      ),
    );

    // 串流寫入檔案並回報進度
    await for (final chunk in response.data.stream) {
      await raf.writeFrom(chunk);
      downloadedBytes += chunk.length;

      yield DownloadProgress(
        downloaded: downloadedBytes,
        total: totalBytes,
        speed: _calculateSpeed(),
      );
    }
  }
}
```

**三層架構：**

```
┌─────────────────────┐
│    HomeViewModel    │  ← 管理 UI 狀態
│  (進度訂閱/顯示)     │
├─────────────────────┤
│   DownloadService   │  ← 下載邏輯
│  (Dio/進度計算)      │
├─────────────────────┤
│  DownloadRepository │  ← 持久化
│  (Hive 儲存任務)     │
└─────────────────────┘
```

### 5. 提示詞格式化框架

不同的 LLM 有不同的提示詞格式，設計了可擴展的格式化框架：

```dart
abstract class PromptFormat {
  String get inputSequence;   // e.g., "<|user|>"
  String get outputSequence;  // e.g., "<|assistant|>"
  String get systemSequence;  // e.g., "<|system|>"
  String? get stopSequence;

  String formatMessages(List<Map<String, dynamic>> messages);
  String? filterResponse(String response);
}

// ChatML 格式實作
class ChatMLFormat extends PromptFormat {
  @override
  String get inputSequence => '<|im_start|>user\n';

  @override
  String get outputSequence => '<|im_start|>assistant\n';

  @override
  String formatMessages(List<Map<String, dynamic>> messages) {
    return messages.map((m) {
      final role = m['role'];
      final content = m['content'];
      return '<|im_start|>$role\n$content<|im_end|>\n';
    }).join() + '<|im_start|>assistant\n';
  }
}
```

### 6. 日誌與錯誤追蹤

建立了三層日誌架構，兼顧開發除錯和線上監控：

```
┌─────────────────────────────────────────┐
│        CrashReportingService            │
│    (Firebase Crashlytics 遠端回報)       │
├─────────────────────────────────────────┤
│          LogFileService                 │
│    (本地檔案儲存，5MB 輪替)              │
├─────────────────────────────────────────┤
│             Logger                      │
│    (自訂日誌類別，敏感資訊過濾)          │
└─────────────────────────────────────────┘
```

**敏感資訊自動過濾：**

```dart
static String _sanitizeMessage(String message) {
  return message
      .replaceAll(RegExp(r'Bearer [A-Za-z0-9\-_]+'), 'Bearer [REDACTED]')
      .replaceAll(RegExp(r'api[_-]?key["\s:=]+["\']?[\w-]+'), 'api_key=[REDACTED]')
      .replaceAll(RegExp(r'password["\s:=]+["\']?[^\s"\']+'), 'password=[REDACTED]');
}
```

## 套件選型考量

| 需求 | 選擇 | 考量 |
|------|------|------|
| HTTP 客戶端 | Dio | 支援進度回調、取消請求、攔截器 |
| 本地儲存 | Hive | 高效能、支援自訂型別序列化 |
| 簡單配置 | SharedPreferences | 輕量、適合 key-value 儲存 |
| 錯誤追蹤 | Firebase Crashlytics | 業界標準、免費額度足夠 |
| FFI | dart:ffi | 官方套件、無額外依賴 |

## 效能優化要點

### 1. 模型載入優化

```dart
// 延遲載入 - 只在需要時才載入模型
late final UnifiedLM _lm;

Future<void> _loadModel() async {
  // 顯示載入中 UI
  setState(() => _isLoading = true);

  // 在 isolate 中載入以避免阻塞 UI
  _lm = await compute(
    (path) => UnifiedLM(path),
    _selectedModelPath,
  );

  setState(() => _isLoading = false);
}
```

### 2. 流式輸出

不等待完整回應，即時顯示生成的文字：

```dart
Stream<String> generateStream(String prompt) async* {
  while (!_isFinished) {
    final token = _generateNextToken();
    yield token;  // 即時產出
  }
}
```

### 3. 下載進度節流

避免過於頻繁的 UI 更新：

```dart
// 每 500ms 才更新一次速度計算
if (now.difference(_lastSpeedUpdate).inMilliseconds >= 500) {
  _currentSpeed = _calculateSpeed();
  _lastSpeedUpdate = now;
}
```

## 未來規劃

- [ ] 對話歷史持久化
- [ ] 多模型同時載入
- [ ] 更多推理引擎支援 (LiteRT, ONNX, ExecuTorch) - 參見 [UnifiedLM 擴展性研究](./roadmap/core/unified_lm_extensibility_study.md)
- [ ] 模型微調支援
- [ ] 更多量化格式支援

## 結語

開發一個在手機上運行 LLM 的應用程式，需要在效能、使用者體驗和跨平台相容性之間取得平衡。透過合理的架構設計——抽象的 LM 介面、穩健的下載管理、清晰的分層架構——我們可以建立一個可維護且可擴展的應用程式。

希望這份架構筆記能對你有所幫助！如果你有任何問題或建議，歡迎交流討論。

---

**相關連結：**
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - 本地推理引擎
- [HuggingFace Hub](https://huggingface.co/) - 模型來源
- [GGUF 格式說明](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)

---

*本文基於 Little Star App v0.0.4-r2 版本撰寫*
