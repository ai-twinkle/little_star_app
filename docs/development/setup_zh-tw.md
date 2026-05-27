# 開發環境設定

> 讀者：想 clone repo 並跑起 dev build 的貢獻者。
> 本文帶你從零起步到在 iOS、macOS、Windows、Android 上跑起 App。

> 本文為 [setup.md](./setup.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## 1. 概覽

`little_star_app` 是一個 Flutter App，原生依賴 llama.cpp（C/C++）與 Apple Silicon 上的 mlx-swift-lm（Swift）。要跑 dev build，你會經歷：

1. 安裝主機工具（Xcode / Visual Studio、fvm、CMake）。
2. Clone repo 並抓 Flutter / CocoaPods 依賴。
3. 為目標平台 build llama.cpp。
4. （選用）若修改 `pigeons/mlx_inference.dart` 則重新生成 Pigeon glue。
5. 執行 `fvm flutter run -d <platform>`。

各平台 llama.cpp 詳細 build 指南位於 `scripts/llama.cpp_*_Build.md`。本文是**入口文件**——指引你該讀哪份文件、以及該以什麼順序做事。

## 2. 環境需求

### 2.1 主機 OS

| 目標 | 主機 OS | 備註 |
|------|---------|------|
| iOS | macOS 13+ | Xcode 需要 macOS |
| macOS | macOS 13+ | App 的最低部署目標為 macOS 13 |
| Android | macOS / Linux / Windows | 需要 NDK |
| Windows | Windows 10+ | Visual Studio + 「使用 C++ 的桌面開發」工作負載 |

### 2.2 工具鏈

| 工具 | 版本 | 安裝 | 用途 |
|------|------|------|------|
| **fvm** | 最新 | `dart pub global activate fvm` | 鎖定 Flutter SDK 至專案版本 |
| **Flutter** | 透過 fvm | `fvm install` | Flutter SDK |
| **Xcode** | 15+（已測 26.2） | App Store | iOS / macOS build |
| **Xcode CLT** | 現行版 | `xcode-select --install` | 命令列 build 工具 |
| **CocoaPods** | 最新 | `gem install cocoapods` | iOS / macOS plugin 依賴 |
| **CMake** | 3.28+（已測 4.0.2） | `brew install cmake` / `winget install Kitware.CMake` | llama.cpp build |
| **Android NDK** | 25.1.8937393+ | Android Studio → SDK Manager | Android llama.cpp build |
| **Visual Studio** | 2022 + C++ 工作負載 | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) | Windows llama.cpp build |
| **Git LFS** | 最新 | `brew install git-lfs` / `git lfs install` | macOS universal lib 透過 LFS 傳遞 |
| **Pigeon CLI** | `^22.7.2` | `fvm dart pub global activate pigeon 22.7.2` *（選用）* | 重新生成 MLX bridge glue |

> **為何用 fvm？** Flutter SDK 版本屬於專案的一部分；fvm 讓你本地 SDK 與 CI、其他貢獻者保持一致。直接執行 `flutter` 可能使用全域安裝的版本，與本專案預期不同。

### 2.3 驗證

完成上述安裝後，做基本檢查：

```bash
fvm flutter doctor
```

至少這些項目應顯示綠色勾：

- Flutter
- （Mac）Xcode
- （Mac/Win）連線裝置或模擬器

某些區塊（Chrome、Linux 工具鏈）在你不開發的平台上顯示紅色屬正常。

## 3. Clone 與初始化

```bash
git clone https://github.com/<owner>/little_star_app.git
cd little_star_app

# 拉取 LFS 追蹤的檔案（macOS universal libs）。
git lfs install
git lfs pull

# 安裝專案釘版的 Flutter SDK。
fvm install
fvm use

# 抓 Dart / Flutter 依賴。
fvm flutter pub get

# 安裝 iOS / macOS plugin pod。
cd ios   && pod install && cd ..
cd macos && pod install && cd ..
```

### 驗證

```bash
fvm flutter doctor
fvm flutter pub deps --no-dev | head -20
```

兩個指令都應該無錯誤完成。

## 4. Build llama.cpp

llama.cpp bundle 在 `llama.cpp/` 目錄，釘在固定 commit（Windows 目前 `b9334`、行動裝置目標 `b7493`）。build script 為各平台編譯對應的 static 或 dynamic library，並放到 Runner 預期的位置。

| 平台 | Build script | 產出 |
|------|--------------|------|
| iOS | `scripts/build_llama.cpp_ios.sh` | `ios/Frameworks/libllama-*.a` + `libggml*.a` |
| macOS | `scripts/build_llama.cpp_macos.sh` | `macos/Frameworks/libllama.a` + `libggml*.a`（universal arm64 + x86_64） |
| Android | `scripts/build_llama.cpp_android.sh` / `.ps1` | `android/app/src/main/jniLibs/<abi>/libllama.so` |
| Windows | `scripts/build_llama.cpp_x64.ps1` | `windows/runner/llama.dll`（透過 exe-relative path 載入） |

