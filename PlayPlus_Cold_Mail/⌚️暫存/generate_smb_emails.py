import csv
import json
import re

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

def get_greeting(contact_name):
    contact_name = contact_name.strip()
    if contact_name in ["官方", "xxx窗口", "", "無"]:
        return "您好"
    else:
        return f"{contact_name} 您好"

def get_social_proof(company_name, description):
    name_desc = (company_name + " " + description).lower()
    
    # Food industry
    if any(k in name_desc for k in ["食品", "餐飲", "飲料", "農業", "水產", "烘焙", "麵包"]):
        return {
            "name": "食安智幫手APP",
            "link": "https://playplus.com.tw/portfolio/tfif-app",
            "scene": "現場自主檢查與食安追蹤"
        }
    # Biotech / Medical
    elif any(k in name_desc for k in ["生技", "生物科技", "醫療", "醫藥", "檢驗", "診所", "醫院", "藥", "健康"]):
        return {
            "name": "腎臟醫學會 TSN 病理系統",
            "link": "https://playplus.com.tw/portfolio/tsn",
            "scene": "病理數據管理與檢驗流程"
        }
    # Default: Mitac
    else:
        return {
            "name": "神達會議室預約系統",
            "link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
            "scene": "跨部門資源預約與行政流程"
        }

def get_product_keyword(company_name, description):
    # Extract a short keyword representing what they do to make the email feel personalized
    name_desc = (company_name + " " + description).lower()
    if "光電" in name_desc or "傳感器" in name_desc:
        return "光電與傳感器製造"
    elif "壓鑄" in name_desc or "模具" in name_desc:
        return "模具與壓鑄製造"
    elif "機械" in name_desc or "設備" in name_desc:
        return "自動化機械研發"
    elif "生技" in name_desc or "檢測" in name_desc or "核酸" in name_desc:
        return "生技與精準醫療檢測"
    elif "醫療" in name_desc or "連接器" in name_desc or "線材" in name_desc:
        return "醫療器材與連接器製造"
    elif "包材" in name_desc or "保麗龍" in name_desc or "發泡" in name_desc:
        return "環保包材與發泡材料生產"
    elif "壓克力" in name_desc or "光學材料" in name_desc:
        return "光學材料與壓克力製造"
    elif "振動檢測" in name_desc or "監控" in name_desc:
        return "工業檢測與監控服務"
    elif "馬達" in name_desc or "驅動器" in name_desc:
        return "馬達與驅動控制製造"
    elif "印刷" in name_desc or "包裝" in name_desc:
        return "專業印刷與包裝設計"
    elif "五金" in name_desc or "工具" in name_desc:
        return "精密五金與工具製造"
    elif "滾珠" in name_desc or "螺桿" in name_desc:
        return "傳動元件與精密加工"
    elif "交通器材" in name_desc or "汽車" in name_desc:
        return "車輛零件與交通器材製造"
    elif "食品" in name_desc:
        return "食品加工與生產管理"
    else:
        return "精密製造與營運管理"

# Read the CSV
rows = []
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows.append(header)
    for row in reader:
        rows.append(row)

generated_emails = []
updated_count = 0

