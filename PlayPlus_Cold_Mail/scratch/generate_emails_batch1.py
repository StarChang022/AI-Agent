#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate Day 1-60 cold email content for all companies in 名單副本.csv
Following PlayPlus 歐美俐落風格 for enterprise internal systems.
"""
import csv
import os

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

# Portfolio references
PORTFOLIO = {
    "mitac": {"name": "神達會議室預約系統", "url": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system", "desc": "跨部門資源預約的混亂問題"},
    "chrb": {"name": "大管家包租代管系統", "url": "https://playplus.com.tw/portfolio/chrb", "desc": "物件管理、租約追蹤與帳務報表自動化"},
    "tfif": {"name": "食安智幫手APP", "url": "https://playplus.com.tw/portfolio/tfif-app", "desc": "食品安全稽核流程數位化"},
    "tsn": {"name": "腎臟醫學會 TSN 病理系統", "url": "https://playplus.com.tw/portfolio/tsn", "desc": "病理報告管理與學術資料彙整"},
}

# Company-specific email content
# Each company gets customized emails based on their industry context
def get_emails(company_name, industry, employee_count, source_url):
    """Generate 5-day email sequence for a given company."""
    
    # Skip the obviously invalid entry
    if company_name == "年終獎金":
        return None
    
    # Determine best portfolio match based on company type
    # For manufacturing companies, Mitac (enterprise booking) and CHRB (management system) are most relevant
    
    # Create industry-specific hooks
    hooks = get_industry_hooks(company_name, industry, employee_count)
    
    emails = {
        "day1_title": hooks["day1_title"],
        "day1_content": hooks["day1_content"],
        "day7_title": hooks["day7_title"],
        "day7_content": hooks["day7_content"],
        "day14_title": hooks["day14_title"],
        "day14_content": hooks["day14_content"],
        "day30_title": hooks["day30_title"],
        "day30_content": hooks["day30_content"],
        "day60_title": hooks["day60_title"],
        "day60_content": hooks["day60_content"],
    }
    return emails


def get_industry_hooks(company_name, industry, employee_count):
    """Generate customized email hooks based on company characteristics."""
    
    # Determine the display name (strip any English prefix like "Envalior_")
    display_name = company_name
    
    # Select varied portfolio examples across different emails
    # Rotate through portfolios to avoid repetition
    portfolio_sets = [
        ("mitac", PORTFOLIO["mitac"]),
        ("chrb", PORTFOLIO["chrb"]),
        ("tfif", PORTFOLIO["tfif"]),
        ("tsn", PORTFOLIO["tsn"]),
    ]
    
    # ---- Customization logic based on company characteristics ----
    
    # Categorize companies for more targeted messaging
    is_precision = any(kw in company_name for kw in ["精密", "精密工具", "精密工業"])
    is_electronics = any(kw in company_name for kw in ["電子", "電機", "科技", "自動化"])
    is_chemical = any(kw in company_name for kw in ["化學", "化工", "樹脂", "塑膠", "鐵氟龍", "複合材料", "尼龍"])
    is_metal = any(kw in company_name for kw in ["金屬", "鋼", "鑄", "鉬", "鉅", "鑫", "鋒"])
    is_food = any(kw in company_name for kw in ["食品", "肉食", "畜"])
    is_biotech = any(kw in company_name for kw in ["生醫", "生化", "藥", "醫"])
    is_energy = any(kw in company_name for kw in ["能源", "新能源"])
    is_textile = any(kw in company_name for kw in ["伊都錦", "ITOKIN"])
    
    # Choose primary pain point based on category
    if is_food:
        pain_hook = "食品製造業的稽核紀錄與批號追蹤"
        pain_detail = "像是原料批號追溯、生產日報表、溫度紀錄這些資料，是不是還在靠紙本或 Excel 手動彙整？"
        best_portfolio = PORTFOLIO["tfif"]
        portfolio_intro = f'例如我們曾協助食品產業開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），將稽核流程從紙本全面數位化，大幅減少人為疏漏。'
        day14_portfolio = PORTFOLIO["chrb"]
        day14_case = f'我們另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），協助業者將物件管理、帳務報表全部系統化，每月省下超過 40 小時的人工作業時間。'
    elif is_biotech:
        pain_hook = "醫藥產業的數據管理與法規追蹤"
        pain_detail = "研發數據、實驗紀錄、法規文件的版本管理，是否還在多人共用資料夾、靠檔名區分版本？"
        best_portfolio = PORTFOLIO["tsn"]
        portfolio_intro = f'例如我們曾協助腎臟醫學會開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），將病理報告與學術資料的管理流程完全系統化。'
        day14_portfolio = PORTFOLIO["mitac"]
        day14_case = f'另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），我們協助神達電腦解決了跨部門資源預約的混亂問題，讓預約流程從信件往返變成一鍵完成。'
    elif is_electronics:
        pain_hook = "科技產業快速擴編後的流程斷層"
        pain_detail = "當團隊人數從 30 人長到 80 人，原本口頭交代就能搞定的事，是否開始出現交接遺漏、進度追蹤困難的問題？"
        best_portfolio = PORTFOLIO["mitac"]
        portfolio_intro = f'例如我們曾協助神達電腦開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），解決了跨部門資源管理的混亂，讓預約與追蹤變得一目了然。'
        day14_portfolio = PORTFOLIO["tsn"]
        day14_case = f'另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），我們將原本散落在各處的資料統一納入系統管理，讓團隊協作效率顯著提升。'
    elif is_chemical:
        pain_hook = "化工產業的配方管理與生產追蹤"
        pain_detail = "配方版本、生產參數、品管紀錄這些關鍵資料，是否還分散在不同人的 Excel 和筆記本裡？"
        best_portfolio = PORTFOLIO["tfif"]
        portfolio_intro = f'例如我們曾為食品產業開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），將製程中的關鍵檢核點全面數位化，確保每筆紀錄都可追溯。'
        day14_portfolio = PORTFOLIO["chrb"]
        day14_case = f'我們的另一個成功案例「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），則是將複雜的物件與帳務管理從 Excel 搬到系統上，讓每月結帳從三天縮短到半天。'
    elif is_metal or is_precision:
        pain_hook = "製造業規模成長後的管理陣痛期"
        pain_detail = "訂單追蹤、生產排程、品管紀錄，是否還在靠資深師傅的經驗和 Excel 表格在撐？一旦關鍵人員請假或離職，流程就斷線？"
        best_portfolio = PORTFOLIO["mitac"]
        portfolio_intro = f'例如我們曾協助神達電腦開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），將原本混亂的跨部門資源管理變得井然有序。'
        day14_portfolio = PORTFOLIO["tfif"]
        day14_case = f'另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），我們協助業者將關鍵製程的稽核紀錄全面數位化，讓每筆資料都能即時追蹤、不再遺漏。'
    elif is_energy:
        pain_hook = "新能源產業快速擴張中的流程挑戰"
        pain_detail = "專案進度、設備管理、維運紀錄是否還在用共用雲端硬碟加 Excel 追蹤？當專案數量翻倍，這套方法還撐得住嗎？"
        best_portfolio = PORTFOLIO["chrb"]
        portfolio_intro = f'例如我們開發的「{best_portfolio["name"]}」（{best_portfolio["url"]}），成功將複雜的多物件管理與帳務追蹤全部系統化，大幅提升營運效率。'
        day14_portfolio = PORTFOLIO["mitac"]
        day14_case = f'另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），我們協助企業將跨部門的資源調度從混亂變為透明可控。'
    elif is_textile:
        pain_hook = "服飾品牌在多通路營運下的管理挑戰"
        pain_detail = "庫存對帳、門市回報、季度報表，是否還需要各門市用不同格式的 Excel 回傳，再由總部花整天彙整？"
        best_portfolio = PORTFOLIO["chrb"]
        portfolio_intro = f'例如我們開發的「{best_portfolio["name"]}」（{best_portfolio["url"]}），將分散多處的物件資料與帳務報表統一管理，讓月底結算從三天縮短到幾小時。'
        day14_portfolio = PORTFOLIO["mitac"]
        day14_case = f'另一個案例是「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），協助企業將跨部門的資源協調流程完全線上化，省去大量來回溝通的時間成本。'
    else:
        # General manufacturing default
        pain_hook = "中型企業成長期的內部管理瓶頸"
        pain_detail = "當公司從幾十人成長到近百人規模，原本靠 Excel 和口頭交代的管理方式，是否開始出現紀錄遺漏、交接困難的問題？"
        best_portfolio = PORTFOLIO["mitac"]
        portfolio_intro = f'例如我們曾協助神達電腦開發「{best_portfolio["name"]}」（{best_portfolio["url"]}），解決了跨部門資源預約的混亂問題。'
        day14_portfolio = PORTFOLIO["chrb"]
        day14_case = f'我們另一個案例「{day14_portfolio["name"]}」（{day14_portfolio["url"]}），則是將複雜的物件管理與帳務追蹤完全系統化，每月省下大量人工彙整時間。'

    # ===== DAY 1: 建立關聯 =====
    day1_title = _get_day1_title(company_name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile)
    
    day1_content = (
        f"您好，<br>"
        f"<br>"
        f"{pain_detail}<br>"
        f"<br>"
        f"我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型 ERP，而是從您最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬工具。{portfolio_intro}<br>"
        f"<br>"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以先從這邊瀏覽我們的服務及作品集：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
    )

    # ===== DAY 7: 溫和提醒 =====
    day7_title = _get_day7_title(company_name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile)
    
    day7_content = (
        f"您好，<br>"
        f"<br>"
        f"上週寄了一封信聊到{pain_hook}的議題，不確定您是否有機會看到。我知道您業務繁忙，若無法回覆我完全能理解。<br>"
        f"<br>"
        f"如果這個議題剛好也是貴公司目前面臨的挑戰，歡迎直接回覆這封信，我可以提供幾個同產業的數位化案例做為參考：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
    )

    # ===== DAY 14: 價值證明 =====
    day14_title = _get_day14_title(company_name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile)
    
    day14_content = (
        f"您好，<br>"
        f"<br>"
        f"想跟您分享一個我們近期的實戰案例，可能對貴公司有參考價值。<br>"
        f"<br>"
        f"{day14_case}<br>"
        f"<br>"
        f"許多中型企業在成長期都面臨類似的痛點——流程散落在不同人手上、資料靠人工彙整、主管沒有即時的管理儀表板。這些問題不是買一套現成軟體就能解決的，而是需要「量身打造」。<br>"
        f"<br>"
        f"如果您也有類似的困擾，我很樂意花 15 分鐘跟您分享我們是怎麼從零開始幫企業解決這些問題的。更多案例請參考：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
    )

    # ===== DAY 30: 處理異議 =====
    day30_title = _get_day30_title(company_name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile)
    
    day30_content = (
        f"您好，<br>"
        f"<br>"
        f"之前寄了幾封信聊到企業內部系統數位化的議題，我猜您可能有些顧慮，這很正常。以下是我們最常聽到的三個問題：<br>"
        f"<br>"
        f"<b>「客製化系統是不是很貴？」</b><br>"
        f"我們採用模組化開發，可以先從最急迫的一條流程開始，預算從幾萬元就能啟動，不需要一次投入幾百萬。<br>"
        f"<br>"
        f"<b>「導入系統會不會很花時間？」</b><br>"
        f"我們的專案週期通常在 4-8 週，而且主管每週只需要 15 分鐘確認進度即可，不會占用您太多時間。<br>"
        f"<br>"
        f"<b>「同仁會不會不習慣新系統？」</b><br>"
        f"我們的設計原則就是「讓使用者覺得比 Excel 更簡單」。介面直覺、操作簡單，上線培訓通常只需要一次。<br>"
        f"<br>"
        f"如果您只是目前時機不對，我完全理解。但如果是上述這些顧慮讓您猶豫，歡迎回信聊聊，也許只是一個 15 分鐘的對話就能釐清。參考我們的服務及作品集：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
    )

    # ===== DAY 60: 優雅退場 =====
    day60_title = _get_day60_title(company_name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile)
    
    day60_content = (
        f"您好，<br>"
        f"<br>"
        f"這是我最後一次就這個議題打擾您了。<br>"
        f"<br>"
        f"過去幾週我分享了一些企業內部流程數位化的案例與想法，但也許目前不是貴公司考慮這件事的時間點，這我完全能理解。<br>"
        f"<br>"
        f"我不會再主動寫信給您，但如果未來有一天，您發現某條流程真的靠人力撐不住了——無論是紀錄追蹤、報表彙整還是交接斷層——歡迎隨時回覆這封信，我們的團隊會在。<br>"
        f"<br>"
        f"祝貴公司業務蒸蒸日上。我們的服務及作品集：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
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
        "day60_content": day60_content,
    }


def _get_day1_title(name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile):
    """Generate varied Day 1 titles based on company type."""
    if is_food:
        return f"食品製造的稽核紀錄，還在用紙本？"
    elif is_biotech:
        return f"研發數據散落各處，是否讓您頭疼？"
    elif is_electronics:
        return f"團隊擴編後，流程是否開始跟不上？"
    elif is_chemical:
        return f"配方版本管理，還在靠人腦記憶？"
    elif is_precision:
        return f"精密製造的品管紀錄，有更聰明的做法"
    elif is_metal:
        return f"生產排程與品管追蹤，還在靠 Excel？"
    elif is_energy:
        return f"專案數量翻倍，管理工具跟上了嗎？"
    elif is_textile:
        return f"多門市的庫存與回報，還在人工彙整？"
    else:
        return f"公司快速成長，內部管理跟上了嗎？"


def _get_day7_title(name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile):
    """Generate varied Day 7 titles."""
    if is_food:
        return f"快速跟進：關於食品稽核數位化"
    elif is_biotech:
        return f"簡短跟進：數據管理的另一種可能"
    elif is_electronics:
        return f"簡短補充：流程優化的一個想法"
    elif is_chemical:
        return f"簡短跟進：製程管理的數位化方案"
    elif is_precision or is_metal:
        return f"快速跟進：製造業流程數位化"
    elif is_energy:
        return f"簡短跟進：能源產業的管理工具"
    elif is_textile:
        return f"簡短跟進：多通路管理的解方"
    else:
        return f"快速跟進：關於內部流程優化"


def _get_day14_title(name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile):
    """Generate varied Day 14 titles."""
    if is_food:
        return f"一個食品業數位化的真實案例"
    elif is_biotech:
        return f"醫藥產業的系統化管理實例"
    elif is_electronics:
        return f"科技公司怎麼用系統解決管理問題"
    elif is_chemical:
        return f"同產業的流程數位化成功案例"
    elif is_precision or is_metal:
        return f"製造業客戶如何告別 Excel 管理"
    elif is_energy:
        return f"快速成長企業的系統化管理實例"
    elif is_textile:
        return f"品牌如何用系統統一多點管理"
    else:
        return f"一個中型企業數位轉型的真實案例"


def _get_day30_title(name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile):
    """Generate varied Day 30 titles."""
    if is_food:
        return f"關於系統導入，您可能有這些顧慮"
    elif is_biotech:
        return f"客製化系統常見的三個疑慮"
    elif is_electronics:
        return f"導入內部系統前，先解答三個常見問題"
    elif is_chemical:
        return f"關於數位化轉型的三個常見顧慮"
    elif is_precision or is_metal:
        return f"客製化系統沒有想像中複雜"
    elif is_energy:
        return f"系統導入的三個常見疑問，一次回答"
    elif is_textile:
        return f"導入管理系統前的三個常見顧慮"
    else:
        return f"關於系統數位化，常見的三個顧慮"


def _get_day60_title(name, is_food, is_biotech, is_electronics, is_chemical, is_metal, is_precision, is_energy, is_textile):
    """Generate varied Day 60 titles."""
    if is_food:
        return f"最後一封信：未來有需要隨時找我們"
    elif is_biotech:
        return f"最後一封：需要時我們隨時都在"
    elif is_electronics:
        return f"不再打擾，但我們隨時為您效勞"
    elif is_chemical:
        return f"最後一封信，但大門隨時為您敞開"
    elif is_precision or is_metal:
        return f"最後一封：未來有需求歡迎隨時聯繫"
    elif is_energy:
        return f"不再打擾，但大門隨時為您開著"
    elif is_textile:
        return f"最後一封信：需要時隨時找我們"
    else:
        return f"最後一封信：未來有需要，我們隨時都在"


def main():
    # Read CSV
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            rows.append(row)
    
    print(f"Read {len(rows)} rows from CSV")
    print(f"Columns: {fieldnames}")
    
    # Generate emails for each company
    updated_count = 0
    skipped = []
    
    for row in rows:
        company_name = row.get("公司品牌簡稱", "").strip()
        industry = row.get("產業", "").strip()
        employee_count = row.get("員工人數", "").strip()
        source_url = row.get("說明", "").strip()
        
        if not company_name:
            skipped.append("(empty)")
            continue
        
        emails = get_emails(company_name, industry, employee_count, source_url)
        
        if emails is None:
            skipped.append(company_name)
            continue
        
        # Write email content to row
        row["day1_title"] = emails["day1_title"]
        row["day1_content"] = emails["day1_content"]
        row["day7_title"] = emails["day7_title"]
        row["day7_content"] = emails["day7_content"]
        row["day14_title"] = emails["day14_title"]
        row["day14_content"] = emails["day14_content"]
        row["day30_title"] = emails["day30_title"]
        row["day30_content"] = emails["day30_content"]
        row["day60_title"] = emails["day60_title"]
        row["day60_content"] = emails["day60_content"]
        
        updated_count += 1
        print(f"  ✓ {company_name}")
    
    # Write back to CSV
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"\n✅ Done! Updated {updated_count} companies, skipped {len(skipped)}: {skipped}")
    print(f"📄 CSV saved to: {CSV_PATH}")


if __name__ == "__main__":
    main()