執行你目標平台的 script：

```bash
# macOS / iOS 主機
bash scripts/build_llama.cpp_macos.sh
bash scripts/build_llama.cpp_ios.sh

# Windows 主機（PowerShell）
.\scripts\build_llama.cpp_x64.ps1

# Android（跨平台，需要 ANDROID_NDK_ROOT）
bash scripts/build_llama.cpp_android.sh
```

完整的 CMake flag 推導、整合細節、已知問題請見深入版：

- [`scripts/llama.cpp_MacOS_Build.md`](../../scripts/llama.cpp_MacOS_Build.md)
- [`scripts/llama.cpp_iOS_Build.md`](../../scripts/llama.cpp_iOS_Build.md)
- [`scripts/llama.cpp_Android_Build.md`](../../scripts/llama.cpp_Android_Build.md)

### 驗證

Script 跑完後：

```bash
# macOS — 確認 universal lib 在位
ls -la macos/Frameworks/libllama.a
file macos/Frameworks/libllama.a  # 應顯示「fat file with 2 architectures」

# iOS — 確認 device + simulator lib
ls -la ios/Frameworks/libllama-*.a

# Windows
Test-Path windows\runner\llama.dll

# Android
ls -la android/app/src/main/jniLibs/*/libllama.so
```

## 5. Pigeon 程式碼生成（選用）

MLX bridge 介面定義在 `pigeons/mlx_inference.dart`。若你修改此檔，請重新生成 Dart 與 Swift glue：

```bash
fvm dart run pigeon --input pigeons/mlx_inference.dart
```

產出位置：
- `lib/core/engine/mlx/mlx_inference.g.dart`（Dart 端）
- `ios/Runner/MlxBridge/MlxInference.g.swift`（Swift 端）

**不要手動編輯 `.g` 結尾的產生檔**——下次執行會覆蓋。

只有當你動到 Pigeon schema 時才需要這一步。對於全新 checkout，產生的檔案已在 repo 內，可跳過本節。

## 6. 平台專屬設定

### 6.1 iOS

iOS Runner 除了 llama.cpp static lib 還需要兩件事：

1. **mlx-swift-lm Swift Package**：應已在 Xcode 專案內連好（透過 *Runner project → Package Dependencies* 加入）。確認 `MLXLLM`、`MLXLMCommon`、`MLXHuggingFace`、`Tokenizers` 都在列表內。
2. **Code signing**：實機 build 需在 *Runner target → Signing & Capabilities* 設定 development team；模擬器 build 不需簽章。

**驗證**：

```bash
fvm flutter build ios --debug --no-codesign
```

應該無 linker 錯誤完成。若看到 `Undefined symbols for llama_*`，重跑 `scripts/build_llama.cpp_ios.sh`。

### 6.2 macOS

macOS Runner 透過 `OTHER_LDFLAGS` 內的 `-force_load` 連結 static lib（設定於 `macos/Runner.xcodeproj/project.pbxproj`）。Entitlements 已配置：

- App Sandbox（永遠開啟）
- `com.apple.security.cs.allow-jit`（Debug 限定——Flutter JIT）
- `com.apple.security.network.client`（模型下載）

模型儲存位置：

```
~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/Models/
```

此路徑由 `path_provider` 的 `getApplicationSupportDirectory()` 回傳。

**驗證**：

```bash
fvm flutter build macos --debug
```

應該成功，build log 內回報 `1279 llama/ggml symbols found`。

> **macOS 上 Firebase 刻意被關閉**（見 `lib/main.dart`），因為 macOS 的 `GoogleService-Info.plist` 尚未配置。如果你要為 macOS 加上 Firebase，請移除 `_isFirebaseSupported` 守衛。

### 6.3 Windows

Windows runner 動態連結 `llama.dll`。DLL 放在 `windows/runner/`，loader 在執行期以 exe-relative path 解析（見 `lib/core/platform/native_library_loader.dart`）。

目前 `WindowsPlatformAdapter.supportsInference = false`，待 EP-1 desktop 整合任務完成才會切到 true；Windows build 可跑起來，但 UI 會關閉推論功能。

**驗證**：

```powershell
fvm flutter build windows --debug
```

應該完成；產出位置 `build\windows\x64\runner\Debug\little_star_app.exe`。

### 6.4 Android

`AndroidDirectoryService` 將模型寫入 `/storage/emulated/0/Download/LittleStar/models`，使用者可見。Build 預期 `libllama.so` 依 ABI 放於 `android/app/src/main/jniLibs/<abi>/`。

**驗證**：

```bash
fvm flutter build apk --debug
```

