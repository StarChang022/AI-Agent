我需要你將 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Official_Website/文案內容` 專案以 Static Site Generation 網頁渲染技術打包成靜態網站，寫出相應的執行腳本。
先將 `/Users/starchang/Documents/CloudFolder/GitHub/playplus2025_transition_version` 資料夾內容清除，再將打包結果直接輸出至 `/Users/starchang/Documents/CloudFolder/GitHub/playplus2025_transition_version` 資料夾。記得不要刪除 GitHub 相關檔案，避免造成 GitHub 判定專案被刪除。

以下是每個項目的需求。

# blog

1. 將 blog 資料夾內的 .md 檔案套用 blog/template.html 模板，一律打包為 blog 裡面的文章（例如 20250604-web-design-budget.md 打包成 blog/20250604-web-design-budget.html）。依照以下 `## blog 文章` 生成對應的 html 靜態頁面。

2. blog.html 是 blog 的列表頁。依照以下 `## blog 列表` 生成對應的 html 靜態頁面。

## blog 文章

1. blog/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. blog/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. blog/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. blog/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. blog/template.html 裡面的 <div class="tags"> 的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。
6. blog/template.html 裡面的 🟢Date 帶入對應 .md 檔案的 # Head Editor 的 **date** 。
7. blog/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部，將 <div class="content column gap-frame-half"> 裡面的內容帶入，帶入時必須配合上下網進行適當的縮排。

## blog 列表

1. blog.html 依照日期（對應 .md 檔案的 # Head Editor 的 **Date**）新到舊排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 blog.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 blog.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 blog.html 裡面的 🟢Date 帶入對應 .md 檔案的 # Head Editor 的 **date** 。
5. 承1，將 blog.html 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。
6. 承5，將 blog.html 裡面的 🟢Filter 根據 🟢TAGs 帶入的值，往上去 <div class="grid-filter" data-container="#blogs"> 容器內尋找對應的 data-filter （對應數量），以空格隔開。例如 tags 為「談談數位轉型, 釐清需求, 決策與規劃」，則 data-filter 為「mindset needs planning」。

# portfolio

1. 將 portfolio 資料夾內的 .md 檔案套用 portfolio/template.html 模板，一律打包為 portfolio 分類裡面的文章（例如 frontier.md 打包成 portfolio/frontier.html）。依照以下 `## portfolio 文章` 生成對應的 html 靜態頁面。

2. portfolio.html 是 portfolio 的列表頁。依照以下 `## portfolio 列表` 生成對應的 html 靜態頁面。

## portfolio 文章

1. portfolio/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. portfolio/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. portfolio/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. portfolio/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. portfolio/template.html 裡面的 🟢ArticleForeword 帶入對應 .md 檔案的 # Head Editor 的 **foreword** 。
6. portfolio/template.html 裡面的 🟢UrlWebsite 帶入對應 .md 檔案的 # Head Editor 的 **urlwebsite** 。
7. portfolio/template.html 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。
7. portfolio/template.html 裡面的 <div class="tags"> 的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。
8. portfolio/template.html 裡面的 「<!-- GEO Summary Box Editor -->」 帶入對應 .md 檔案的 # GEO Summary Box Editor 全部，將 <div class="summary-box background-skin p-3 radius-6 my-4 text-start"> 裡面的內容帶入，帶入時必須配合上下網進行適當的縮排。
9. portfolio/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部，將 <div class="content column gap-frame-half"> 裡面的內容帶入，帶入時必須配合上下網進行適當的縮排。
10. 當對應 .md 檔案的 # Head Editor 的 **confidential** 為「Yes」，就要讓 portfolio/template.html 裡面的 ### portfolio confidential 的段落需要顯示。反之，當 **confidential** 為「No」，該段落移除。

### portfolio confidential

<div class="tips">
	<div class="column">
		<p>企業內部系統會關係到保密性，畫面僅以黑白設計稿呈現。</p>
	</div>
</div>

## portfolio 列表

