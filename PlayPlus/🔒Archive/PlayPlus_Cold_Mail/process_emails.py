import csv
import json

input_file = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'
output_file = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'

# Templates for 大企業_企業內部系統_一般製造業
da_day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
da_day1_content = "您好，<br><br>在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。<br><br>我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。<br><br>作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，放大強調供應商管理與跨部門人力調度，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。<br><br>隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。<br><br>只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？<br><br>祝順利。"
da_day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
da_day7_content = "您好，<br><br>我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br><br>我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對貴產業常見的「跨國據點協作／複雜的供應商對帳／跨部門單據審核」，我們在實際開發前會打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。<br><br>若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br><br>祝順利。"
da_day30_title = "企業內部系統優化的最後一封信"
da_day30_content = "您好，<br><br>打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br><br>在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升供應鏈數位韌性，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。<br><br>我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br><br>祝順利。"

# Templates for 中小企業_企業內部系統_一般製造業
zhong_day1_title = "擺脫人工彙整報表！專為製造業打造的客製化內部系統"
zhong_day1_content = "您好，<br><br>我剛瀏覽了貴公司的網站，了解到貴司在製造領域擁有深厚的專業技術。不過我們也發現，許多企業在快速擴張的階段，常會遇到內部管理與流程跟不上的問題，例如：關鍵作業流程缺乏文件紀錄、表單管理混亂且依賴紙本、報表多半靠人工彙整等。<br><br>我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型系統，而是從你們最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助神達電腦開發會議室預約系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system），解決跨部門資源預約的混亂問題。<br><br>是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>感謝您"
zhong_day7_title = "Re: 擺脫人工彙整報表！專為製造業打造的客製化內部系統"
zhong_day7_content = "您好，<br><br>上週有發送一封關於客製化內部系統的郵件給您。我知道您業務繁忙，若無法回覆我完全能理解。如果您們目前剛好有優化內部表單或報表流程的想法，我們很樂意提供一些初步的規劃建議供您參考。<br><br>感謝您"
zhong_day30_title = "關於優化內部營運流程的最後一封信"
zhong_day30_content = "您好，<br><br>這是最後一封追蹤信，後續不會再打擾您的收件匣。<br><br>許多企業主在評估系統時，常會擔心預算過高或耗費太多溝通時間。我們提供「模組化開發」與「分階段優化方案」，能完全符合您的預算彈性；且主管每週只需 15 分鐘確認進度，大幅降低溝通成本。<br><br>未來若有任何數位轉型的需求，隨時歡迎您到我們的網站（https://playplus.com.tw/）看看。<br><br>感謝您"

with open(input_file, mode='r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    rows = list(reader)

for row in rows:
    scen = row.get('Scenarios', '')
    contact = row.get('聯絡人名稱', '官方')
    if contact != '官方':
        greeting = f"{contact} 您好，"
    else:
        greeting = "您好，"

    if scen == '大企業_企業內部系統':
        row['day1_title'] = da_day1_title
        row['day1_content'] = da_day1_content.replace('您好，', greeting, 1)
        row['day7_title'] = da_day7_title
        row['day7_content'] = da_day7_content.replace('您好，', greeting, 1)
        row['day14_title'] = '-'
        row['day14_content'] = '-'
        row['day30_title'] = da_day30_title
        row['day30_content'] = da_day30_content.replace('您好，', greeting, 1)
        row['day60_title'] = '-'
        row['day60_content'] = '-'
    elif scen == '中小企業_企業內部系統':
        row['day1_title'] = zhong_day1_title
        row['day1_content'] = zhong_day1_content.replace('您好，', greeting, 1)
        row['day7_title'] = zhong_day7_title
        row['day7_content'] = zhong_day7_content.replace('您好，', greeting, 1)
        row['day14_title'] = '-'
        row['day14_content'] = '-'
        row['day30_title'] = zhong_day30_title
        row['day30_content'] = zhong_day30_content.replace('您好，', greeting, 1)
        row['day60_title'] = '-'
        row['day60_content'] = '-'

with open(output_file, mode='w', encoding='utf-8', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print("Processed all rows and updated CSV.")
