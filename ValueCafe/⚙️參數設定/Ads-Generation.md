我的網頁內要加入廣告，所以我需要你根據以下 `# 基本設定` 和 `# 指定頁面` 的需求，將廣告生成邏輯加入 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Build]] 資料夾內的程式裡面。

# 基本設定

1. 廣告樣式會從 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 裡面指定。
2. 承上，廣告樣式欄位遵守 `## 欄位規定` 的規則。
3. 每個 `# 指定頁面` 都要從 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json]] 抓取自己被分配的內容。當 pages 陣列中提到該頁面，表示該頁面是可以帶入該則廣告的。
4. 承上，當符合該頁面的廣告有多則（包含 Books 和 Courses），請從中隨機挑選我指定的數量。
5. 插入廣告時必須對齊上下文縮排，不要破壞原本的 HTML 架構。

## 欄位規定

下方對照表左側帶有「🟢」的文字表示為 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的內容變數，右側為該變數的 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json]] 對應內容。

1. 🟢AdsUrl → "url"
2. 🟢AdsTitle → "title"
3. 🟢AdsDescription → "description"
4. 每個廣告樣式內都會有 <ul class="tags"><li class="orange">Books</li><li class="green">Courses</li></ul> 標籤，根據 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/database.json]] 的 "type" 判斷。當 "type" 為「Books」時，移除 <li class="green">Courses</li> 標籤；當 "type" 為「Courses」時，移除 <li class="orange">Books</li> 標籤。
5. 承上，「<!-- Horizontal Bar Ads  -->」和「<!-- Cards Ads -->」廣告樣式內如果有 <img src="images/recomm-books.webp" alt="🟢AdsTitle"> <img src="images/recomm-courses.webp" alt="🟢AdsTitle"> 兩張圖片，要根據 "type" 判斷顯示其中一張圖片，當 "type" 為 Books 時，只能顯示 <img src="images/recomm-books.webp" alt="🟢AdsTitle">，當 "type" 為 Courses 時，只能顯示 <img src="images/recomm-courses.webp" alt="🟢AdsTitle">。
6. 承上，當頁面為內頁時，圖片路徑要跟著調整層級。例如 news/20251222-waymo-driverless-taxis-were-paralyzed.html 裡面的廣告圖片路徑應該是 ../images/recomm-books.webp 或 ../images/recomm-courses.webp 這樣。

# 指定頁面

## financial-ratios 列表

1. 打包產出時，在 financial-ratios 列表（financial-ratios.html）的 「<!-- List Editor -->」 每3篇文章就加入1則廣告，也就是整個文章列表的第4則、第8則、第12則...是廣告，請以此類推，將廣告加入文章列表中。
2. 此區廣告樣式採用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Horizontal Bar Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。

## financial-ratios 內頁

1. financial-ratios 資料夾內的頁面為 financial-ratios 內頁（例如 financial-ratios/debt-ratio.html）。
2. 打包產出時，在 financial-ratios 內頁的「<!-- Bookmarks Ads -->」區塊加入廣告，該區塊套用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Bookmarks Ads -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，廣告數量最多5則。
4. 當廣告區塊內沒有廣告時，將該區塊清空。

## intrinsic-value 列表

1. 打包產出時，在 intrinsic-value 列表（intrinsic-value.html）的 「<!-- List Editor -->」 每3篇文章就加入1則廣告，也就是整個文章列表的第4則、第8則、第12則...是廣告，請以此類推，將廣告加入文章列表中。
2. 此區廣告樣式採用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Horizontal Bar Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。

## intrinsic-value 內頁

1. intrinsic-value 資料夾內的頁面為 intrinsic-value 內頁（例如 intrinsic-value/pb-ratio.html）。
2. 打包產出時，在 intrinsic-value 內頁的「<!-- Bookmarks Ads -->」區塊加入廣告，該區塊套用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Bookmarks Ads -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，廣告數量最多5則。
4. 當廣告區塊內沒有廣告時，將該區塊清空。

## philosophy 列表

1. 打包產出時，在 philosophy 列表（philosophy.html）的 「<!-- List Editor -->」 每3篇文章就加入1則廣告，也就是整個文章列表的第4則、第8則、第12則...是廣告，請以此類推，將廣告加入文章列表中。
2. 此區廣告樣式採用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Cards Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，容器 <a href="🟢AdsUrl" target="_blank"> 外面要再包一層 <div class="col-md-3"></div> 外框。

## philosophy 內頁

1. philosophy 資料夾內的頁面為 philosophy 內頁（例如 philosophy/economic-moat.html）。
2. 打包產出時，在 philosophy 內頁的「<!-- Bookmarks Ads -->」區塊加入廣告，該區塊套用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Bookmarks Ads -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，廣告數量最多5則。
4. 當廣告區塊內沒有廣告時，將該區塊清空。

## legendary 內頁

1. legendary 資料夾內的頁面為 legendary 內頁（例如 legendary/peter-lynch.html）。
2. 打包產出時，在 legendary 內頁文章的倒數第二段加入廣告，也就是最後一個 <div class="column column-content"> 的前面加入廣告區塊，該區塊套用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Horizontal Bar Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，容器 <a href="🟢AdsUrl" target="_blank"> 外面要再包一層 <div class="column column-content"></div> 外框。
4. 承上，廣告數量最多1則。

## news 列表

1. 打包產出時，在 news 列表（news.html）的 「<!-- List Editor -->」 每4篇文章就加入1則廣告，也就是整個文章列表的第5則、第10則、第15則...是廣告，請以此類推，將廣告加入文章列表中。
2. 此區廣告樣式採用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Cards Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，容器 <a href="🟢AdsUrl" target="_blank"> 外面要再包一層 <div class="col-md-3"></div> 外框。

## news 內頁

1. news 資料夾內的頁面為 news 內頁（例如 news/20251222-uber-lyft-baidu-london-robotaxi-2026.html）。打包產出時，在 news 內頁的「<!-- More Resources Editor -->」每3篇文章就加入1則廣告，也就是整個文章列表的第4則、第8則、第12則...是廣告，請以此類推，將廣告加入文章列表中。
2. 此區廣告樣式採用 [[/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/⚙️參數設定/Ads/templates.html]] 的 「<!-- Cards Ads  -->」 裡面的 <a href="🟢AdsUrl" target="_blank"> 整段樣式。
3. 承上，插入廣告時，將原有區塊的 <a href="🟢UrlName.html"></a> 容器移除，直接將廣告樣式 <a href="🟢AdsUrl" target="_blank"> 整段置入。
4. 承上，容器 <a href="🟢AdsUrl" target="_blank"> 外面要再包一層 <div class="oc-item"></div> 外框。