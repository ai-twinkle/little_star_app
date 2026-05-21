# 下載服務 416 錯誤修復與權限檢查

## 問題描述

在恢復下載模型時，出現 HTTP 416 (Range Not Satisfiable) 錯誤：

```
I/flutter: debug: [DownloadService] Resuming download from byte 253115424
I/flutter: error: [DownloadService] Download failed: This exception was thrown because the response has a status code of 416
```

隨後嘗試刪除暫存檔時又發生 `PathNotFoundException` 錯誤。

## 根本原因分析

### HTTP 416 錯誤
- **原因**：本地暫存檔 `.tmp` 的大小超過或等於伺服器上的檔案大小
- **常見情境**：
  1. 檔案已完整下載，但暫存檔尚未重新命名為正式檔案
  2. 伺服器上的檔案已更新（大小變小）
  3. 暫存檔損壞或大小資料不一致

### PathNotFoundException 錯誤
- **原因**：`tempFile.exists()` 回傳 true，但實際刪除時檔案已不存在
- **可能原因**：
  1. 競態條件（race condition）
  2. 檔案系統同步延遲
  3. Android Scoped Storage 權限限制

## 解決方案

### 1. 處理 416 錯誤與安全刪除 (`download_service.dart`)

```dart
// 安全地檢查暫存檔
int existingBytes = 0;
try {
  if (await tempFile.exists()) {
    existingBytes = await tempFile.length();
    _log.debug('Resuming download from byte $existingBytes');
  }
} catch (e) {
  // 檔案存取錯誤 - 可能是權限問題
  _log.warn('Cannot access temp file, starting fresh: $e');
  existingBytes = 0;
}

// 處理 416 錯誤
on DioException catch (e) {
  if (e.response?.statusCode == 416) {
    _log.warn('Range not satisfiable (416), deleting temp file and restarting');
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (deleteError) {
      // 忽略刪除錯誤 - 檔案可能已不存在
      _log.debug('Could not delete temp file: $deleteError');
    }
    existingBytes = 0;
    headers.remove('Range');

    // 不帶 Range header 重新下載
    response = await _dio.get<ResponseBody>(...);
  } else {
    rethrow;
  }
}
```

### 2. 正確的檔案寫入模式

```dart
// 根據是否有暫存資料選擇寫入模式
final sink = tempFile.openWrite(
    mode: existingBytes > 0 ? FileMode.append : FileMode.write);
```

### 3. 下載前權限檢查 (`home_viewmodel.dart`)

```dart
Future<void> startOneClickDownload(
  RecommendedModelState modelState, {
  required Future<bool> Function() requestPermission,
}) async {
  // ...

  // 在 Android 上下載前先請求權限
  if (Platform.isAndroid) {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _log.warn('Storage permission denied, cannot download');
      throw Exception('Storage permission is required to download models');
    }
  }

  // ...
}
```

### 4. UI 層傳入權限回調 (`home_screen.dart`)

```dart
onDownload: () => _viewModel.startOneClickDownload(
  modelState,
  requestPermission: () => _directoryService.requestPermissions(context: context),
),
```

## 修改的檔案

| 檔案 | 修改內容 |
|------|----------|
| `lib/data/services/download_service.dart` | 處理 416 錯誤、安全刪除、正確寫入模式 |
| `lib/ui/home/view_model/home_viewmodel.dart` | 新增 `requestPermission` 參數，下載前檢查權限 |
| `lib/ui/home/widgets/home_screen.dart` | 保存 `_directoryService`，傳入權限回調 |

## Android 權限說明

App 需要以下權限才能下載到 `/storage/emulated/0/Download/` 路徑：

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

使用者需要在系統設定中授予「管理所有檔案」權限：
**設定 → 應用程式 → Little Star → 權限 → 檔案與媒體 → 允許管理所有檔案**

## 測試建議

1. 首次下載模型 - 應該彈出權限請求對話框
2. 拒絕權限後嘗試下載 - 應該顯示錯誤訊息
3. 授予權限後下載 - 應該正常開始下載
4. 下載中途取消，再次下載 - 應該能正確恢復或重新開始
5. 手動刪除 `.tmp` 檔案後恢復下載 - 應該自動從頭開始
