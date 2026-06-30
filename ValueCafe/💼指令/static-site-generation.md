我需要你將 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/en` 專案以 Static Site Generation 網頁渲染技術打包成靜態網站，寫出相應的執行腳本。
先將 `/Users/starchang/Documents/CloudFolder/GitHub/valuecafe` 資料夾刪除，再將打包結果直接輸出成 `/Users/starchang/Documents/CloudFolder/GitHub/valuecafe` 資料夾。

以下是每個項目的需求。

# financial-ratios

1. 將 financial-ratios 資料夾內的 .md 檔案套用 financial-ratios/template.html 模板，一律打包為 financial-ratios 分類裡面的文章（例如 debt-ratio.md 打包成 financial-ratios/debt-ratio.html）。依照以下 `## financial-ratios 文章` 生成對應的 html 靜態頁面。

2. financial-ratios.html 是 financial-ratios 的列表頁。依照以下 `## financial-ratios 列表` 生成對應的 html 靜態頁面。

## financial-ratios 文章

1. financial-ratios/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. financial-ratios/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. financial-ratios/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. financial-ratios/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. financial-ratios/template.html 裡面的 「<!-- Hero Editor -->」 帶入對應 .md 檔案的 # Hero Editor 全部。
6. financial-ratios/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部。
7. financial-ratios/template.html 裡面的 「<!-- More Resources Editor -->」 依照 `### financial-ratios more` 生成對應的卡片連結。

### financial-ratios more

1. 從 financial-ratios 裡面隨機挑選最多6則文章，無需任何排序。
2. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。

## financial-ratios 列表

1. financial-ratios.html 依照 financial-ratios/order.json 的 **id** 排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 financial-ratios.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 financial-ratios.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 financial-ratios.html 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。

# intrinsic-value

1. 將 intrinsic-value 資料夾內的 .md 檔案套用 intrinsic-value/template.html 模板，一律打包為 intrinsic-value 分類裡面的文章（例如 pe-ratio.md 打包成 intrinsic-value/pe-ratio.html）。依照以下 `## intrinsic-value 文章` 生成對應的 html 靜態頁面。

2. intrinsic-value.html 是 intrinsic-value 的列表頁。依照以下 `## intrinsic-value 列表` 生成對應的 html 靜態頁面。

## intrinsic-value 文章

1. intrinsic-value/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. intrinsic-value/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. intrinsic-value/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. intrinsic-value/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. intrinsic-value/template.html 裡面的 「<!-- Hero Editor -->」 帶入對應 .md 檔案的 # Hero Editor 全部。
6. intrinsic-value/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部。
7. intrinsic-value/template.html 裡面的 「<!-- More Resources Editor -->」 依照 `### intrinsic-value more` 生成對應的卡片連結。

### intrinsic-value more

1. 從 intrinsic-value 裡面隨機挑選最多6則文章，無需任何排序。
2. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。

## intrinsic-value 列表

1. intrinsic-value.html 依照 intrinsic-value/order.json 的 **id** 排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 intrinsic-value.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 intrinsic-value.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 intrinsic-value.html 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。

# legendary

1. 將 legendary 資料夾內的 .md 檔案套用 legendary/template.html 模板，一律打包為 legendary 分類裡面的文章（例如 charlie-munger.md 打包成 legendary/charlie-munger.html）。依照以下 `## legendary 文章` 生成對應的 html 靜態頁面。

2. legendary.html 是 legendary 的列表頁。依照以下 `## legendary 列表` 生成對應的 html 靜態頁面。

## legendary 文章

1. legendary/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. legendary/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. legendary/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. legendary/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. legendary/template.html 裡面的 「<!-- Hero Editor -->」 帶入對應 .md 檔案的 # Hero Editor 全部。
6. legendary/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部。
7. legendary/template.html 裡面的 「<!-- More Resources Editor -->」 依照 `### legendary more` 生成對應的卡片連結。

### legendary more

1. 從 legendary 裡面隨機挑選最多6則文章，無需任何排序。
2. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢LegendaryName 帶入對應 .md 檔案的 # Head Editor 的 **name** 。

## legendary 列表

1. legendary.html 依照 legendary/order.json 的 **id** 排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 legendary.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 legendary.html 裡面的 🟢LegendaryName 帶入對應 .md 檔案的 # Head Editor 的 **name** 。

# news

1. 將 news 資料夾內的 .md 檔案套用 news/template.html 模板，一律打包為 news 分類裡面的文章（例如 20251222-alphabet-acquires-intersect-power-ai-energy-strategy.md 打包成 news/20251222-alphabet-acquires-intersect-power-ai-energy-strategy.html）。依照以下 `## news 文章` 生成對應的 html 靜態頁面。

2. news.html 是 news 的列表頁。依照以下 `## news 列表` 生成對應的 html 靜態頁面。

## news 文章

1. news/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. news/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. news/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. news/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. news/template.html 裡面的 「<!-- Hero Editor -->」 帶入對應 .md 檔案的 # Hero Editor 全部。
6. news/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部。
7. news/template.html 裡面的 「<!-- More Resources Editor -->」 依照 `### news more` 生成對應的卡片連結。

### news more

1. 從 news 裡面隨機挑選最多6則文章，依照日期新到舊排序。
2. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢Date 帶入對應 .md 檔案的 # Head Editor 的 **Date** 。
5. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **TAGs** （對應數量）。

