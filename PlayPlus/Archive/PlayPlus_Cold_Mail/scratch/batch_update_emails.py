import csv
import os

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

def generate_emails(row):
    company = row.get("公司品牌簡稱", "貴公司").strip()
    contact = row.get("聯絡人名稱", "").strip()
    desc = row.get("說明", "").strip()
    
    greeting = "您好，"
    if contact and contact != "官方" and "窗口" not in contact:
        greeting = f"{contact} 您好，"

    # --- Day 1 ---
    # Custom hook based on description
    hook = ""
    if "五金" in desc or "製造" in desc:
        hook = f"我剛瀏覽了{company}的資料，注意到你們在精密製造與品質管理上有深厚的底蘊。隨著行銷世界多國，內部的生產排程與訂單追蹤想必也日益複雜。"
    elif "文化" in desc or "設計" in desc:
        hook = f"我注意到{company}在圖書設計與 AR 技術上的創新，這類高效率的創意產出，往往需要極其精準的內部協作流程來支撐。"
    elif "電機" in desc or "電磁" in desc:
        hook = f"我剛看到{company}在電磁線圈領域的專業地位。身為義大利集團的重要基地，跨國協作與生產數據的即時性想必是營運核心。"
    elif "印刷" in desc:
        hook = f"我看到{company}在特殊印刷領域的 ISO 認證與標準化流程。在追求高品質產出的同時，如何讓報表彙整與客戶追蹤更自動化，是許多同業目前的轉型重點。"
    elif "鋼鐵" in desc or "鋼筋" in desc:
        hook = f"我剛瀏覽了{company}的資料，注意到你們在鋼鐵球化與加工產量上的領導地位。在如此大規模的生產環境中，如何減少人工報表處理、優化流程紀錄，通常能大幅提升獲利空間。"
    else:
        hook = f"我剛瀏覽了{company}的網站，注意到你們近期業務與團隊規模成長非常快速。這通常也代表內部的管理流程（如報表彙整、進度追蹤）正面臨數位化的轉型期。"

    day1_title = f"探討：{company} 的內部流程優化想法"
    day1_content = (
        f"{greeting}<br><br>"
        f"{hook}<br><br>"
        f"我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型 ERP，而是從你們最痛的一條流程開始（如新人交接、手動彙整報表等），打造好紀錄、好追蹤、好交接的專屬工具。<br><br>"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        "感謝您"
    )

    # --- Day 7 ---
    day7_title = f"快速確認：上週與您分享的內部管理想法"
    day7_content = (
        f"{greeting}<br><br>"
        f"想簡單確認一下，您是否有機會看到我上週關於{company}流程數位化的信件？<br><br>"
        "如果您正忙於業務擴張，這封信或許能為您帶來一些內部管理自動化的靈感。您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        "感謝您"
    )

    # --- Day 14 ---
    day14_title = f"分享：如何協助企業解決跨部門預約混亂（案例分享）"
    social_proof = "神達電腦開發的會議室預約系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system）"
    if "製造" in desc:
        social_proof = "食安智幫手 APP（https://playplus.com.tw/portfolio/tfif-app）"
    
    day14_content = (
        f"{greeting}<br><br>"
        f"我一直在關注{company}的發展。許多與貴司規模相仿的企業在轉型時，最擔心開發曠日廢時且預算難控。<br><br>"
        f"以我們協助{social_proof}為例，我們成功解決了資源預約與追蹤的混亂問題。您感興趣了解這類「模組化開發」如何幫助貴司在控制預算下快速啟動數位化嗎？<br><br>"
        "您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        "感謝您"
    )

    # --- Day 30 ---
    day30_title = f"解決數位轉型的兩大顧慮：預算與時間"
    day30_content = (
        f"{greeting}<br><br>"
        "根據經驗，許多企業遲遲未啟動數位化，多半是擔心預算過高或員工學習成本太重。<br><br>"
        "PlayPlus 提供「分階段優化方案」，您可以從最核心的一個流程開始。我們系統設計極簡口語化，主管每週只需 15 分鐘確認進度。不知道這是否能解決您目前的顧慮？<br><br>"
        "您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        "感謝您"
    )

    # --- Day 60 ---
    day60_title = f"期待未來有機會合作：{company}數位轉型的一封信"
    day60_content = (
        f"{greeting}<br><br>"
        "我看這陣子您可能專注於其他更優先的事務，我也就不再主動打擾了。<br><br>"
        f"數位轉型是場長跑，未來若{company}有任何內部流程自動化、報表系統化的需求，隨時歡迎聯絡。祝貴司業務蒸蒸日上。<br><br>"
        "您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        "感謝您"
    )

    return {
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
    }

def main():
    rows = []
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            emails = generate_emails(row)
            row.update(emails)
            rows.append(row)

    with open(CSV_PATH, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✅ 成功更新 {len(rows)} 筆潛在客戶的冷郵件內容！")

if __name__ == "__main__":
    main()
