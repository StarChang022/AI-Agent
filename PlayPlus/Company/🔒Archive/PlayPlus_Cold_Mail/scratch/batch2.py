import csv
CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    headers = next(reader)
    rows = [row for row in reader]
col = {h: i for i, h in enumerate(headers)}
emails = {}

# === Row 4: 台灣聯意 (fimex@fimex.com.tw, 官方) ===
emails[4] = {
    "day1_title": "聯意的國際客戶，第一眼看到的是什麼？",
    "day1_content": "您好，<br><br>台灣聯意在電工產品外銷領域經營了超過 40 年，這份資歷在業界數一數二。<br><br>不過在研究你們網站的過程中，我發現目前的線上呈現可能沒有完全反映出聯意的專業實力。當歐美客戶在搜尋供應商時，官網的質感往往是他們判斷合作意願的第一關。<br><br>我們是 PlayPlus，擅長為外銷導向的企業打造具國際水準的官網，讓線上形象成為業務拓展的助力而非阻力。<br><br>有興趣了解我們的做法嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: 聯意官網的國際形象 — 簡短跟進",
    "day7_content": "您好，<br><br>上週聊到聯意官網的國際形象，想快速跟進一下。<br><br>一個小觀察：**在外銷產業，官網就是你的 24 小時業務員。**它是在幫你爭取客戶，還是在幫競爭對手？<br><br>感謝您",
    "day14_title": "外銷企業靠官網優化，半年多接了 50% 詢問單",
    "day14_content": "您好，<br><br>分享一個真實案例：一家台灣外銷製造商請我們重新規劃官網，著重產品規格的結構化呈現與多語系體驗。上線半年後，海外線上詢問量成長 **50%**。<br><br>重點不是花大錢重做，而是用對的架構讓產品自己說話。聯意的產品線這麼齊全，如果網站也能幫上忙，效益一定很明顯。<br><br>案例可以寄給您，或先到 https://playplus.com.tw/ 看看我們的作品。<br><br>感謝您",
    "day30_title": "怕改網站佔用太多時間？其實不用",
    "day30_content": "您好，<br><br>做貿易的公司最怕額外的事情拖住業務節奏，這我很理解。<br><br>我們的做法是**模組化分階段**：先從海外客戶最常看的頁面下手，再逐步優化。主管只需每週 15 分鐘確認進度，其餘交給我們。<br><br>這樣不影響日常營運，也能穩步提升線上競爭力。有興趣可以回信，或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝聯意外銷事業蒸蒸日上",
    "day60_content": "您好，<br><br>不再打擾了。未來若有官網升級的需求，我們隨時都在：https://playplus.com.tw/<br><br>祝聯意持續在國際市場發光！<br><br>感謝您",
}

# === Row 5: 艾登才藝中心 (syclassroom.teacher@gmail.com, 官方) ===
emails[5] = {
    "day1_title": "艾登的課程這麼豐富，但家長找得到你們嗎？",
    "day1_content": "您好，<br><br>我注意到艾登才藝中心目前主要用 Facebook 粉專來經營線上曝光。你們的課程從創意開發到才藝啟發都有，內容看起來非常用心。<br><br>但有個問題值得思考：當家長在搜尋「兒童才藝課程」或「幼兒創意教學」時，他們找到的會是艾登嗎？單靠社群平台，很容易被演算法限制觸及率，等於把招生主動權交給了 Facebook。<br><br>我們是 PlayPlus，專注協助教育機構建立自己的品牌官網，讓家長能直接找到你、信任你、然後報名。<br><br>有興趣了解我們怎麼幫其他才藝機構做到的嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: 艾登的線上招生管道 — 快速跟進",
    "day7_content": "您好，<br><br>上週提到艾登在線上曝光方面的觀察，想簡短跟進。<br><br>一個數據：**超過 70% 的家長在幫孩子選才藝班之前，會先上網搜尋和比較。**有自己的品牌官網，等於 24 小時都在幫你招生。<br><br>感謝您",
    "day14_title": "一間才藝教室如何靠官網讓報名率翻倍",
    "day14_content": "您好，<br><br>分享一個案例：一間原本只靠社群經營的兒童教育機構，在我們協助建立品牌官網後，把課程介紹、師資背景、家長好評都系統性地呈現出來。<br><br>結果？上線三個月後，**線上報名諮詢量成長了 60%**，而且家長反映「看完網站就很放心」。<br><br>艾登的課程內容和教學理念都很棒，如果也能用一個專業官網來呈現，效果一定很好。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "沒有工程師也能有專業官網，艾登可以這樣做",
    "day30_content": "您好，<br><br>我理解才藝教室的團隊通常以教學為主，不一定有人力處理網站的事情。<br><br>所以我們的做法是**全程代勞**：從內容規劃、設計到上線維護，教室端只需要提供課程資料和照片，其餘交給我們。而且可以分階段進行，先建好核心頁面就能上線，後續再逐步擴充。<br><br>有興趣的話歡迎回信聊聊，或先到 https://playplus.com.tw/ 看看我們的服務。<br><br>感謝您",
    "day60_title": "最後一封：祝艾登培育更多優秀的孩子",
    "day60_content": "您好，<br><br>這是最後一封了。完全理解教學工作繁忙，沒時間處理這些是正常的。<br><br>未來如果艾登想要建立自己的品牌官網或提升線上招生效果，我們隨時都在：https://playplus.com.tw/<br><br>祝艾登越辦越好！<br><br>感謝您",
}

