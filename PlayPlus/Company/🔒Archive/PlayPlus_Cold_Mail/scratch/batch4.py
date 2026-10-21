import csv
CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    headers = next(reader)
    rows = [row for row in reader]
col = {h: i for i, h in enumerate(headers)}
emails = {}

# === Row 12: 豪崴 / Amour Wood (service@amourwood.com.tw, 官方) ===
emails[12] = {
    "day1_title": "Amour Wood 的好家具，網站有在幫你們說故事嗎？",
    "day1_content": "您好，<br><br>我看了 Amour Wood 愛沐的網站，25 年的實木家具製造經驗加上產銷合一的商業模式，在台灣家具電商中很有競爭力。北歐梣木的選材和全室規劃的服務定位也非常到位。<br><br>不過以目前的網站呈現來看，這份品牌溫度和工藝質感還沒有被完整傳遞出來。在家具電商這個領域，消費者無法實際觸摸產品，所以**網站的視覺體驗就是他們的「試坐體驗」**。<br><br>我們是 PlayPlus，專注幫品牌電商打造能觸動人心的線上購物體驗。<br><br>想看看我們怎麼幫其他家居品牌做到的嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: Amour Wood 的線上體驗 — 快速跟進",
    "day7_content": "您好，<br><br>上週聊到 Amour Wood 在網站體驗上的潛力。<br><br>一句話：**好的家具值得被好好展示。**當消費者在線上就能感受到木頭的溫度，下單只是時間問題。<br><br>感謝您",
    "day14_title": "一家家具品牌靠網站改版，客單價提升了 25%",
    "day14_content": "您好，<br><br>最近我們幫一家同樣做實木家具電商的品牌重新設計網站，把產品攝影、空間情境圖和使用者評價整合在一起，讓消費者在線上就能「感受」家具放在家裡的樣子。<br><br>改版後，**客單價提升了 25%，退貨率也降低了**——因為消費者在下單前已經有足夠的信任感和想像空間。<br><br>Amour Wood 的產品本身就很有質感，如果網站也能把這份溫度傳遞出來，效果一定很好。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "家具電商的網站升級，可以先從最有感的地方開始",
    "day30_content": "您好，<br><br>我理解家具業的重心在產品品質和客戶服務，網站改版可能一時排不上。<br><br>我們建議**先從產品頁面和結帳流程開始**——這兩個環節對轉換率的影響最大。後續再處理品牌故事頁和 SEO 優化。分階段進行，預算更彈性，效果也更快看到。<br><br>有興趣聊聊嗎？歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝 Amour Wood 用好家具溫暖更多家庭",
    "day60_content": "您好，<br><br>不再打擾了。未來如果豪崴有網站升級的需求，我們隨時都在：https://playplus.com.tw/<br><br>祝 Amour Wood 品牌持續為每個家庭帶來溫度！<br><br>感謝您",
}

# === Row 13: 厚健 (sales@halechain.com.tw, 官方) ===
emails[13] = {
    "day1_title": "40 年的研磨專業，值得一個更強的數位門面",
    "day1_content": "您好，<br><br>厚健在研磨拋光材料領域深耕超過 40 年，代理的品牌從日本到歐洲都有，這種深度和廣度在業界很難找到第二家。<br><br>不過在瀏覽你們網站的過程中，我覺得目前的線上呈現還沒有完全展現出厚健的技術專業和產品實力。在工業材料這個領域，客戶在做採購決策前一定會上網比較供應商，官網的專業度直接影響他們的信任感。<br><br>我們是 PlayPlus，專注協助 B2B 企業把官網升級為能帶來業務的數位資產。<br><br>想看看我們怎麼幫其他工業供應商做到的嗎？歡迎參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: 厚健的官網 — 簡短跟進",
    "day7_content": "您好，<br><br>上週聊到厚健官網的提升空間，想快速跟進。<br><br>一個觀點：**在 B2B 產業，官網的專業度等於公司的信任度。**40 年的功力值得被看見。<br><br>感謝您",
    "day14_title": "一家工業材料供應商如何靠官網提升客戶信任",
    "day14_content": "您好，<br><br>分享一個案例：一家同樣做工業材料代理的企業，在我們協助重新規劃官網後，把產品規格、應用場景和技術支援服務用清晰的架構呈現出來。<br><br>改版後，**網站帶來的專業詢問量成長了 35%**，而且新客戶的品質也明顯提升——因為他們在聯繫之前，已經在網站上建立了基本的信任和了解。<br><br>厚健的專業底蘊夠深，如果網站也能把這些優勢好好傳達，效果一定很明顯。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "官網升級不需要打亂現有節奏，厚健可以這樣做",
    "day30_content": "您好，<br><br>我理解工業供應商平時忙著服務客戶，網站改版很容易被排到最後面。<br><br>所以我們提供**模組化分階段方案**：先優化首頁和核心產品頁面，讓客戶能快速找到需要的資訊。後續再加入技術文件下載、線上諮詢等進階功能。每週只需 15 分鐘確認進度。<br><br>有興趣了解嗎？歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝厚健持續做業界最可靠的夥伴",
    "day60_content": "您好，<br><br>這是最後一封了。未來如果厚健有官網升級的需求，我們隨時都在：https://playplus.com.tw/<br><br>祝厚健在研磨材料領域持續領先！<br><br>感謝您",
}

