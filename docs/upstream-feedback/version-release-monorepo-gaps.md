# version-release CLI：monorepo / trunk 場景缺口回饋

> 消費端：app_tunnel（monorepo：app/ Flutter + server/ Go，trunk all-on-main，單一版本號 tag 整個產品）。
> 上游：tarrragon/claude.git 的 `.claude/skills/version-release`。
> 發現於 TD-P3-004（v1.2.0）。本專案已用專案 config + worklog 對齊在地解決可用性，但下列為 CLI 本體層級問題，需回上游修正。
>
> **上游追蹤**：framework-issue [tarrragon/claude#4](https://github.com/tarrragon/claude/issues/4)（相關已關閉 #3：Flutter version detection 假陽性）。取捨判斷已寫入 skill `references/monorepo-versioning-strategy.md`（待 sync-push 上游）。

## 在地已解決（專案 config）

- `.version-release.yaml` 補 `project_type: flutter` + `version_source.primary: app/pubspec.yaml`，並把 `worklog_path_pattern` 從扁平 `docs/work-logs/v{version}` 改為巢狀 `docs/work-logs/v{major}/v{major_minor}/v{version}`，與 `ticket` CLI 的放置一致。補上 `v{version}-main.md` 後 `check` 通過、`release --dry-run` 正確產出 trunk git-ops。

## 上游待修缺口

### 1. `check_version_sync` 無條件套用 Chrome Extension 雙版本邏輯

`check_version_sync` 不論 `project_type` 一律呼叫 `check_version_sync_dual` 並印「版本同步檢查（Chrome Extension 雙版本來源）」「package.json 版本: …」。非 chrome-ext 專案看到此報告會誤以為被當成 Chrome Extension（實際 `detect_project_type` 判定正確，只是報告誤導）。
建議：`project_type != chrome-ext` 時跳過 dual-source 報告，或改印與 `project_type` 對應的版本源摘要。

### 2. `detect_version_files` 不採用 `version_source.primary`，只掃根目錄

設定 `version_source.primary: app/pubspec.yaml` 後，`detect_version_files` 仍只掃根目錄候選檔，找不到即印「未偵測到版本檔案（package.json/manifest.json）」，且 release 不會 bump `app/pubspec.yaml`。monorepo 子目錄版本源無法自動 bump。
建議：`detect_version_files` / 版本確認步驟應優先採用 `version_source.primary`（含子目錄相對路徑）。

### 3. 分支慣例警告未尊重 `release_workflow: trunk`

`release_workflow: trunk` 下，`check_version_sync` 仍印「當前分支: main（慣例為 feature/v1.2）」。trunk = all-on-main，main 即預期分支。
建議：`release_workflow == trunk` 時跳過 feature 分支慣例警告（git-ops 步驟已正確跳過 feature 合併，僅此警告未對齊）。

### 4. worklog 路徑：version-release 與 ticket CLI 預設不一致

`ticket` CLI 將 ticket 放巢狀 `v{major}/v{major_minor}/v{version}/`，但 version-release 的 `worklog_path_pattern` 預設為扁平（非 flutter 類型）。兩個框架工具對 worklog 放置不一致，consumer 需手動對齊 config 才能讓 preflight 找到 worklog。
建議：兩 skill 共用 worklog 路徑解析，或在文件明示需對齊 `worklog_path_pattern` 與 ticket CLI。

### 5. preflight 要求 `v{version}-main.md` 固定命名

`check_worklog_completed` 僅認 `v{version}-main.md`（或舊結構 `v{major_minor}.0-main.md`）為主日誌。手動建立的主日誌若用其他描述後綴（如 `v1.0.0-mvp-remote-terminal.md`）不被認可。
建議：放寬主日誌偵測（如取版本子目錄內任一 `v{version}*.md` 為主日誌），或文件明示 `-main.md` 為強制命名。