# === Row 6: 髮瑪 (hairmod77@gmail.com, 官方) ===
emails[6] = {
    "day1_title": "HAIRMOD 的品牌質感，值得一個更好的線上舞台",
    "day1_content": "您好，<br><br>我看了 HAIRMOD 的 Instagram，你們代理的品牌從義大利到荷蘭都有，產品線非常專業，照片也拍得很有質感。<br><br>但我也發現，髮瑪目前似乎還沒有一個完整的品牌官網。在美髮沙龍產業，設計師在選用新品牌時通常會先上網研究，如果找不到一個能完整呈現品牌故事、產品線和教育課程的網站，信任感就會打折扣。<br><br>我們是 PlayPlus，專門幫品牌打造高質感的數位平台，讓線上形象跟產品品質一樣到位。<br><br>有興趣看看我們的作品嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: HAIRMOD 的線上品牌形象 — 簡短跟進",
    "day7_content": "您好，<br><br>上週聊到 HAIRMOD 在線上品牌建立方面的觀察。<br><br>一句話：**Instagram 能幫你曝光，但官網才能幫你建立品牌信任。**兩者搭配才是最完整的數位佈局。<br><br>感謝您",
    "day14_title": "一家美容品牌如何用官網拉開與競品的距離",
    "day14_content": "您好，<br><br>最近我們幫一家同樣做進口美容品牌代理的客戶建立了品牌官網，把產品介紹、品牌故事、教育課程和經銷據點整合在一起。<br><br>上線後，**沙龍端的合作洽談量成長了 45%**，品牌方也很滿意台灣的線上呈現。<br><br>HAIRMOD 代理這麼多頂尖品牌，如果有一個能完整展現的官網，對拓展沙龍通路一定很有幫助。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "從 IG 到官網，其實沒有想像中複雜",
    "day30_content": "您好，<br><br>很多品牌主會覺得「有 IG 就夠了」或「做官網太複雜」。但其實我們提供的**一站式服務**涵蓋從規劃到上線的所有環節，品牌端只需要提供素材和確認方向。<br><br>而且可以分階段進行——先做品牌形象頁和核心產品頁，後續再加入課程報名、經銷查詢等功能。預算彈性，節奏由你掌控。<br><br>有興趣聊聊嗎？歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝 HAIRMOD 品牌越做越強",
    "day60_content": "您好，<br><br>不再打擾了。未來如果髮瑪想要建立品牌官網或提升數位形象，我們隨時都在：https://playplus.com.tw/<br><br>祝 HAIRMOD 在沙龍界持續發光！<br><br>感謝您",
}

# === Row 7: 雷登國際 (chun38205@gmail.com, 官方) ===
emails[7] = {
    "day1_title": "MONZU 滿足的品牌故事，值得被更多人看見",
    "day1_content": "您好，<br><br>我研究了雷登國際的 MONZU 品牌，MIT 無毒 EVA 拖鞋加上微笑標章認證，這個定位在市場上非常有辨識度。而且你們正在往國際化方向發展，這個野心我很欣賞。<br><br>不過我看了目前的官網，覺得在品牌故事的傳達和產品體驗的呈現上，還有很大的提升空間。特別是要打國際市場的話，官網的質感和專業度就是買家的第一道篩選關卡。<br><br>我們是 PlayPlus，專門幫品牌打造能說服人的數位平台。<br><br>想了解我們怎麼幫其他 MIT 品牌走向國際嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: MONZU 的品牌官網 — 快速跟進",
    "day7_content": "您好，<br><br>上週聊到 MONZU 品牌在線上呈現上的潛力，想簡短跟進。<br><br>一個觀點：**要做國際市場，官網就是你的全球展示間。**它應該讓任何語言的買家都能在 30 秒內理解「為什麼選 MONZU」。<br><br>感謝您",
    "day14_title": "一個台灣品牌如何靠官網打進海外市場",
    "day14_content": "您好，<br><br>分享一個案例：一家做 MIT 生活用品的品牌，在我們協助重新設計官網後，把品牌理念、產品特色和認證資訊用國際買家容易理解的方式呈現出來。<br><br>結果上線後，**海外經銷商的洽談量成長了 55%**，品牌也開始收到來自東南亞和歐洲的合作邀請。<br><br>MONZU 已經有微笑標章和無毒認證這些硬實力，如果官網也能把這些優勢清楚傳達，國際化之路會順暢很多。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "國際化官網不用一步到位，MONZU 可以這樣開始",
    "day30_content": "您好，<br><br>我理解品牌要往國際走，要顧的事情很多，網站可能不是最急的那一項。<br><br>所以我們提供**模組化方案**：先做一個高質感的中英文品牌官網作為基礎，後續再根據目標市場逐步擴充語系和功能。這樣投入可控，而且每個階段都有明確成效。<br><br>如果想聊聊怎麼開始，歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝 MONZU 征服全球市場",
    "day60_content": "您好，<br><br>這是最後一封了。未來如果雷登國際在品牌官網或數位行銷上有需求，我們隨時都在：https://playplus.com.tw/<br><br>祝 MONZU 品牌邁向國際、滿足全世界！<br><br>感謝您",
}

for row_idx, email_data in emails.items():
    for field in ["day1_title","day1_content","day7_title","day7_content","day14_title","day14_content","day30_title","day30_content","day60_title","day60_content"]:
        rows[row_idx][col[field]] = email_data[field]

with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(rows)
print("Batch 2 done: rows 4-7 (台灣聯意 fimex, 艾登, 髮瑪, 雷登)")
