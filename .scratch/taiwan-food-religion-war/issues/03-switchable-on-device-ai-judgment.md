# 03 — 接入可切換模型的端側 AI 裁決

**What to build:** 有本機模型時，玩家可在辯護頁使用預設模型或切換至另一個已安裝模型；送出後由所選模型依實際辯護產生經過結構與安全驗證的個人化判決。任何不可用或競態情況都透明切回既有備援結果，且整局只完成一次。

**Blocked by:** 02 — 完成辯護與離線備援結果.

**Status:** completed

- [x] 辯護頁列出可發現的已安裝 GGUF 與 MLX 模型，不提供下載、管理或獨立模型狀態頁。
- [x] 預設選擇可重現：GGUF 優先於 MLX，同類模型以穩定排序取第一個；玩家送出前可切換，送出後選擇器鎖定。
- [x] 模型選擇只存在當前 Session；「再玩一次」會重新發現模型並套用預設，不保留上一局選擇。
- [x] AI 裁決透過既有 inference abstraction 與 generation boundary 執行，不讓遊戲 Feature 直接依賴 FFI、Pigeon 或特定 backend。
- [x] 模型輸入包含冠軍、對應固定質疑、玩家原始辯護、三級判決準則及安全護欄，且每次辯護只呼叫一次生成。
- [x] 串流 token 在服務邊界內組合完成，通過驗證後才一次顯示；結果必須恰有合法 `verdict` 與單句 `roast`，不呈現 Markdown、前後說明或技術資訊。
- [x] 明確倒戈不得判為「信仰堅定」；護欄要求輸出不得重述或擴大玩家輸入中的攻擊性內容。
- [x] 沒有模型、所選模型消失、載入或生成失敗、20 秒逾時、無法解析、缺欄位、非法 verdict 或內容驗證失敗時，自動產生冠軍對應備援結果。
- [x] AI 完成、逾時或失敗接近同時發生時只接受第一個終態，結果不能被後續事件覆寫，Session 與 native 資源會正確取消及釋放。
- [x] 以可替換的裁決介面測試有效成功結果、三種合法判決、模型切換、所有失敗類別與完成競態；自動測試不載入真實模型。

## Comments

- Implemented session-scoped GGUF/MLX discovery and selection, on-device structured judgment through `BackendSelector`, `InferenceSession`, and `GenerationController`, plus transparent fallback handling.
- Validation: all 298 Flutter tests passed; analyzer completed with only the repository's existing 257 informational findings and no errors or warnings from this feature.
- Retained as completed prior capability. Its model discovery, selection, generation, validation, fallback, and lifecycle behavior remain reusable, while 07 replaces the retired tournament subject with the drawn stance and revalidates all twelve stances.
