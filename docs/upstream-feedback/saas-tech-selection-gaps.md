# saas-tech-selection 缺口記錄(回饋上游 blog)

> **用途**:app_tunnel 套用 `saas-tech-selection` skill 過程中發現的缺口與修正建議。
> **回饋對象**:`/Users/mac-eric/project/blog`(skill authoring upstream,remote `tarrragon/blog.git`)。
> **原則**(見 CLAUDE.md 6.5):本檔僅作缺口記錄與驗證,**正式修改一律在 blog 進行**,改完同步散佈回 app_tunnel。
> **發現版本**:skill v0.6.0
> **狀態(2026-06-16)**:三缺口**已全數回饋 blog**,commit `7c27eb0`(skill 3 處:interview-core / security / deployment-platform;backend 章節:0.21 delivery-mode 新段、7.2 identity 新問題節點+段、5.10 outbound-tunnel-entry 新章)。app_tunnel 本地 `.claude/skills/` 副本待下次 sync-pull 同步,勿手改。

---

## GAP-01:交付形態 gate 缺「單人自用自架基礎設施工具」形態

**現況**:Stage 0 的交付形態 gate(`references/interview-core.md` 定錨段)出口選項全是**架站/SaaS 形態**——託管平台(Shopify / Wix / Google Sites / WordPress)、BaaS(Firebase)、辦公生態自動化(Apps Script)、或「自建 SaaS」。

**缺口**:有一類專案是**單人自用、自架在本機、非對外服務**的基礎設施工具(本專案 app_tunnel:手機遠端操作本機終端機)。它:
- 沒有租戶、沒有多使用者、沒有使用者資料庫
- 「自建」成立,但走完整 SaaS 訪談(domain/event 切分、多租戶資料模型、容量假設)大部分維度空轉
- commodity domain check 的網站假設(認證/金流/表單/後台 CRUD)幾乎都不適用

**建議修正**:在交付形態 gate 增加一個分支「**個人/自用基礎設施工具(self-hosted personal tool)**」,走**極縮減流程**:跳過 domain/event 切分與多租戶,直接進「安全邊界 + 部署常駐 + 密鑰管理」三個維度。判讀單位仍是每條流程(可與其他形態混合)。

---

## GAP-02:認證維度缺「裝置綁定 + 共享密鑰」模型

**現況**:`references/dimensions/security.md` 的身份/認證假設偏 web-auth(帳號系統、SSO、OAuth、Access Service Token、per-tenant 隔離)。

**缺口**:單人自用情境的認證是**兩層、皆非 web-auth**:
1. 給「人」的:裝置原生生物辨識(Face ID / BiometricPrompt)防手機遺失
2. 給「連線」的:App 與本機端**共享密鑰**(secret 存 Keychain / Keystore),驗證「這條連線是我的 app」,擋掉拿到公開 tunnel 網址的外人

**建議修正**:security 維度增列「單人/裝置綁定認證」候選類型,附其專屬防護底線——secret 不可硬寫進 app(反編譯可挖)、走 WSS 傳輸、Keychain/Keystore 保管、可選 IP 限制當保險;tripwire = 「從單人變多人」時必須升級為真正的帳號系統。

---

## GAP-03:缺「把對外入口外包給 tunnel」的部署判讀

**現況**:`references/dimensions/deployment-platform.md` 的入口/部署假設是 PaaS / VM / container / k8s,對外服務經由公網 IP + 反向代理。

**缺口**:本專案的對外入口是 **Cloudflare Tunnel**——本機**主動外連**,路由器零開 port、對公網零暴露入口。這是「把入口能力整塊外包」的 commodity 判讀,現有 deployment 維度沒有這個選項。

**建議修正**:deployment-platform 維度增列「**outbound tunnel(cloudflared / Tailscale Funnel 類)**」候選,適用於「自架但不想暴露公網入口」;附防護底線(tunnel 網址不是密碼、不可當安全機制;前面必須再疊一層認證閘道)與 tripwire(流量/多入口成長時改評估正式反向代理)。

---

## 處理紀錄

- 2026-06-16 — GAP-01 / 02 / 03 全數回饋 blog(commit `7c27eb0`)。skill 與 backend 教學章節同步更新。

## GAP-04：§1 操作盤點缺「畫面狀態機 + 導航矩陣」輸出物

**現況**：§1 操作盤點（Stage 1 BDD）輸出一張「操作 / 主情境 / 失敗情境 / 前端引導 / 後端防護」表。表中「前端引導」只記錄一句概要行為（如「辨識失敗不讀憑證」「連線失敗顯示無法連線」），不要求展開為畫面狀態。

