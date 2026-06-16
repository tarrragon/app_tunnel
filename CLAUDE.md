# CLAUDE.md

本文件為 Claude Code 在此專案中的開發指導規範。

---

## 1. 專案身份

**專案名稱**: app_tunnel

**專案目標**: 手機透過 Cloudflare Tunnel 遠端操作本機真實終端機的**單人自用工具**。鏈路:`Flutter app（Face ID）→ 帶密鑰連線 → CF Tunnel → 本機 Go proxy（驗密鑰）→ ttyd → zsh`。

**專案類型**: 單人自用自架基礎設施工具(非 SaaS、非多租戶、非對外服務)。**Monorepo** 管理:Flutter 手機端 + Go 本機 proxy。

| 項目 | 值 |
|------|------|
| **語言** | Flutter/Dart(`app/` 手機端)、Go(`server/` 本機 proxy) |
| **實作代理人** | `parsley-flutter-developer`(app)、`fennel-go-developer`(server) |
| **識別特徵** | `app/pubspec.yaml`、`server/go.mod` |

**啟用的 MCP/Plugin**:

- dart - Dart/Flutter 開發工具
- serena - 語意程式碼操作
- context7 - 文件查詢

---

## 2. 核心價值

@.claude/rules/core/quality-baseline.md

---

## 3. 規則系統

@.claude/rules/README.md

---

## 4. Skill 指令

@.claude/pm-rules/skill-index.md

---

## 5. 方法論參考

@.claude/pm-rules/methodology-index.md

---

## 6. 技術選型與架構決策

### 已決策(依 saas-tech-selection Stage 5 格式:理由 / 防護 / tripwire)

**D1 — server 語言:Go**
- **理由**:proxy 職責極小(接 WSS、驗密鑰、轉發 WS 到 `localhost:7681`),Go stdlib `httputil.ReverseProxy` 從 1.12 起透明支援 WS upgrade,約 50 行;編譯成單一靜態 binary,launchd 常駐零執行期依賴;靜態型別 + 小攻擊面適合「通往完整 shell」的安全敏感長駐服務。PHP(請求-回應模型,逆語言慣性)、Python(拖 venv,async WS 較囉嗦)皆次之。
- **防護**:proxy 是 shell 的唯一對外閘道,密鑰驗證失敗一律拒絕、不得 fallback 放行;ttyd 自身 basic auth 保留為最後一道防線。
- **tripwire**:若未來改為「proxy 自行用 `creack/pty` 開 PTY、拿掉 ttyd」,重評協議層;若從單人變多人,Go 仍適用但認證模型需整個重設計。

**D2 — repo 管理:Monorepo(單一 repo app_tunnel)**
- **理由**:app 與 proxy 共用同一份契約(密鑰格式、WS 握手),一起改一起發、需 atomic commit;單人單產品、無獨立發布節奏、無不同可見性、無跨多消費端重用——polyrepo 的四個成立條件一個都不符。
- **防護**:契約(密鑰格式 / WS 子協議)集中在 `docs/`,app 與 server 共同引用,避免雙邊定義漂移。
- **tripwire**:若日後 server 要被多個 app/專案重用,或需開源其一而另一私有,再評估拆出 polyrepo。

**D3 — 手機端:原生 Flutter 終端機 UI(自接 WebSocket)**
- **理由**:自渲染終端機(xterm 類)+ 自接 ttyd WS 子協議,可大幅改善手機打字體驗(Esc/Ctrl/方向鍵),這是「手機操 CLI」最有感的改善;代價是工程量大於 WebView 內嵌。
- **防護**:secret 存 iOS Keychain / Android Keystore、不硬寫進 app(反編譯可挖);傳輸走 WSS(CF Tunnel 段加密);每次連線前過一次 Face ID / BiometricPrompt。
- **tripwire**:若打字體驗投報率不如預期,退回 WebView 內嵌 ttyd 方案。

