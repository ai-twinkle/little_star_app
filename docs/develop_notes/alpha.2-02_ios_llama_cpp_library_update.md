# iOS llama.cpp 靜態庫更新問題排查

## 問題概述

更新 llama.cpp 版本後，iOS 建置失敗，出現大量 `Undefined symbol` 連結器錯誤。

## 錯誤訊息

```
Error (Xcode): Undefined symbol: llama_kv_cache_unified::llama_kv_cache_unified(...)
Error (Xcode): Undefined symbol: llama_kv_cache_unified_context::next()
Error (Xcode): Undefined symbol: llm_graph_input_attn_kv_unified::set_input(...)
... 約 60+ 個 undefined symbols
```

## 問題根因

### 1. 標頭檔案與靜態庫版本不同步

手動更新了 `ios/Runner/` 中的標頭檔案（如 `llama.h`、`ggml.h`），但沒有重新編譯靜態庫。

- 標頭檔案：新版（Dec 21 13:06）
- 靜態庫：舊版（Dec 21 12:57）

### 2. 缺少必要的標頭檔案

`llama.h` 依賴 `ggml-opt.h`，但這個檔案沒有被複製到 `ios/Runner/`，導致 Swift Bridging Header 編譯失敗：

```
Error (Xcode): Command SwiftGeneratePch failed with a nonzero exit code
```

### 3. 過時的導出符號列表

`ios/llama.exp` 檔案包含舊版 API 的符號名稱（如 `llama_kv_cache_unified`），但新版 llama.cpp 已將其重構為 `llama_kv_cache`。

xcconfig 設定引用了這個過時的檔案：
```
EXPORTED_SYMBOLS_FILE = $(PROJECT_DIR)/llama.exp
```

## 解決方案

### 1. 更新編譯腳本 (`scripts/build_llama.cpp_ios.sh`)

新增必要的 CMake 選項：

```bash
-DGGML_NATIVE=OFF \           # 交叉編譯必須關閉
-DGGML_METAL_EMBED_LIBRARY=ON \ # 嵌入 Metal shader
-DGGML_ACCELERATE=ON \        # 啟用 Apple Accelerate framework
```

新增自動複製標頭檔案功能：

```bash
# Copy all ggml headers (including ggml-opt.h and gguf.h which are required by llama.h)
for header in ggml.h ggml-alloc.h ggml-backend.h ggml-metal.h ggml-cpu.h ggml-opt.h gguf.h; do
    if [ -f "$LLAMA_DIR/ggml/include/$header" ]; then
        cp "$LLAMA_DIR/ggml/include/$header" "$IOS_RUNNER_DIR/"
    fi
done
```

### 2. 移除過時的 llama.exp 設定

刪除 `ios/llama.exp` 檔案，並修改 xcconfig 設定：

**ios/Flutter/Debug.xcconfig** 和 **ios/Flutter/Release.xcconfig**：

```diff
- EXPORTED_SYMBOLS_FILE = $(PROJECT_DIR)/llama.exp
+ DEAD_CODE_STRIPPING = NO
```

使用 `DEAD_CODE_STRIPPING = NO` 替代導出符號列表，避免連結器移除 llama.cpp 函數，且不需要維護符號列表。

### 3. 完整重建流程

```bash
# 1. 重新編譯 llama.cpp 靜態庫
./scripts/build_llama.cpp_ios.sh

# 2. 清理 Xcode 快取
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# 3. 清理 Flutter 專案
fvm flutter clean
rm -rf ios/Pods ios/Podfile.lock

# 4. 重新建置
fvm flutter pub get
fvm flutter run -d <device-id>
```

## 預防措施

1. **永遠透過編譯腳本更新 llama.cpp**：不要手動複製標頭檔案，使用 `build_llama.cpp_ios.sh` 腳本可確保標頭檔案和靜態庫版本同步。

2. **避免使用 EXPORTED_SYMBOLS_FILE**：使用 `DEAD_CODE_STRIPPING = NO` 更簡單且不需要維護符號列表。

3. **版本更新時完整重建**：更新 llama.cpp 原始碼後，務必重新編譯所有平台的靜態庫。

## 相關檔案

- `scripts/build_llama.cpp_ios.sh` - iOS 編譯腳本
- `ios/Frameworks/` - 靜態庫存放目錄
- `ios/Runner/*.h` - 標頭檔案
- `ios/Flutter/Debug.xcconfig` - Debug 建置設定
- `ios/Flutter/Release.xcconfig` - Release 建置設定