## 7. 跑起 App

平台 build 完成後：

```bash
# iOS 模擬器或實機
fvm flutter run -d ios

# macOS
fvm flutter run -d macos

# Windows
fvm flutter run -d windows

# Android 模擬器或實機
fvm flutter run -d android
```

首次啟動，Home 畫面會顯示**推薦模型**列表。本地還沒有任何模型——點一個從 Hugging Face 下載，或開啟 Models 畫面加入你自己的 GGUF / MLX 模型。

### 驗證

啟動 log 應包含：

```
Successfully loaded llama.cpp libraries from <platform> app bundle
```

若看到「Failed to load libraries」，回頭檢查第 4 節（llama.cpp build）與第 6 節（平台設定）。

## 8. 模型——下載與放置

### 8.1 App 內下載

最簡單的途徑。透過 Models 畫面：

- **推薦清單**：來自 `lib/config/recommended_models.dart` 的精選名單——Gemma 3 270M、Llama 3.2 1B、Qwen 2.5 0.5B 等。
- **搜尋 Hugging Face**：輸入關鍵字；結果會過濾為 GGUF（Apple Silicon 上也含 MLX）。

下載完的檔案落在平台對應的模型目錄（見 8.2），會出現在 Chat / Completion 畫面內。

### 8.2 手動放置（開發用）

如果你已有 GGUF / MLX 模型檔，把它丟到平台對應的模型目錄：

| 平台 | 路徑 |
|------|------|
| iOS（模擬器） | `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<APP-UUID>/Documents/Models/` |
| macOS | `~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/Models/` |
| Android | `/storage/emulated/0/Download/LittleStar/models/` |
| Windows | `%APPDATA%\<bundle-id>\Models\` |

重啟 App 後，模型會出現在「Local Models」分頁下。

## 9. 常見問題排查

### `pigeon ^22.7.2` 阻擋 `flutter_riverpod` 升版

症狀：`fvm flutter pub upgrade` 抱怨 `riverpod 3.x` 與 `pigeon 22.7.2` 不相容。

原因：`pigeon 22.7.2` 間接釘住舊版 `meta` / `analyzer`，與 `riverpod 3.x` 衝突。

修法：保留 `flutter_riverpod: ^2.6.1`，直到 Pigeon 上游跟上。已記錄於 `pubspec.yaml`。若你要升 `flutter_riverpod`，同時也升 `pigeon` 並重新生成 MLX glue（第 5 節）。

### Link 時 `Undefined symbols: _llama_*`

原因：llama.cpp static library 未為當前目標重建，或 Frameworks 目錄不在 `LIBRARY_SEARCH_PATHS`。

修法：

```bash
# Mac / iOS：重 build 並清快取
bash scripts/build_llama.cpp_macos.sh   # 或 _ios.sh
fvm flutter clean
fvm flutter pub get
fvm flutter run -d macos
```

對 macOS 而言，再次確認 `macos/Runner.xcodeproj/project.pbxproj` 內的 `OTHER_LDFLAGS` 含有 [`scripts/llama.cpp_MacOS_Build.md`](../../scripts/llama.cpp_MacOS_Build.md) 列出的六條 `-force_load`。

### iOS 上 MLX 模型載入失敗

症狀：`loadModel` 拋出 `PlatformException(no-model, ...)` 或 tokenizer 錯誤。

可能原因：

1. **SPM resolution 失敗**——在 Xcode 開啟 `ios/Runner.xcodeproj`，確認 `mlx-swift-lm` 3.31.3 已正確 resolve（*Package Dependencies*）。
2. **模型目錄結構不對**——`mlx-swift-lm` 預期一個資料夾，內含 `config.json`、`tokenizer.json`、`model.safetensors*` 等。單一檔案不會運作。
3. **AutoTokenizer trust**——bridge 使用 `AutoTokenizerLoader`（非 `MLXHuggingFaceMacros`）以繞過 trust 要求；若修改 `MlxInferenceBridge.swift`，請保留此 loader。

### macOS Runner 啟動時 Firebase crash

原因：`DefaultFirebaseOptions.currentPlatform` 因為 macOS 沒有 `GoogleService-Info.plist` 而拋例外。

狀態：已在 `lib/main.dart` 透過 `_isFirebaseSupported` 守衛排除。若仍 crash，確認該守衛存在。

### llama.cpp build 失敗，`metal.h not found`（macOS）

原因：Xcode CLT 不完整。

修法：

```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

重跑 build script。

## 10. 下一步

- 讀 [`docs/architecture/overview.md`](../architecture/overview.md) 了解各層如何協作。
- 讀 [`docs/adr/`](../adr/README.md) 看具體設計選擇背後的「為何」。
- 讀 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)（EP-1 撰寫中）了解 PR / commit 流程。
