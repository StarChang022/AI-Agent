# -*- coding: utf-8 -*-
import csv
import json
import os
import shutil

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_mails_all.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

def generate_quickey_emails(comp_name, contact_name, industry, description):
    # Rule 1: Greetings
    contact = contact_name.strip()
    if contact in ["官方", "", "無", "聯絡人", "xxx窗口"] or contact.endswith("窗口"):
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    # Rule 2: Pain points hook
    name_desc = (comp_name + " " + industry + " " + description).lower()
    if any(k in name_desc for k in ["製造", "五金", "機械", "加工", "精密", "鐵工"]):
        pain_context = "我們注意到許多精密製造與零件加工企業在日常營運中，同仁經常需要花費大量時間手動登打物料收據、出貨單與發票。這些繁瑣的工作不僅效率低落，也消耗了同仁專注於核心製程管理的精力。"
    elif any(k in name_desc for k in ["生醫", "醫療", "藥", "健康", "食品", "日式", "壽司"]):
        pain_context = "我們注意到許多食品與醫藥生醫團隊在日常營運中，同仁經常需要花費大量時間登打原料發票、包材收據與品管單據。這些繁瑣的日常報帳與登打工作，往往消耗了同仁寶貴的精力。"
    elif any(k in name_desc for k in ["設計", "印刷", "平面", "包裝", "文創"]):
        pain_context = "我們注意到許多文創、設計與印刷團隊在日常營運中，同仁經常需要花費大量時間登打各式輸出耗材、紙張收據與專案發票。這些低效率的手動登打工作，常常消耗了團隊的創作精力。"
    else:
        pain_context = "我們注意到許多企業在日常營運中，行政與財務同仁經常需要花費大量時間處理成堆的收據與發票。這些繁瑣的手動登打工作不僅效率低落，也消耗了團隊寶貴的精力。"

    # Day 1
    day1_title = "還在手動登打發票與收據？讓「快記」幫您省下每個月的報帳時間"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{pain_context}<br>\n"
        f"<br>\n"
        f"為了解決這個痛點，我們開發了「快記」數位系統。透過最新的 OCR 光學字元辨識技術，您只需上傳收據或發票照片，系統就能自動辨識並快速建立支出紀錄，讓您的財務管理變得輕鬆又準確。<br>\n"
        f"<br>\n"
        f"我們已準備好線上 Demo 體驗環境，邀請您花 3 分鐘親自操作測試：<br>\n"
        f"https://demos.playplus.dev/quickey/<br>\n"
        f"<br>\n"
        f"若您體驗後覺得有幫助，或是希望進一步了解，歡迎在 Demo 頁面點擊「問卷調查」，讓我們能為您提供更精準的協助。<br>\n"
        f"<br>\n"
        f"祝順利。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 7
    day7_title = "Re: 還在手動登打發票與收據？讓「快記」幫您省下每個月的報帳時間"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寫信向您介紹「快記」。<br>\n"
        f"<br>\n"
        f"理解您平時業務繁忙，特此簡單追蹤。我們發現，導入 OCR 自動辨識後，多數行政同仁能省下至少一半（甚至數十小時）的報帳時間。我們非常希望您能體驗看看這個能立刻提升效率的工具。<br>\n"
        f"<br>\n"
        f"您可以隨時透過此連結免費體驗操作：https://demos.playplus.dev/quickey/<br>\n"
        f"<br>\n"
        f"若您有任何問題或想法，歡迎在 Demo 頁面點擊「問卷調查」與我們交流。<br>\n"
        f"<br>\n"
        f"祝順利。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 30
    day30_title = "關於優化報帳流程的最後一封信"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br>\n"
        f"<br>\n"
        f"在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫人工登打發票的繁瑣流程，我們打造的「快記」OCR 報帳系統，會是您提升行政效率的最佳幫手。<br>\n"
        f"<br>\n"
        f"您依然可以保留這個 Demo 連結，隨時進行測試：<br>\n"
        f"https://demos.playplus.dev/quickey/<br>\n"
        f"<br>\n"
        f"若未來貴司有優化內部支出的需求，歡迎您隨時在 Demo 頁面點擊「問卷調查」與我們聯繫。<br>\n"
        f"<br>\n"
        f"祝順利。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day14_title": "-",
        "day14_content": "-",
        "day30_title": day30_title,
        "day30_content": day30_content,
        "day60_title": "-",
        "day60_content": "-"
    }