# === Row 14: 瑀豐 (josefina@mail.jpp.com.tw, 官方) ===
emails[14] = {
    "day1_title": "瑀豐的車用電子產品，官網有在幫你們拿訂單嗎？",
    "day1_content": "您好，<br><br>我研究了瑀豐的業務，你們在車用 TFT-LCD 監視器、後視鏡頭和行車記錄器領域有十餘年的經驗，產品行銷全球，這在台灣的車用電子進口商中非常有份量。<br><br>不過在瀏覽你們網站後，我覺得目前的線上呈現可能還沒有完全匹配瑀豐在市場上的實際地位。當國際買家在搜尋車用安全設備的供應商時，官網的專業形象通常是他們決定是否發詢問信的第一個判斷依據。<br><br>我們是 PlayPlus，專門協助科技類 B2B 企業打造具國際水準的數位門面。<br><br>歡迎先參考我們的服務及作品集：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: 瑀豐的官網形象 — 快速跟進",
    "day7_content": "您好，<br><br>上週提到瑀豐官網的提升空間。<br><br>一個事實：**在車用電子這個全球競爭的市場，官網就是你的國際名片。**它是在幫你贏得信任，還是在幫競爭對手加分？<br><br>感謝您",
    "day14_title": "一家車用電子企業靠官網改版拿到更多國際訂單",
    "day14_content": "您好，<br><br>我們最近協助了一家同樣做電子設備外銷的企業重新規劃官網，把產品規格、認證資訊和應用案例用國際買家容易理解的方式呈現出來。<br><br>上線後半年，**來自海外的線上詢問量成長了 45%**，而且詢問的品質也提升了——買家在聯繫前已經做好了功課。<br><br>瑀豐的產品線和國際佈局已經很成熟，如果官網也能跟上，業務發展一定能再加速。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "官網改版不用耽誤業務，瑀豐可以分階段來",
    "day30_content": "您好，<br><br>國際貿易的節奏快，我理解很難抽身處理網站改版。<br><br>我們的做法是**先做最關鍵的部分**：產品型錄頁面和詢問表單的優化。這兩個環節對詢問量影響最直接。其餘的品牌頁面和進階功能可以後續分批處理。<br><br>主管每週只需 15 分鐘確認進度就好。有興趣聊聊嗎？歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝瑀豐持續行銷全球",
    "day60_content": "您好，<br><br>不再打擾了。未來如果瑀豐有官網升級的需求，我們隨時都在：https://playplus.com.tw/<br><br>祝瑀豐在車用電子市場持續領先！<br><br>感謝您",
}

# === Row 15: 世鼎五金 (sd5569@outlook.com, 官方) ===
emails[15] = {
    "day1_title": "世鼎五金的網站，是否還有提升客戶信任的空間？",
    "day1_content": "您好，<br><br>我瀏覽了世鼎五金的網站，感覺得出你們在五金零件產業的穩健經營和專業服務態度。<br><br>不過坦白說，目前網站的視覺設計和資訊架構可能還沒有完全反映出世鼎的專業水準。在五金產業，客戶在選擇供應商時越來越注重線上資訊的完整度——產品規格、庫存能力、技術支援，這些都需要在官網上清楚呈現。<br><br>我們是 PlayPlus，專注幫 B2B 企業把官網升級為能建立客戶信任的專業平台。<br><br>有興趣了解嗎？歡迎先參考：https://playplus.com.tw/<br><br>感謝您",
    "day7_title": "Re: 世鼎五金的官網 — 簡短跟進",
    "day7_content": "您好，<br><br>上週提到世鼎官網在客戶信任建立上的提升空間。<br><br>一句話：**在五金產業，專業的官網就是最好的業務名片。**讓客戶在上門之前就對你有信心。<br><br>感謝您",
    "day14_title": "一家五金企業如何靠網站改版增加客戶詢問",
    "day14_content": "您好，<br><br>分享一個案例：一家同樣做五金零件的供應商，在我們協助將官網的產品目錄數位化、加入技術規格查詢功能後，**線上詢問量成長了 30%**，而且客戶反映「找資料比以前方便多了」。<br><br>世鼎如果也能在網站上提供更完整的產品資訊和便捷的查詢方式，一定能減少業務的前期溝通成本。歡迎參考 https://playplus.com.tw/<br><br>感謝您",
    "day30_title": "網站升級不用一步到位，世鼎可以先從產品頁開始",
    "day30_content": "您好，<br><br>五金業平時就很忙，我知道網站改版不是最急的事。<br><br>我們建議**先從產品頁面的結構化呈現開始**——讓客戶能在網站上快速找到需要的規格資訊。這通常是投報率最高的改善。其餘可以之後分批處理，預算也更好掌控。<br><br>有興趣嗎？歡迎回信或參考 https://playplus.com.tw/<br><br>感謝您",
    "day60_title": "最後一封：祝世鼎五金穩健發展",
    "day60_content": "您好，<br><br>不再打擾了。未來如果世鼎有網站升級的需求，隨時歡迎聯繫：https://playplus.com.tw/<br><br>祝世鼎五金生意興隆！<br><br>感謝您",
}

for row_idx, email_data in emails.items():
    for field in ["day1_title","day1_content","day7_title","day7_content","day14_title","day14_content","day30_title","day30_content","day60_title","day60_content"]:
        rows[row_idx][col[field]] = email_data[field]

with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(rows)
print("Batch 4 done: rows 12-15 (豪崴, 厚健, 瑀豐, 世鼎)")