**D4 — 三層認證(縱深防護)**
- **理由**:失敗代價是「整台機器的 shell 外洩」,單層不可接受。三層各自獨立:① Cloudflare Access Service Token(邊緣,未授權流量到不了主機)② Go proxy 本機密鑰 `X-App-Tunnel-Token`(擋拿到 tunnel 網址的外人)③ ttyd basic auth(最後防線)。tunnel 網址**不是密碼**,不可當安全機制。
- **防護**:proxy 驗錯/缺密鑰一律回 404(不洩漏存在)、constant-time 比較;**雖然選了現在就寫 Go proxy**,CF Access 已先在邊緣擋,proxy 密鑰是縱深第二層。
- **tripwire**:從單人變多人 → 三層全部重設計為帳號系統 + 動態下發。

**D5 — 運作姿態:Named tunnel + 自有網域,手動起停**
- **理由**:固定網址(app 寫死 endpoint)但**不開機自啟、不 24/7 常駐**,用時起、用完關,把暴露窗壓到最小;符合「大道至簡」與「用完關掉」安全建議。
- **防護**:launchd 不放 `~/Library/LaunchAgents`、systemd 不 `enable`;停用即關三個行程。
- **tripwire**:若改 always-on 常駐,暴露窗放大 → 需補 WAF / 入口限流 / 告警。

**D6 — 密鑰保管:可插拔後端(跨平台)**
- **理由**:proxy **可能跑在 Linux**(非僅 macOS),故密鑰載入抽象成多後端:`keychain`(macOS 預設,不落明文)、**`file`(0600,Linux / 通用 fallback,保留)**、`env`(CI/容器)。Go binary 跨編譯 darwin/linux 零改碼。
- **防護**:`file` 後端啟動時檢查權限,過寬(group/other 可讀)即拒絕;密鑰檔與憑證一律 `.gitignore`。
- **tripwire**:secret 數量 > 10 或存取主體變多 → 引入 secret manager。

**D7 — 憑證配對:QR enrollment(設計 A 對稱,MVP)**
- **理由**:把「手動複製 64 字元密鑰」這個最易錯/易外洩環節,換成**視覺 air-gap 掃描**(不經剪貼簿/雲)。主機 `enroll` 子指令產密鑰、組憑證包、`qrencode -t ANSIUTF8` 印 ASCII QR(無頭 Linux 亦可),手機掃一次存 Keychain。定位為**一次性配對**(遠端情境無法每次掃),runtime 認證不變(仍靜態 header),proxy 主路徑不改。
- **防護**:QR 含全部憑證明文、僅顯示一次,勿截圖;密鑰用 `crypto/rand` 產生;掃描後主機端密鑰已落後端、QR 即關。
- **tripwire → 設計 B(非對稱)**:要「主機端零可重用密鑰 + 私鑰硬體保護」時升級——手機金鑰對、QR 回送公鑰、runtime 改挑戰-回應(nonce 簽 + replay 防護),`protocol` 升版、proxy 改驗簽握手。詳見 `docs/contract.md`。

**D8 — Observability:結構化稽核 log,不建 pager**
- **理由**:單人、無 SLA,「掛了」你連線即知,不需 uptime 監控/pager。但 shell 閘道的關鍵訊號是**誰連上了**——proxy 記錄**放行**與拒絕連線(結構化 JSON、真實 client_ip 取自 CF-Connecting-Ip)、依賴(ttyd)失敗分類為 ERROR。
- **防護**:**絕不 log PTY 內容**(你打的指令含密碼)——透明 proxy 天然滿足,Phase 2 自開 PTY 做錄影時必須遵守。
- **tripwire**:想「有人連上即時知道」→ 加連線推播(ntfy.sh 類)到手機(本次選不做)。

**D9 — Reliability:CI gate + 測試 + timeout**
- **理由**:proxy 是安全敏感程式,可靠性最低標 = `go test` gate + 認證閘道測試。已建單元測試(認證閘道 / secret 後端 / 權限 / enroll)、CI(vet+test+跨平台 build)、graceful shutdown、proxy→ttyd 明確 timeout。
- **防護**:外部呼叫(連 ttyd)有 timeout;go.mod/go.sum 鎖依賴(目前零外部依賴,Phase 2 加 WS/pty lib 時 go.sum 生效)。
- **N/A**:重試/idempotency(無編排操作)、webhook 驗簽(無 webhook)。