## news 列表

1. news.html 依照日期（對應 .md 檔案的 # Head Editor 的 **Date**）新到舊排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承上，第1則文章的容器為 <div class="col-md-6"> ，從第2則開始的其他文章的容器皆為 <div class="col-md-3"> 。
3. 承1，將 news.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
4. 承1，將 news.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
5. 承1，將 news.html 裡面的 🟢Date 帶入對應 .md 檔案的 # Head Editor 的 **Date** 。
6. 承1，將 news.html 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **TAGs** 。

# philosophy

1. 將 philosophy 資料夾內的 .md 檔案套用 philosophy/template.html 模板，一律打包為 philosophy 分類裡面的文章（例如 investment-moat.md 打包成 philosophy/investment-moat.html）。依照以下 `## philosophy 文章` 生成對應的 html 靜態頁面。

2. philosophy.html 是 philosophy 的列表頁。依照以下 `## philosophy 列表` 生成對應的 html 靜態頁面。

## philosophy 文章

1. philosophy/template.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
2. philosophy/template.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
3. philosophy/template.html 裡面的 🟢PageDescription 帶入對應 .md 檔案的 # Head Editor 的 **description** 。
4. philosophy/template.html 裡面的 🟢PageKeywords 帶入對應 .md 檔案的 # Head Editor 的 **keywords** 。
5. philosophy/template.html 裡面的 「<!-- Hero Editor -->」 帶入對應 .md 檔案的 # Hero Editor 全部。
6. philosophy/template.html 裡面的 「<!-- Content Editor -->」 帶入對應 .md 檔案的 # Content Editor 全部。
7. philosophy/template.html 裡面的 「<!-- More Resources Editor -->」 依照 `### philosophy more` 生成對應的卡片連結。

### philosophy more

1. 從 philosophy 裡面隨機挑選最多6則文章，無需任何排序。
2. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「<!-- More Resources Editor -->」 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。

## philosophy 列表

1. philosophy.html 依照 philosophy/order.json 的 **id** 排序，在 「<!-- List Editor -->」 生成對應的列表連結。
2. 承1，將 philosophy.html 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 philosophy.html 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。

# index.html

## Financial Ratios List

1. 「 <!-- Financial Ratios List Editor --> 」 依照 financial-ratios/order.json 的 id 排序，列出對應的前6則 financial-ratios 文章。
2. 承1，將 「 <!-- Financial Ratios List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Financial Ratios List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Financial Ratios List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。

## Intrinsic Value List

1. 「 <!-- Intrinsic Value List Editor --> 」 依照 intrinsic-value/order.json 的 id 排序，列出對應的前6則 intrinsic-value 文章。
2. 承1，將 「 <!-- Intrinsic Value List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Intrinsic Value List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Intrinsic Value List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。

## News List

1. 「 <!-- News List Editor --> 」 依照 news 資料夾內的日期（對應 .md 檔案的 # Head Editor 的 **Date**）新到舊排序，列出對應的前10則 news 文章。
2. 承1，將 「 <!-- News List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- News List Editor --> 」 裡面的 🟢PageTitle 帶入對應 .md 檔案的 # Head Editor 的 **title** 。
4. 承1，將 「 <!-- News List Editor --> 」 裡面的 🟢Date 帶入對應 .md 檔案的 # Head Editor 的 **date** 。
5. 承1，將 「 <!-- News List Editor --> 」 裡面的 🟢TAGs 帶入對應 .md 檔案的 # Head Editor 的 **TAGs** 。

## Philosophy List

1. 「 <!-- Philosophy List Editor --> 」 依照 philosophy/order.json 的 id 排序，列出對應的前6則 philosophy 文章。
2. 承1，將 「 <!-- Philosophy List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Philosophy List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。
4. 承1，將 「 <!-- Philosophy List Editor --> 」 裡面的 🟢ListSummary 帶入對應 .md 檔案的 # Head Editor 的 **list-summary** 。

## Legendary List

1. 「 <!-- Legendary List Editor --> 」 依照 legendary/order.json 的 id 排序，列出對應的全部 legendary 文章。
2. 承1，將 「 <!-- Legendary List Editor --> 」 裡面的 🟢UrlName 帶入對應 .md 檔案的 # Head Editor 的 **id** 。
3. 承1，將 「 <!-- Legendary List Editor --> 」 裡面的 🟢Name 帶入對應 .md 檔案的 # Head Editor 的 **name** 。

# worldview.html

1. 從 financial-ratios, intrinsic-value, legendary, news, philosophy, statements, to-beginners 這些項目隨機挑選最多8則文章帶入 「<!-- More Resources Editor -->」 ，無需任何排序。
2. 承1，將 worldview.html 的 🟢Url 帶入對應 html 的位址。
3. 承1，將 worldview.html 的 🟢PageTitle 帶入對應 html 的 title 。

# 其他

上述未提到的檔案。

1. empty.md : 不用打包。
2. components-level2.html : 不用打包。
3. components-level1.html : 不用打包。
4. contact.html : 直接打包，無需調整。
5. style.css : 直接打包，無需調整。
6. statements 資料夾 : 直接打包，無需調整。
7. to-beginners 資料夾 : 直接打包，無需調整。
8. js 資料夾 : 直接打包，無需調整。
9. images 資料夾 : 直接打包，無需調整。
10. css 資料夾 : 直接打包，無需調整。