**缺口**：「前端引導」沒有系統性要求產出：
1. **畫面狀態機**：每個操作涉及幾個畫面？每個畫面有哪些狀態（idle / connecting / connected / error / disconnected）？每個狀態允許哪些操作？
2. **導航流**：每個畫面的進入路徑和退出路徑（每個畫面都需要 back/exit）
3. **Gate fallback**：每個 gate（biometric、network、auth）失敗時的替代路徑
4. **輸入機制**：涉及用戶輸入的操作，其輸入方式設計（keyboard type、submit flow、special keys）

**暴露案例**：
- W2-001：terminal 的 error/disconnected/connecting 畫面沒有返回按鈕（導航流缺失）
- W2-001：`biometricOnly: true` 沒有密碼 fallback（gate fallback 缺失）
- W2-001：terminal 沒有文字輸入框（輸入機制未設計）
- W2-001：首頁沒有 Enroll Device 入口（導航流缺失）

**建議修正**：§1 操作盤點表新增「畫面狀態矩陣」輸出物——每個操作對應的畫面列表 × 狀態 × 可用操作 × 退出路徑。作為 D3（前端）或新維度的 input。

---

## GAP-05：D8 Observability 缺 Client-side 連線生命週期 log

**現況**：D8 只規劃了 server 端稽核 log（Go proxy 的 JSON audit log on stderr），完全沒涵蓋 client（Flutter app）側。

**缺口**：Client-side 需要但未規劃的 log 層：
1. **連線生命週期 log**：connect → biometric → load credential → WS handshake → auth token → data flow → disconnect，每步 log
2. **Protocol-level 訊息 log**：WS frame type（text/binary）、payload 前綴（ttyd 的 `'0'` output prefix）、auth handshake 結果
3. **錯誤回報**：連線失敗的 error type + cause，不只是 UI 顯示

**暴露案例**：
- W2-002：auth token 沒有發送、text vs binary frame 錯誤——若有 protocol-level log，秒可定位
- W2-004（P0）：iOS 實機 WS stream 不觸發——沒有 log 只能盲測，被迫用最昂貴的 debug 方式（實機）
- W2 修復後補的 `developer.log('Step 1/2/3...')` 和 `'WS recv: type=...'` 都是事後 hotfix

**建議修正**：D8 拆為 D8-server（稽核 log，不變）+ D8-client（連線生命週期 + protocol 訊息 + 錯誤回報）。自用工具場景可用 `developer.log`，但需在設計階段確定 log 點清單。

---

## GAP-06：D9 Testing 缺三層測試策略分層

**現況**：D9 只提「CI gate + 測試 + timeout」，未區分測試層級。

**缺口**：三層測試各有不同價值，skill 未要求分層設計：

| 層 | 定義 | 現況 | 價值 |
|----|------|------|------|
| Unit（mock） | 用 fake 替代外部依賴 | 192 個，全綠 | 驗證內部邏輯，但遮蔽真實行為 |
| Protocol integration | 對真實 ttyd/proxy 驗證 WS 握手和訊框格式 | **不存在** | W2-002 的 text/binary frame + auth token 問題，此層秒可抓 |
| Screen state（widget test） | 覆蓋所有畫面狀態轉換 | 7 個 widget test，不覆蓋 back 按鈕 | W2-001 的導航缺失，此層應測 |

**暴露案例**：
- 「192 測試全過但實機全壞」——unit test 用 `FakeWebSocketChannel`，永遠不會發現 text vs binary frame 問題
- Go server 有 `integration_test.go` 但 Flutter app 的 `connection_flow_test.dart` 仍用 `FakeWebSocketChannel`

**建議修正**：D9 要求專案明確規劃三層測試策略，至少回答：「哪些行為只能靠真實服務驗證？」單人自用工具場景特別適合 protocol integration test，因為 server 就在本機。

---

## GAP-07：D3 前端選型缺輸入機制設計

**現況**：D3 只選了「原生 Flutter 終端機 UI（自接 WebSocket）」，理由是「改善手機打字體驗」，但未設計輸入機制本身。

**缺口**：「手機操 CLI」的打字體驗需要明確設計：
- keyboard type（visiblePassword 避免自動校正？）
- submit behavior（enter 送出 vs 逐字元送出？）
- special keys（Esc / Tab / Ctrl 組合鍵的 UI 方案）
- IME 行為（關閉建議、關閉自動校正、關閉個人化學習）

**暴露案例**：W2-001 diff 中的 `TextField` 參數（`enableSuggestions: false, autocorrect: false, enableIMEPersonalizedLearning: false, keyboardType: TextInputType.visiblePassword`）都是事後補的，不是設計產物。

**建議修正**：D3 選型含 UI 的專案，在選型表新增「輸入機制設計」子維度——keyboard behavior / submit model / special keys / IME policy。

---

## 待補充

<!-- 專案實作中若再發現缺口,持續往下追加 GAP-0x。回饋 blog 後在此標記已處理。 -->
