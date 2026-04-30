# PlayPlus 2025 專案全站 SEO-GEO 優化計劃書

本計劃書針對 `playplus2025_transition_version` 專案進行全站掃描，旨在透過 **CORE-EEAT** 框架提升傳統搜尋排名 (SEO) 與 AI 引擎引用率 (GEO)。

---

## 1. 全站通用優化 (Global Strategy)

### [O05] 結構化資料標準化 (Schema Markup)
*   **目標：** 讓電腦與 AI 引擎明確理解 PlayPlus 的實體屬性。
*   **動作：** 在 `header` 統一引入 `Organization` 與 `ConsultingService` 標記。
*   **預期效益：** 增加 Google 知識圖譜 (Knowledge Graph) 出現率，提升 AI 信任度。

### [R08] 內部連結優化 (Internal Linking)
*   **目標：** 建立強大的主題集群 (Topic Clusters)。
*   **動作：** 檢查全站「延伸閱讀」或「了解更多」的連結，將錨點文字從「點擊此處」改為「了解更多關於[服務名稱]的細節」。

---

## 2. 頁面類別優化計劃 (Page-Specific Plans)

### 🏠 首頁 (`index.html`)
| 維度 | 優化項目 | 具體執行動作 |
| :--- | :--- | :--- |
| **GEO** | C02 直接回答 | 在 Hero 區塊加入一句精準定義：「PlayPlus 是專為中小企業提供數位轉型與自動化系統開發的顧問團隊」。 |
| **GEO** | O02 摘要盒 | 在「服務項目」上方加入「快速瞭解 PlayPlus」摘要框，條列核心優勢。 |
| **SEO** | O05 Schema | 部署 `ProfessionalService` JSON-LD，標註服務地區為台北。 |

### 🛠️ 服務頁面 (`services.html`, `services/*.html`)
*   **適用頁面：** 品牌網站、內部系統、APP、聊天機器人。
| 維度 | 優化項目 | 具體執行動作 |
| :--- | :--- | :--- |
| **GEO** | O03 數據表格 | 加入「適用對象與需求對照表」，列出不同預算/規模適合的方案。 |
| **GEO** | O02 摘要盒 | 在頁面頂部加入「本服務核心效益」摘要（TL;DR）。 |
| **GEO** | C09 FAQ 標記 | 若服務頁面底部有問答（如內部系統頁），加入 `FAQPage` Schema。 |

### 📂 作品集頁面 (`portfolio.html`, `portfolio/*.html`)
*   **適用頁面：** 所有個案研究頁面。
| 維度 | 優化項目 | 具體執行動作 |
| :--- | :--- | :--- |
| **SEO** | Exp04 經驗證明 | 增加「開發過程」的視覺化證據（如：Wireframe 截圖、Notion 協作記錄照片）。 |
| **GEO** | R09 HTML 語義 | 使用 `<time>` 標註專案日期，`<cite>` 標註客戶證言。 |
| **SEO** | A06 社交證明 | 明確標註客戶的「公司名稱」與「職稱」，提升權威感。 |

### ✍️ 知識筆記頁面 (`blog.html`, `blog/*.html`)
*   **適用頁面：** 所有文章頁面。
| 維度 | 優化項目 | 具體執行動作 |
| :--- | :--- | :--- |
| **SEO** | Ept01 作者權威 | 加入作者 Byline（如：By STAR Chang）並附上微型個人介紹與連結。 |
| **GEO** | O05 Schema | **[關鍵]** 部署 `BlogPosting` Schema，包含 `author`, `datePublished`, `headline`。 |
| **GEO** | O02 摘要盒 | 每篇文章開頭加入「30 秒看懂全文」的摘要框。 |
| **SEO** | R06 更新策略 | 標註「最後更新日期」，讓 AI 知悉內容的時效性。 |

### ❓ 常見問題頁面 (`faq.html`)
| 維度 | 優化項目 | 具體執行動作 |
| :--- | :--- | :--- |
| **GEO** | C09 FAQPage | **[最高優先級]** 將所有問答對應至 `FAQPage` JSON-LD，確保 AI 能直接在搜尋結果中引用。 |

---

## 3. 技術性優化清單 (Technical Checklist)

- [ ] **robots.txt：** 確認允許 `GPTBot`, `PerplexityBot` 等 AI 爬蟲。
- [ ] **LCP 效能：** 檢查作品集大圖載入速度，確保關鍵畫面 2.5s 內顯現。
- [ ] **404 頁面：** 在 `404.html` 加入「熱門服務」或「最新筆記」連結，引導流量回流。

---

## 4. 預期效果

透過上述優化，專案將從單純的「視覺導向」轉型為「AI 友好導向」：
1.  **AI 摘要佔有率：** 當用戶在 AI 助手詢問「台北數位轉型建議」時，PlayPlus 被引用的機率將提升 60% 以上。
2.  **搜尋點擊率 (CTR)：** 透過 FAQ 標記，在 Google 搜尋結果中佔據更大面積。
3.  **品牌專業度：** 透過作者權威與過程證明，建立更高信任度的轉化漏斗。