1. portfolio.html 依照日期（對應 .md 檔案的 # Head Editor 的 **Date**）新到舊排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 portfolio.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 portfolio.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 portfolio.html 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
5. 承1，將 portfolio.html 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。
6. 承5，將 portfolio.html 裡面的 🟢Filter 根據 🟢TAGs 帶入的值，往上去 <div class="filter column gap-micro"> 的 <div class="grid-filter" data-container="#portfolios"> 容器內尋找對應的 data-filter （對應數量），以空格隔開。例如 tags 為「企業內部系統, 電子業, 中型專案」，則 data-filter 為「system electronics medium-project」。

# public 資料夾

1. internal-system-briefing.pdf : 直接打包，無需調整。
2. openapi.yaml : 直接打包，無需調整。
3. sitemap.xml : 依照 `## portfolio sitemap` 和 `## blog sitemap` 規則打包，沒提到的部分則維持現狀。

## portfolio sitemap

「<!-- Portfolio -->」底下區塊內的負責管理 portfolio.html 和 portfolio 資料夾內的 .html 檔案的 sitemap 路徑。
因為 portfolio.html 這個頁面是固定的，所以主要是管理 portfolio 資料夾內的 .html 檔案。

1. 當 portfolio 資料夾內的文章有增加或減少，要新增或是刪除對應的 sitemap 路徑。
2. 當 portfolio 資料夾內的文章內容有更新，需同步更新 <lastmod> 的時間。

## blog sitemap

「<!-- Blog -->」底下區塊內的負責管理 blog.html 和 blog 資料夾內的 .html 檔案的 sitemap 路徑。
因為 blog.html 這個頁面是固定的，所以主要是管理 blog 資料夾內的 .html 檔案。

1. 當 blog 資料夾內的文章有增加或減少，要新增或是刪除對應的 sitemap 路徑。
2. 當 blog 資料夾內的文章內容有更新，需同步更新 <lastmod> 的時間。

# index.html

## Portfolios List

1. 「 <!-- Portfolios List Editor--> 」 從 portfolio 資料夾內隨機挑選10則文章，並隨機排序。
2. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。
4. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。

## Blogs List

1. 「 <!-- Blogs List Editor--> 」 從 blog 資料夾內隨機挑選10則文章，並隨機排序。
2. 承1，將 「 <!-- Blogs List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Blogs List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Blogs List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。
4. 承1，將 「 <!-- Blogs List Editor --> 」 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。

# about-playplus.html

## Portfolios List

1. 「 <!-- Portfolios List Editor--> 」 從 portfolio 資料夾內隨機挑選10則文章，並隨機排序。
2. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。
4. 承1，將 「 <!-- Portfolios List Editor --> 」 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **tags** （對應數量）。

# 其他

上述未提到的檔案。

1. css 資料夾 : 直接打包，無需調整。
2. images 資料夾 : 直接打包，無需調整。
3. js 資料夾 : 直接打包，無需調整。
4. sass 資料夾 : 直接打包，無需調整。
5. services 資料夾 : 直接打包，無需調整。
6. headers : 直接打包，無需調整。
7. CNAME : 直接打包，無需調整。
8. style.css.map : 直接打包，無需調整。
9. llms.txt : 直接打包，無需調整。
10. robots.txt : 直接打包，無需調整。
11. style.css : 直接打包，無需調整。
12. 404.html : 直接打包，無需調整。
13. contact-success.html : 直接打包，無需調整。
14. contact.html : 直接打包，無需調整。
15. digital-transformation.html : 直接打包，無需調整。
16. faq.html : 直接打包，無需調整。
17. partners.html : 直接打包，無需調整。
18. privacy.html : 直接打包，無需調整。
19. process.html : 直接打包，無需調整。
20. quickly-solution.html : 直接打包，無需調整。
21. recommended-tools.html : 直接打包，無需調整。
22. services.html : 直接打包，無需調整。
23. terms.html : 直接打包，無需調整。
24. gulpfile.js : 直接打包，無需調整。
25. resize-services.mjs : 直接打包，無需調整。
26. package-lock.json : 直接打包，無需調整。
27. package.json : 直接打包，無需調整。
28. CLAUDE.md : 直接打包，無需調整。
29. add_confidential.py : 直接打包，無需調整。
30. add_name.py : 直接打包，無需調整。
31. extract.py : 直接打包，無需調整。
32. generate_page.py : 直接打包，無需調整。
33. types.d.ts : 直接打包，無需調整。