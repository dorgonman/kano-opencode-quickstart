# OpenCode Workspace 同步工具

解決 OpenCode workspace 跨裝置和跨網域的資料同步問題。

## 問題說明

### 1. 跨裝置問題
OpenCode 的 workspace 資料儲存在本地：
- **Web 版**：瀏覽器 localStorage
- **桌面版**：本地檔案系統
- 換裝置後資料不會自動同步

### 2. 同一裝置不同網域問題
瀏覽器的 localStorage 按照網域隔離：
- `localhost:4096` 和 `your-machine.tailscale.net:4096` 是不同網域
- 資料完全獨立，不會自動同步
- 這是瀏覽器的安全機制

## 解決方案

### 工具 1：瀏覽器 localStorage 同步工具

**重點**：OpenCode 的 Web UI 狀態通常存在瀏覽器 `localStorage`，而 `localStorage` 會依照「origin（協議 + 網域 + 埠號）」隔離。

所以 `http://localhost:4096` 與 `https://xxx.tailscale.net:8443` 就算是同一台電腦，也一定是兩份不同的 `localStorage`。

**為什麼不能用 `http://localhost:4096/opencode-sync-localstorage.html`？**
- OpenCode 是 SPA，未知路徑通常會被前端 router 接走並導回 app。
- 即使你用其他 server 把 HTML 檔案 serve 起來，因為 origin 不同，也讀不到 OpenCode origin 的 `localStorage`。

**實務做法（純指令以外、但不改 source code）**：用 DevTools Console 進行匯出/匯入。

在來源 origin（例如 localhost）開啟 OpenCode，按 F12 → Console，貼上：
```js
const backup = {};
for (let i = 0; i < localStorage.length; i++) {
  const key = localStorage.key(i);
  if (key && key.startsWith('opencode.')) {
    backup[key] = localStorage.getItem(key);
  }
}
console.log(JSON.stringify(backup, null, 2));
```

在目標 origin（例如 Tailscale URL）開啟 OpenCode，貼上剛剛輸出的 JSON：
```js
const backup = /* paste JSON here */;
Object.entries(backup).forEach(([k, v]) => localStorage.setItem(k, v));
location.reload();
```

### 工具 2：專案匯出工具

**檔案**：`opencode-export-projects.ts`

**用途**：匯出所有專案和 workspace 設定

**使用方法**：
```bash
# 匯出到檔案
bun run opencode-export-projects.ts --output projects-backup.json

# 輸出到 stdout
bun run opencode-export-projects.ts > projects-backup.json

# 列出所有專案（不匯出）
bun run opencode-export-projects.ts 2>&1 | grep "•"
```

**匯出內容**：
- 專案 ID 和名稱
- Worktree 路徑
- Sandbox 列表
- 圖示和顏色設定
- 啟動指令
- 時間戳記

**不包含**：
- Session 對話記錄
- Message 內容
- 瀏覽器 localStorage（需手動匯出）

### 工具 3：專案匯入工具

**檔案**：`opencode-import-projects.ts`

**用途**：在新裝置匯入專案設定

**使用方法**：
```bash
# 匯入（跳過已存在的專案）
bun run opencode-import-projects.ts projects-backup.json

# 匯入並覆蓋已存在的專案
bun run opencode-import-projects.ts projects-backup.json --merge
```

**注意事項**：
- 會自動更新時間戳記
- 預設不覆蓋已存在的專案
- 使用 `--merge` 可強制覆蓋

## 完整遷移流程

### 情境 1：換新裝置

**在舊裝置**：
```bash
# 1. 匯出專案設定
bun run opencode-export-projects.ts --output backup.json

# 2. 在瀏覽器開啟 opencode-sync-localstorage.html
# 3. 匯出 localStorage 並複製
```

**在新裝置**：
```bash
# 1. 匯入專案設定
bun run opencode-import-projects.ts backup.json

# 2. 在瀏覽器開啟 opencode-sync-localstorage.html
# 3. 貼上並匯入 localStorage
# 4. 重新整理頁面
```

### 情境 2：同步 localhost 和 Tailscale

**在 localhost 開啟瀏覽器**：
1. 訪問 `http://localhost:4096`
2. 開啟 `opencode-sync-localstorage.html`
3. 點擊「匯出 OpenCode 資料」
4. 複製 JSON

**在 Tailscale 網址開啟瀏覽器**：
1. 訪問 `http://your-machine.tailscale.net:4096`
2. 開啟 `opencode-sync-localstorage.html`
3. 貼上 JSON
4. 點擊「匯入資料」
5. 重新整理頁面

## 更多資訊

關於跨瀏覽器行為的深入技術解釋以及伺服器端資料備份工具，請參閱：
- [OpenCode Portability & Cross-Browser Behavior](README-opencode-portability.md)

## 儲存位置

### 後端資料（專案設定）
```
~/.local/share/opencode/storage/
├── project/          # 專案 JSON 檔案
│   ├── <project-id>.json
│   └── global.json
├── session/          # Session 資訊
├── message/          # 訊息內容
└── part/             # 訊息片段
```

### 前端資料（UI 狀態）
- **Web 版**：`localStorage` 中的 `opencode.*` keys
- **桌面版**：Tauri plugin-store 檔案

## 技術細節

### localStorage 隔離機制
瀏覽器的同源政策（Same-Origin Policy）：
- 協議（http/https）
- 網域（localhost vs tailscale.net）
- 埠號（4096）

任一不同就是不同的 origin，localStorage 完全隔離。

### 專案 ID 生成
OpenCode 使用 Git 的 root commit hash 作為專案 ID：
```bash
git rev-list --max-parents=0 --all
```

這確保同一個 Git 倉庫在不同裝置上有相同的 ID。

## 常見問題

### Q: 為什麼 localhost 和 Tailscale 的資料不同步？
A: 這是瀏覽器的安全機制。不同網域的 localStorage 完全隔離，無法自動同步。

### Q: 可以自動同步嗎？
A: 目前沒有官方的自動同步功能。你可以：
1. 使用提供的工具手動同步
2. 只使用一個網域（統一用 localhost 或 Tailscale）
3. 使用桌面版（資料在檔案系統，可以備份）

### Q: 匯入會覆蓋現有資料嗎？
A: 預設不會。使用 `--merge` 參數才會覆蓋。

### Q: Session 對話記錄會一起匯出嗎？
A: 不會。這些工具只匯出專案設定。如需匯出 session，使用：
```bash
opencode export [sessionID]
```

## 安全注意事項

1. 備份檔案可能包含敏感資訊（專案路徑、設定）
2. 不要將備份檔案上傳到公開位置
3. localStorage 資料可能包含 token 和認證資訊
4. 建議定期清理舊備份

## 未來改進建議

向 OpenCode 團隊提出的功能請求：
1. 內建的 workspace 匯出/匯入功能
2. 雲端同步選項（類似 VS Code Settings Sync）
3. 跨網域資料同步機制
4. 自動備份功能

## 相關連結

- OpenCode GitHub: https://github.com/anomalyco/opencode
- 提交 Feature Request: https://github.com/anomalyco/opencode/issues