for idx, row in enumerate(rows):
    if idx == 0:  # Skip header
        continue
    
    if len(row) > 10 and row[10].strip() == "中小企業_企業內部系統":
        company_name = row[0].strip()
        email = row[5].strip()
        contact_name = row[6].strip()
        description = row[8].strip()
        
        greeting = get_greeting(contact_name)
        sp = get_social_proof(company_name, description)
        prod_kw = get_product_keyword(company_name, description)
        
        # Day 1
        day1_title = f"{company_name}的內部作業流程，目前還是靠 Excel 或人工作業嗎？"
        day1_content = (
            f"{greeting}，<br>"
            f"<br>"
            f"在{prod_kw}的日常營運中，同仁是否每天仍花費大量時間在 Excel 或紙本表單上進行重複的人工作業？這不僅悄悄消耗了團隊精力，也讓關鍵流程只留在資深員工腦中，一旦面臨交接或離職，就容易出現斷層。<br>"
            f"<br>"
            f"我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 與系統開發顧問。我們不推銷複雜昂貴的套裝軟體，而是專注於協助中型企業從最痛的一條流程切入，打造好紀錄、好追蹤的客製化內部系統。<br>"
            f"<br>"
            f"不知道貴司目前在跨部門協作或日常報表彙整上，是否也遇到類似的瓶頸？如果方便，我很樂意分享一些我們在相關領域的數位化案例。<br>"
            f"<br>"
            f"感謝您"
        )
        
        # Day 7
        day7_title = f"Re: {company_name}的內部作業流程，目前還是靠 Excel 或人工作業嗎？"
        day7_content = (
            f"{greeting}，<br>"
            f"<br>"
            f"上週曾寄信向您致意，理解您平時公務繁忙，因此特地寫這封信簡單追蹤，希望沒有打擾到您。<br>"
            f"<br>"
            f"許多企業在快速成長的階段，常會因為缺乏合適的數位工具，導致管理效率跟不上業務擴張的速度。<br>"
            f"<br>"
            f"若貴司近期正有計劃重新梳理內部流程或評估數位轉型，歡迎隨時與我們交流。<br>"
            f"<br>"
            f"感謝您"
        )
        
        # Day 14
        day14_title = f"分享一個我們協助相關領域客戶提升營運效率的案例"
        day14_content = (
            f"{greeting}，<br>"
            f"<br>"
            f"延續上週的話題，我想分享一個我們實際協助客戶進行流程數位化的經驗。<br>"
            f"<br>"
            f"我們曾協助相關領域的客戶打造了 {sp['name']}（{sp['link']}），協助他們將原本繁瑣的{sp['scene']}流程完全數位化，不僅大幅減少了人工彙整的時間，更讓管理者能即時掌握營運數據。<br>"
            f"<br>"
            f"這是我們的官網與更多作品集：https://playplus.com.tw/ ，您可以參考我們如何透過客製化系統協助企業解決效率痛點。<br>"
            f"<br>"
            f"如果貴司也有類似的流程優化需求，我們可以用 10 分鐘線上簡單聊聊。<br>"
            f"<br>"
            f"感謝您"
        )
        
        # Day 30
        day30_title = f"關於企業內部系統開發，您是否也有這些預算與時間的顧慮？"
        day30_content = (
            f"{greeting}，<br>"
            f"<br>"
            f"在與許多中型企業主交流的過程中，我們發現大家雖然想優化系統，但常有兩大顧慮：一是怕開發預算太高，二是怕耗費太多主管的管理時間。<br>"
            f"<br>"
            f"為此，我們 PlayPlus 採用「模組化開發」與「分階段優化方案」，讓企業可以從最迫切的單一流程開始，彈性調配預算；且我們有專屬的顧問陪跑，主管每週只需花 15 分鐘確認進度，其餘的商業邏輯盤點與設計開發皆由我們處理。<br>"
            f"<br>"
            f"如果這能降低貴司的數位化門檻，下週是否方便撥冗 10 分鐘，讓我們為您評估適合的數位步調？<br>"
            f"<br>"
            f"感謝您"
        )
        
        # Day 60
        day60_title = f"內部系統優化 —— 這是我的最後一封信"
        day60_content = (
            f"{greeting}，<br>"
            f"<br>"
            f"打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>"
            f"<br>"
            f"在優雅退場前，還是想再次提醒，若貴司未來有計劃透過數位轉型提升跨部門的資源綜效、建立標準化營運流程，PlayPlus 隨時能提供專業的 UI/UX 與系統開發服務。<br>"
            f"<br>"
            f"我將我們的案例簡報放在這裡：https://playplus.com.tw/ ，方便您未來有需求時隨時參考與聯絡。<br>"
            f"<br>"
            f"祝您工作順心，未來有機會再行合作。<br>"
            f"<br>"
            f"感謝您"
        )
        
        # Save to JSON structure
        generated_emails.append({
            "company_name": company_name,
            "email": email,
            "day1_title": day1_title,
            "day1_content": day1_content,
            "day7_title": day7_title,
            "day7_content": day7_content,
            "day14_title": day14_title,
            "day14_content": day14_content,
            "day30_title": day30_title,
            "day30_content": day30_content,
            "day60_title": day60_title,
            "day60_content": day60_content
        })
        
        # Update the row in-memory
        while len(row) < 21:
            row.append('')
        row[11] = day1_title
        row[12] = day1_content
        row[13] = day7_title
        row[14] = day7_content
        row[15] = day14_title
        row[16] = day14_content
        row[17] = day30_title
        row[18] = day30_content
        row[19] = day60_title
        row[20] = day60_content
        
        updated_count += 1

# Write to JSON
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(generated_emails, f, ensure_ascii=False, indent=2)

# Write back to CSV
with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print(f"Successfully generated and updated {updated_count} SMB rows in {csv_path}")
