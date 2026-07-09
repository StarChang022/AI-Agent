我的網頁內要加入廣告，所以我需要你根據以下 `# 基本設定` 和 `# 指定頁面` 的需求，將廣告生成邏輯加入 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Build` 資料夾內的程式裡面。

# 基本設定

1. 廣告樣式會從 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html` 裡面指定。
2. 承上，廣告樣式欄位遵守 `## 欄位規定` 的規則。
3. 每個 `# 指定頁面` 都要從 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json` 抓取自己被分配的內容。當 pages 陣列中提到該頁面，表示該頁面是可以帶入該則廣告的。
4. 插入廣告時必須對齊上下文縮排，不要破壞原本的 HTML 架構。

## 欄位規定

下方對照表左側帶有「🟢」的文字表示為 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html` 的內容變數，右側為該變數的 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json` 對應內容。

1. 🟢AdsUrl → "url"
2. 🟢AdsTitle → "title"
3. 🟢AdsDescription → "description"
4. 每個廣告樣式內都會有 <ul class="tags"><li class="orange">Books</li><li class="green">Courses</li></ul> 標籤，根據 `/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json` 的 "type" 判斷。當 "type" 為「Books」時，移除 <li class="green">Courses</li> 標籤；當 "type" 為「Courses」時，移除 <li class="orange">Books</li> 標籤。

# 指定頁面

## financial-ratios 列表

1. financial-ratios.html 為 financial-ratios 列表。
2. 此區廣告樣式採用 「<!-- Horizontal Bar Ads  -->」 裡面的
3. financial-ratios 列表的 「<!-- List Editor -->」 每3篇文章就加入1則廣告，也就是整個文章列表的第4則、第8則、第12則...是廣告，請以此類推，將廣告加入文章列表中。