def generate_sme_emails(comp_name, contact_name, industry, description):
    # Greeting
    contact = contact_name.strip()
    if contact in ["官方", "", "無", "聯絡人", "xxx窗口"] or contact.endswith("窗口"):
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    # Social Proof and pain point selection
    name_desc = (comp_name + " " + industry + " " + description).lower()
    
    if any(k in name_desc for k in ["生技", "生物科技", "醫療", "醫藥", "檢驗", "醫院", "藥", "病理", "化學"]):
        sp_name = "腎臟醫學會 TSN 病理系統"
        sp_url = "https://playplus.com.tw/portfolio/tsn"
        sp_scene = "病理數據整合與檢驗表單數位化"
        industry_focus = "生技與醫療器材研發"
        pain_point = "許多生醫團隊在業務擴張時，常面臨繁瑣的合規記錄與臨床表單管理，資料分散且多數靠人工作業彙整，既耗時又容易增加人為疏漏的風險。"
        day7_detail = "降低合規單據的登打負擔，建立直觀且符合工作習慣的系統"
        day30_target = "提升合規管理與數據流程自動化"
    elif any(k in name_desc for k in ["食品", "飲料", "餐飲", "烘焙", "壽司", "食品生技"]):
        sp_name = "食安智幫手APP"
        sp_url = "https://playplus.com.tw/portfolio/tfif-app"
        sp_scene = "現場稽核與食品安全自主管理流程行動化"
        industry_focus = "食品生產與加工"
        pain_point = "許多食品團隊在規模擴張時，門市與產線常面臨表單管理混亂的問題，前線檢驗與總部稽核資料仍依賴紙本或 Excel，每個月手動彙整耗時又難以即時追蹤進度。"
        day7_detail = "降低門市與總部之間的人工彙整成本"
        day30_target = "提升生產後勤與品質管理自動化"
    elif any(k in name_desc for k in ["建設", "營造", "工程", "不動產", "物業", "房屋"]):
        sp_name = "大管家包租代管系統"
        sp_url = "https://playplus.com.tw/portfolio/chrb"
        sp_scene = "房東與房客管理流程全面數位化"
        industry_focus = "工程與房產服務"
        pain_point = "許多工程與房地產團隊在快速成長時，常面臨「流程隱形」的危機，前線管理或巡檢依賴 Excel，缺乏標準化文件紀錄，一旦資深同仁離職或交接就出現斷層。"
        day7_detail = "改善前線表單填寫與總部追蹤不同步的問題，降低交接斷層風險"
        day30_target = "提升跨據點的營運與行政流程標準化"
    else:
        sp_name = "神達會議室預約系統"
        sp_url = "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system"
        sp_scene = "跨部門資源預約的混亂流程重構"
        industry_focus = "製造與日常營運"
        pain_point = "許多企業在快速擴張的階段，常會遇到內部管理與流程跟不上的問題，關鍵流程往往只存在資深同仁腦中，跨部門協作仍靠 Excel 與人工手動彙整報表。"
        day7_detail = "降低同仁對老舊系統的排斥感，打造符合操作習慣的直觀介面"
        day30_target = "提升內部營運流程與跨部門資源綜效"

    # Day 1
    day1_title = f"{comp_name}的內部作業流程，目前還是靠 Excel 或人工作業嗎？"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"在貴司專注的{industry_focus}領域中，隨著業務成長，同仁是否每天仍花費大量時間處理重複性的人工作業？{pain_point}<br>\n"
        f"<br>\n"
        f"我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們從你們最痛的一條流程開始梳理與開發，打造出易於紀錄與交接的專屬系統。例如我們曾協助開發 {sp_name}（{sp_url}），{sp_scene}。<br>\n"
        f"<br>\n"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 7
    day7_title = f"Re: {comp_name}的內部作業流程，目前還是靠 Excel 或人工作業嗎？"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您簡單分享流程數位化的經驗。理解您平時公務繁忙，這封信只是簡單追蹤，希望沒有打擾到您。<br>\n"
        f"<br>\n"
        f"我們非常重視「前半段」的流程盤點，特別是協助企業{day7_detail}。若貴司近期正計畫重構現有系統，我們可以用 10 分鐘線上交流，看看能如何協助。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 30
    day30_title = "關於優化內部營運流程的最後一封信"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n"
        f"<br>\n"
        f"在與許多中型企業主交流的過程中，我們發現大家雖然想優化系統，但常有兩大顧慮：一是怕開發預算太高，二是怕耗費太多主管的溝通管理時間。為此，我們提供「模組化開發」與「分階段優化方案」，讓企業可以彈性調配預算；且我們有專屬顧問跟進，主管每週只需花 15 分鐘確認進度即可。<br>\n"
        f"<br>\n"
        f"在退場前，再次提醒您，若貴司未來有計畫透過系統升級{day30_target}，隨時歡迎與我們取得聯繫（https://playplus.com.tw/）。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day14_title": "-",
        "day14_content": "-",
        "day30_title": day30_title,
        "day30_content": day30_content,
        "day60_title": "-",
        "day60_content": "-"
    }

