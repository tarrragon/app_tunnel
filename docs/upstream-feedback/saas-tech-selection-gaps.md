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

## 待補充

<!-- 專案實作中若再發現缺口,持續往下追加 GAP-0x。回饋 blog 後在此標記已處理。 -->
