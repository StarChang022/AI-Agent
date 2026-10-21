【PlayPlus 普魯士國際】專業技術人力履歷

# **Vincent** | Senior Backend Engineer

| 🛡️ 文件保護宣告 本文件所載之工程師經歷與技能說明，僅供合作評估與專案發包審核使用，已進行去識別化處理。 |
| :---- |

## **基本資料與職級定位**

| 欄位 | 說明內容 |
| :---- | :---- |
| 工程師代號 | Vincent Yang |
| 職級與專業定位 | 資深後端工程師 / Rails 系統架構師 / 雲端與系統解決方案顧問 |
| 總開發年資 | 13 年以上軟體開發經驗 |
| 專長主修領域 | 企業級管理系統架構規劃。 跨平台/APP 後端 API 設計。 技術解決方案與風險評估。 資料庫效能調校與高可用性。 |
| 服務範疇界定 | 包含系統架構規劃、資料庫 Schema 設計與流程梳理顧問。 核心 API 開發、APP 後端整合、多雲環境部署與技術選型利弊評估。 |

## **核心技術棧掌握度**

| 技術領域 | 具體技術項 | 應用重點與經驗說明 |
| :---- | :---- | :---- |
| 後端 | Ruby on Rails (Rails 6/7), Ruby 3.x | 精通 Rails API 架構。 RESTful 設計。 ActiveRecord 進階查詢與 Service Object 模組化設計。 |
| 資料庫與儲存 | PostgreSQL / MySQL | 複雜關聯表 Schema 規劃。 Index 優化與 Query 效能調校。 |
| 快取與背景佇列 | Redis, Sidekiq | 分散式鎖 (Redlock)。 大量非同步推播與排程任務處理。 |
| API 設計與整合 | RESTful API, OpenAPI (Swagger) | 嚴謹的版本控制。 JWT / OAuth2 身份驗證。 第三方金物流與發票 SDK 串接。 Mobile API 最佳化與推播整合 (FCM / APNs)。 |
| 維運與部署 | Docker, Docker-compose | 本地容器化開發環境配置。 Multi-stage build 產出輕量化 Production Image 。 |
|  | AWS (EC2, RDS, S3), GCP, Heroku, Linode | 多雲架構部署與評估。 資料庫自動備份與異地備援。 靜態資源 CDN 整合與資安防護。 |
|  | CI/CD (GitHub Actions) | 自動化 RuboCop 語法檢查。 RSpec 單元測試與自動化 Staging 部署。 |

## **系統與流程分析能力（核心優勢）**

* **技術解決方案評估與風險控管（幫客戶多想一步）**： 多年技術與系統架構經驗，能依據客戶業務階段、預算與未來擴充需求，快速評估多個解決方案的「優勢、長期維護成本與潛在架構風險」，避免客戶走入過度設計或擴充受限的盲區。
* **深入業務邏輯與流程梳理**： 擅長與非技術背景之業務/PM 深度溝通，能從抽象的流程概念，轉換為具體的系統流程。
* **跨端與 APP 後端整合規劃**： 深刻理解 Web 與 Mobile 雙端架構特性，在規劃 API 時兼顧網路斷線容錯、資料快取策略與 App Store 審查週期的版本向下相容性。
* **清晰文檔與溝通效率**： 透過 Swagger / Postman 產出完整 API 規格書與 Request/Response Mock 資料，讓前後端能並行開發，極大化專案推進速度。

## 代表性專案實績

### 智慧健康營養減脂中心 APP