**State-Storage — 無 application datastore**
- 本工具無 source-of-truth 資料庫:proxy 密鑰(`enroll` 可重產)、cloudflared 憑證(`tunnel create` 可重建)、CF Access 設定(在後台)皆可重建,不需備份;migration/多租戶隔離 N/A。
- **觸發型維度**:cache / async-queue / capacity-performance 皆**未觸發**(無高頻讀、無不可丟 event、單人無高峰)。
- **tripwire**:若加 session 紀錄/指令解釋歷史(embedded SQLite),state-storage 才變真,屆時啟用備份/migration 底線。

### 目錄結構

```
app_tunnel/
├── app/          # Flutter 手機端(原生終端機 UI)
├── server/       # Go 本機 proxy(驗密鑰 + WS 轉發)
├── deploy/       # ttyd / cloudflared config、launchd plist、setup 腳本
├── docs/         # 契約規格、upstream-feedback 缺口記錄
└── CLAUDE.md
```

### 框架缺口待回饋

套用 saas-tech-selection 時發現的 3 個缺口已記於 `docs/upstream-feedback/saas-tech-selection-gaps.md`(交付形態 gate 缺自用工具形態、認證維度缺裝置綁定+共享密鑰、部署維度缺 outbound tunnel),待回 blog 修正。

---

## 6.5 需求確認協議與框架回饋

### 採用 saas-tech-selection 模式（特例調整）

本專案的初始需求確認**採用 `saas-tech-selection` skill 的訪談協議**(定錨 → 交付形態 gate → BDD 操作盤點 → DDD domain/event 切分 → 技術維度展開)。

**但本專案是特例**:它**與伺服器有關、卻不是架站(site-building)**。而 `saas-tech-selection` 現有內容(v0.6.0)主要針對「架站 / 後端 SaaS」場景設計(交付形態 gate 預設選項為 Shopify / Wix / WordPress / Firebase 等託管平台、commodity domain 假設認證/金流/表單等網站能力)。因此套用時需:

- 沿用其**訪談骨架與防護底線哲學**(行為先於系統、領域事件骨架、問漏才是成本、底線不可沉默跳過)。
- 對**不適用架站假設的維度**做調整判讀(交付形態 gate 的「託管平台」選項、網站導向的 commodity domain check 等,在「伺服器但非架站」場景下需重新詮釋或替換)。

### 缺口回饋上游(強制)

套用過程中**額外確認、發現缺口、或需修正的部分**,不可只停在本專案 —— 必須**回饋給 `saas-tech-selection` skill 做功能擴充與修正**。

**上游關係(authoring upstream)**:`saas-tech-selection` 的權威來源在 **`/Users/mac-eric/project/blog`**(其 `.claude/` 為獨立 git repo,remote `tarrragon/blog.git`)。app_tunnel 是**下游消費端**,本地 skill 會被上游同步覆蓋。

**回饋流向**:

```
app_tunnel(消費端,發現缺口)
        │  記錄「伺服器但非架站」場景的調整與新增需求
        ▼
/Users/mac-eric/project/blog(authoring upstream,實際修改 skill)
        ▼
tarrragon/claude(框架散佈,其他專案受惠)
```

**原則**:修正在 app_tunnel 本地驗證可行後,**回到 blog 修改 skill 本體**再同步散佈。直接改 app_tunnel 本地的 `.claude/skills/saas-tech-selection/` 會在下次同步時遺失,因此本地僅作**驗證與缺口記錄**,正式修改一律在 blog 進行。

---

## 7. 專案文件

### 任務追蹤

| 文件 | 用途 |
|------|------|
| `docs/todolist.yaml` | 結構化版本索引（Source of Truth） |
| `docs/work-logs/` | 版本工作日誌 |
| `CHANGELOG.md` | 版本變更記錄 |
| `docs/work-logs/v{version}/tickets/` | Ticket 文件 |

---

## 8. 里程碑

- v0.0.x: 基礎架構與技術選型
- v0.x.x: 開發階段,逐步實現功能
- v1.0.0: 完整功能

---

*專案入口文件 - 詳細規則請參考 .claude/rules/ 目錄*