def generate_large_enterprise_emails(comp_name, contact_name, industry, description):
    # Rule 1: Greetings
    contact = contact_name.strip()
    if contact in ["官方", "", "無", "聯絡人", "xxx窗口"] or contact.endswith("窗口"):
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    name_desc = (comp_name + " " + industry + " " + description).lower()

    # Rule 2, 3, 4: Industry customization
    if any(k in name_desc for k in ["製造", "科技", "精密", "五金", "機械", "加工", "鐵工", "鋼鐵", "線材", "鋁業", "熱處理", "閥"]):
        # Manufacturing/Tech
        p1 = "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
        p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，放大強調供應商管理與跨部門人力調度，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"
        day7_p2_detail = "跨國據點協作／複雜的供應商對帳／跨部門單據審核"
        day30_target = "提升供應鏈數位韌性"
    elif any(k in name_desc for k in ["零售", "家電", "電子商務", "食品", "飲料", "電商", "門市", "收納", "服裝", "傢俱"]):
        # Retail/Appliances/E-commerce
        p1 = "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
        p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，放大強調一站式入口、工時登錄及簽核流程重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"
        day7_p2_detail = "跨據點銷存協作／複雜 of 經銷對帳／跨部門採購單據審核"
        day7_p2_detail = day7_p2_detail.replace("of", "的")
        day30_target = "提升後勤自動化"
    elif any(k in name_desc for k in ["金融", "保險", "專業服務", "合規", "證券", "銀行", "生技", "醫療", "藥", "開發中心"]):
        # Finance/Insurance/Professional Services
        p1 = "在高度合規與高頻率審核的日常營運中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
        p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，放大強調一站式入口、工時登錄及簽核流程重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"
        day7_p2_detail = "多系統資料拋轉／複雜的合規審查／跨部門表單簽核"
        day30_target = "提升營運流程自動化"
    else:
        # Others
        p1 = "在台灣許多中大型企業日常營運中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
        p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，放大強調一站式入口、工時登錄及簽核流程重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"
        day7_p2_detail = "多端協作／複雜的跨系統對帳／跨部門審核流程"
        day30_target = "提升營運流程效率"

    # Day 1
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{p1}<br>\n"
        f"<br>\n"
        f"我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。<br>\n"
        f"<br>\n"
        f"{p3}<br>\n"
        f"<br>\n"
        f"隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。<br>\n"
        f"<br>\n"
        f"只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # Day 7
    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n"
        f"<br>\n"
        f"我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對貴產業常見的「{day7_p2_detail}」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。<br>\n"
        f"<br>\n"
        f"若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # Day 30
    day30_title = "企業內部系統優化的最後一封信"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n"
        f"<br>\n"
        f"在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{day30_target}，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。<br>\n"
        f"<br>\n"
        f"我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day14_title": "-",
        "day14_content": "-",
        "day30_title": day30_title,
        "day30_content": day30_content,
        "day60_title": "-",
        "day60_content": "-"
    }

def main():
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return

    # 備份 CSV
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已備份 CSV 至：{BACKUP_PATH}")

    # 一次性讀取 CSV 至記憶體
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 內容為空")
        return

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        contact_idx = header.index("聯絡人名稱")
        scenario_idx = header.index("Scenarios")
        industry_idx = header.index("產業")
        desc_idx = header.index("說明")

        mail_fields = [
            "day1_title", "day1_content",
            "day7_title", "day7_content",
            "day14_title", "day14_content",
            "day30_title", "day30_content",
            "day60_title", "day60_content"
        ]
        col_indices = {field: header.index(field) for field in mail_fields}
    except ValueError as e:
        print(f"❌ 缺少必要欄位：{e}")
        return

    print("ℹ️ 欄位 Index 尋找成功。")

    updated_count = 0
    temp_json_data = []

    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, contact_idx, scenario_idx, industry_idx, desc_idx):
            continue

        comp_name = row[name_idx].strip()
        contact_name = row[contact_idx].strip()
        scenario = row[scenario_idx].strip()
        industry = row[industry_idx].strip()
        description = row[desc_idx].strip()

        # 確保該行的欄位長度足夠
        while len(row) < len(header):
            row.append("")

        emails = None
        if scenario == "Quickey_快記":
            emails = generate_quickey_emails(comp_name, contact_name, industry, description)
        elif scenario == "中小企業_企業內部系統":
            emails = generate_sme_emails(comp_name, contact_name, industry, description)
        elif scenario == "大企業_企業內部系統":
            emails = generate_large_enterprise_emails(comp_name, contact_name, industry, description)
        
        if emails:
            # 填入郵件至 CSV
            for field, c_idx in col_indices.items():
                row[c_idx] = emails[field]

            # 存入暫存記錄 (增加 row_index，與原本格式一致)
            record = {
                "row_index": idx + 1,  # CSV 中的行號（1-based 且包括 header，所以是 idx + 1）
                "company_name": comp_name,
                "email": row[header.index("email")].strip() if "email" in header else ""
            }
            for field in mail_fields:
                record[field] = emails[field]

            temp_json_data.append(record)
            updated_count += 1

    # 一次性覆寫回 CSV 檔案
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"✅ CSV 覆寫成功。更新筆數: {updated_count}")

    # 一次性寫回暫存 JSON
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(temp_json_data, f, ensure_ascii=False, indent=2)

    print(f"✅ 暫存 JSON 寫入成功：{TEMP_JSON_PATH}")

if __name__ == '__main__':
    main()