* **專案規模**： 支援數萬名會員日常三餐飲食紀錄、生理數據追蹤與專業營養師線上諮詢，承載高頻餐食照片上傳、即時 WebSocket 互動與週期性自動扣款。  
* **擔任角色**： 後端核心架構師 / 系統架構規劃 (Lead Backend Architect)  
* **技術棧**： Ruby on Rails 7 (API-only), MySQL, Redis, Sidekiq, ActionCable (WebSocket), ECPay (定期定額/電子發票), Vue 3, Docker, AWS
* **動態營養計算引擎與多維數據儀表板**： 封裝 BMR / TDEE 演算法與六大類食物（主食、蛋白質、蔬果等）動態份量換算 Service Objects，支援會員個人化自訂目標；透過關聯查詢優化與快取策略，實現秒級渲染跨月度飲食/體重/飲水趨勢 Dashboard。  
* **WebSocket 低延遲即時通訊與推播架構**： 採用 ActionCable 建置雙向即時通訊系統，支援會員與營養師「1對1 專屬線上諮詢」與「主題社群互動」，整合圖片即時串流、已讀狀態同步與背景非同步未讀推播。  
* **自動化週期訂閱金流與電子發票整合**： 完整串接綠界 (ECPay) 定期定額扣款與電子發票/載具開立 API；以 AASM 狀態機嚴密管理會員訂閱週期、過期判定與失敗自動補扣機制，達成 100% 無人化帳務運作。  
* **非同步媒體處理與大數據批次匯出**： 運用 Sidekiq + Redis 建立非同步佇列，自動將大量餐食上傳照片進行 WebP 輕量化壓縮；針對營養師後台設計高效記憶體管理的 Excel 批次數據匯出機制，確保伺服器穩定與高可用性。  
* **嚴密五級 RBAC 權限體系與 API 規格化**： 透過 Devise Token Auth 與 CanCanCan 實作涵蓋訪客、一般、試用、付費至 VIP 1對1 的五層級權限隔離，確保健康隱私安全；全面導入 Rswag (OpenAPI/Swagger) 產出規格文件，大幅加速跨端並行開發。

### 線上影音串流與課程電商平台

* **專案規模**： 支援頂尖藝術師資與數萬名學員，涵蓋線上錄播課（單元式章節）、直播互動課（Live）、實體線下課（Onsite）與多課程組合包（Bundle Course）；整合高畫質安全防盜影音串流、電商購物車促銷引擎與全自動化電子發票。  
* **擔任角色**： 後端核心架構師 / 系統架構規劃 (Lead Backend Architect)  
* **技術棧**： Ruby on Rails 7.1, MySQL, Redis, Sidekiq, Bunny Stream / Vimeo API (防盜串流), ECPay (金流/電子發票), Tailwind CSS, Google Cloud Storage (GCS)
* **學習進度追蹤引擎**： 設計高度可擴充的課程資料模型，同時支援「單元錄播課、直播課程、實體工作坊與組合套裝課程」；建立學習歷程模組，精準記錄章節播放秒數、完課進度百分比與書籤標記。  
* **高畫質安全影音串流**： 深度整合 Bunny Stream CDN 與 Vimeo API，實作動態 Token 簽署生成、過期驗證與防盜鏈安全保護，確保高解析度繪畫教學影片低延遲秒開，同時杜絕未授權存取與外洩盜錄風險。  
* **電商結帳與複合促銷 / 折扣碼引擎**： 打造完整購物車與訂單交易核心，支援全站階梯式滿額促銷（Promotion）、套裝合購折抵（Bundle）與自訂折扣碼規則（PromoCode 次數/期間/專屬課程限制），透過資料庫交易機制確保高併發搶購時促銷額度精準扣抵。  
* **金流串接與電子發票自動化**： 完整串接綠界 (ECPay) 信用卡、ATM 虛擬帳號與超商代碼金流；實作財政部合規電子發票自動開立、手機載具/統編驗證與折讓作廢機制，付款完成後即時非同步自動派發課程權限。  
* **多語系 / SEO 全站優化**： 運用 Sidekiq + Redis 佇列處理開課通知信件、發票開立與資料同步；整合 Globalize 繁中/英文多語系架構，並搭配 FriendlyID 與 Meta-Tags 最佳化，大幅提高課程在搜尋引擎的曝光效益。

## **協作流程與工程規範**

* **代碼品質與測試**： 嚴格落實 RuboCop 規範，遵循 StandardRB 代碼風格；核心 Model、Service 與 Controller 全面撰寫 RSpec 單元測試與 Request Spec。  
* **版本控制與工作流**： 標準 Git Flow 流程，所有功能開發均開立 Feature Branch 並經 PR 與 Code Review 通過後合併至 Main 分支。  
* **專案管理與協作**： 熟練使用 Notion 管理專案與任務卡，熟悉 Slack / LINE 異步溝通，具備豐富的遠距團隊協同開發經驗。