# 【PlayPlus 普魯士國際】專業技術人力規格書 (B2B Engineer Profile)

> **文件保護宣告**：本文件所載之工程師經歷與技能說明，僅供合作評估與專案發包審核使用。為遵循保密協定（NDA）及個資保護規範，本文件已進行去識別化處理。所有商務與技術洽詢，請統一聯繫 PlayPlus 專屬業務窗口。

---

## 1. 識別與職級定位 (Profile Overview)

| 欄位 | 說明內容 |
| :--- | :--- |
| **工程師代號** | 例如：`資深後端工程師 - Ray S.` / `Lead Frontend Engineer - Alex` |
| **職級與專業定位** | 例如：資深軟體工程師 (Senior Software Engineer) |
| **總開發年資** | X 年以上（相關核心技術年資 X 年） |
| **專長主修領域** | 例如：企業內部客製化 ERP/CRM、高併發 RESTful API、微前端架構、跨平台 App 開發 |
| **可用工時與狀態** | □ 全職專屬投入（Full-time Dedicated / 40 hrs/wk）<br>□ 固定時數支援（Part-time / 20 hrs/wk）<br>□ 專案里程碑交付（Milestone Delivery） |
| **服務範疇界定** | □ 純程式碼開發支援 (Coding Support)<br>□ 系統架構規劃與流程梳理顧問 (Architecture & Consulting) |
| **商務聯繫窗口** | 專案經理 / 商務負責人（Email: `contact@playplus.com.tw` / 統編：54316089） |

---

## 2. 核心技術棧掌握度 (Tech Stack Matrix)

| 技術領域 | 具體技術項與版本 | 掌握度 / 年資 | 應用重點與經驗說明 |
| :--- | :--- | :---: | :--- |
| **後端與架構** | Ruby on Rails (Rails 6/7), Ruby | 精通 (X 年) | 具備高擴充性 MVC 架構、API-only 模式開發經驗 |
| | PostgreSQL / MySQL | 精通 (X 年) | 複雜關聯模型設計、Query 效能調校、Index 優化 |
| | Redis / Sidekiq | 熟練 (X 年) | 快取策略設計、背景非同步大量任務排程 |
| | RESTful / GraphQL API | 精通 (X 年) | 嚴謹 API 版本控制、Swagger/Postman 文件化 |
| **前端與介面** | Vue.js (Vue 3, Composition API, Pinia) | 精通 (X 年) | 單頁應用 (SPA)、狀態集中管理、響應式動態介面 |
| | Tailwind CSS / SCSS | 精通 (X 年) | 現代化原子 CSS、高質感 UI 動效、RWD 全裝置適配 |
| | TypeScript / JavaScript (ES6+) | 熟練 (X 年) | 型別安全架構、模組化封裝、非同步處理 |
| | MicroFrontend (微前端) | 熟練 (X 年) | 模組獨立部屬、跨系統介面無縫整合 |
| **行動與跨平台** | Flutter (iOS / Android), Dart | 熟練 (X 年) | 雙平台 App 產出、原生 Plugin 整合、推播與地圖功能 |
| **維運與部署** | Docker, Docker-compose | 熟練 (X 年) | 容器化封裝、本地開發環境一致性 |
| | CI/CD Pipeline (GitHub Actions) | 熟練 (X 年) | 自動化測試與部屬流程建置 |
| | 雲端平台 (AWS / GCP / Heroku) | 熟練 (X 年) | S3 儲存、RDS 資料庫、雲端主機佈署與維運 |

---

## 3. 系統與流程分析能力（PlayPlus 差異化優勢）

- **業務邏輯與流程轉化**：能直接與業務端/PM 溝通，快速讀懂複雜商業邏輯與流程圖 (Flowchart / Wireframe)，轉化為高擴充性的資料庫模型與系統架構，大幅降低發包方的溝通成本。
- **高精度 UI/UX 還原度**：具備深厚的元件化 (Component-driven) 思維，能精準還原 Figma 設計稿，並兼顧視覺美感、互動流暢度與載入效能。
- **系統長期利益把關**：秉持「幫客戶多想一步」原則，主動評估邊界條件 (Edge Cases)、擴充性與日後維護成本，避免過早優化與過度設計。

---

## 4. 代表性專案實績 (Project Experience)

> 註：為遵循 NDA 保密協定，客戶名稱已進行去識別化處理，著重技術實作與解決方案。

### 專案 A：【產業類型 + 系統名稱，例如：大型製造連鎖業 客製化 ERP 進銷存管理系統】
- **專案規模與背景**：每日數千筆訂單與料件出入庫異動，需整合多廠區資料與舊有會計系統。
- **擔任角色**：後端核心架構師 / 資深開發工程師
- **技術棧**：Ruby on Rails 7, PostgreSQL, Redis, Vue 3, Docker
- **實作重點與效益**：
  1. 設計符合 ACID 交易原則的進銷存庫存異動模組，徹底解決高併發庫存超賣與重複扣帳問題。
  2. 透過 Redis 快取與資料庫 Index 重構，將核心報表產出時間從原本 15 秒縮短至 0.8 秒。
  3. 與前端團隊協同定義 40+ 支 RESTful API，並建立完善的 Mock 與測試自動化流程。

---

### 專案 B：【產業類型 + 系統名稱，例如：多租戶 (Multi-tenant) SaaS 預約與會員營運平台】
- **專案規模與背景**：服務超過 500 家品牌門市之線上即時預約、點數核銷與 LINE 官方帳號推播。
- **擔任角色**：全端工程師 (Full-stack Engineer)
- **技術棧**：Ruby on Rails, Vue 3, Tailwind CSS, Sidekiq, LINE Messaging API
- **實作重點與效益**：
  1. 導入 Sidekiq 背景排程與佇列機制，平穩處理節慶推播時瞬間湧入的十萬級推播訊息。
  2. 串接綠界金流與發票系統，設計自動重試與交易對帳機制，確保帳務 100% 零遺漏。
  3. 封裝高度複用的 Vue 3 預約日曆元件，提升多裝置操作動線流暢度。

---

## 5. 協作流程與工程規範 (Development Workflow)

- **版本控制與代碼品質**：嚴格遵循 Git Flow / GitHub Flow 規範，採 PR (Pull Request) 與 Code Review 機制；導入 ESLint, RuboCop 與 Prettier 確保代碼風格一致。
- **測試與自動化 (QA)**：具備單元測試 (RSpec, Jest) 覆蓋核心邏輯經驗，並透過 GitHub Actions 執行自動化 CI/CD 測試與部署。
- **敏捷溝通與專案管理**：熟練使用 Jira、ClickUp、Slack、Notion、Postman 等工具，能無縫融入發包方既有之 Scrum 節奏（Daily Standup, Sprint Planning, Retro）。

---

## 6. 學歷背景與專業證照 (Education & Certifications)

- **學歷**：資訊工程 / 相關領域 學士 (或碩士)
- **專業證照 / 認證**：如 AWS Certified Solutions Architect、Scrum Master 認證（若有）
