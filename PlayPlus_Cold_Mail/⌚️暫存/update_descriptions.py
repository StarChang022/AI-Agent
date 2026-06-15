#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
更新 名單副本.csv 中的公司說明（I 欄）為重新撰寫的一句話介紹（繁體中文、專業口吻、200字以內）。
"""

import os
import csv
import json
import shutil

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
BACKUP_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本_backup_intro.csv"
TEMP_JSON_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

# 34 家不重複目標公司的全新專業一句話簡介
INTRO_MAPPING = {
    "三春機械股份有限公司": "三春機械股份有限公司創立至今通過 ISO 9001 認證，專注於提供美規、德規與日規等多種規格的高品質法蘭製品及五金零件製造加工服務。",
    "益在企業股份有限公司": "益在企業擁有逾 40 年精密切削刀具研發製造經驗，以自有品牌行銷全球，產品廣泛應用於電子、鋼鐵及半導體等高精密切削領域。",
    "Viscount Industries CO.\t ltd_美而光實業股份有限公司": "美而光實業成立於 1973 年，專注於自行設計與研發巴士、軌道及電動輪椅等各類交通運輸工具座椅、自行車座墊及健身器材配件。",
    "安華機電工程股份有限公司": "安華機電由東元電機與日本安川電機合資成立，專注於工廠智慧化機電控制系統整合，並提供創能、儲能與節能的綠色能源管理解決方案。",
    "北聯研磨科技股份有限公司": "北聯研磨深耕精密研磨領域近 40 年，現全面升級廠房並引進自動化設備，強勢進軍半導體高階 SiC 晶圓減薄與精密砂輪製造。",
    "高嘉塑膠股份有限公司": "高嘉塑膠創立於 1990 年，專注於研發及生產高品質工業用 PE 包裝材料、保護膜、PS 平板及壓克力板，產品深受國內外大型企業肯定。",
    "允暢五金工具股份有限公司": "允暢五金成立於 1981 年，以自有品牌 Thumb Brand 專注於建築與工業專用緊固件、多材質排釘及螺絲的設計、研發與客製化生產。",
    "普惠醫工股份有限公司": "普惠醫工成立於 1989 年，為專業醫療耗材製造興櫃公司，取得 ISO 13485 等認證，提供高品質輸液套、注射筒及洗腎針等產品。",
    "春星工業股份有限公司": "春星工業股份有限公司專注於盤元線材加工與製造，致力於提供穩健的高品質產品，並以關懷員工與持續成長為企業核心價值。",
    "頌勝科技材料股份有限公司": "頌勝科技材料成立於 1986 年，為專業的高性能材料公開發行公司，專注於半導體耗材、綠色黏著劑、PU 彈性體與醫療健康產品的研發。",
    "傑出材料科技股份有限公司": "傑出材料科技成立於 2004 年，專注於鎂合金與鋁鈧合金材料的開發、管板材製造及加工，致力於為全球客戶提供頂尖的輕量化金屬解決方案。",
    "仕懋股份有限公司": "仕懋股份有限公司創立於 1980 年，專注於血液淨化、再生醫學、輸血安全設備與耗材研發，並提供醫護臨床模擬教育模型的設計製造。",
    "好邦科技股份有限公司": "好邦科技成立於 1977 年，為通過雙系統認證的專業貴金屬連續表面處理與連接器零組件加工廠，提供精密表面處理與機械設計製造服務。",
    "壽元化學工業股份有限公司": "壽元化學工業創立於 1946 年，專注於針劑、錠劑、軟膏及液劑等藥品的製造與銷售，近年積極開拓東南亞及全球外銷市場。",
    "乾唐軒美術工藝股份有限公司": "乾唐軒創立於 1986 年，以「ACERA」品牌融合漢唐文化藝術與現代設計，專利研發「活瓷」健康陶瓷茶具、隨身杯與藝術器皿。",
    "台灣芝浦先進科技股份有限公司": "台灣芝浦為日本芝浦 100% 出資子公司，專注於為 LCD 面板、半導體及光碟製造設備提供高品質的銷售、售後維修服務與零件國產化。",
    "國科生技製藥股份有限公司": "國科生技製藥為 GMP 傳統科學中藥製造廠，以「正揚藥品」品牌運用精密儀器與嚴格品管，產製濃縮製劑、膠囊及外用貼布等近千種中藥。",
    "鑫茂機械工業股份有限公司": "鑫茂機械成立於 2002 年，專注於高精度刨床、壓刨機及帶鋸機等木工機械的研發製造，是全球知名品牌的優質 OEM/ODM 合作夥伴。",
    "台穩精密工業股份有限公司": "台穩精密成立於 1971 年，為台中精機集團成員，配備高精密研磨設備，專注於生產符合國際高精度標準的各式精密齒輪與產業齒輪箱。",
    "益恆科技股份有限公司": "益恆科技深耕綠能產業多年，提供全台電動汽車與電動機車充電設備的專業規劃、架設、安裝與維修保養一站式服務。",
    "呷七碗_嘉義食品工業股份有限公司": "呷七碗（嘉義食品）專注於冷凍與即時食品生產，通過 CAS、ISO-22000 及 HACCP 認證，主營彌月油飯、養生飲品及冷凍食品。",
    "谷綠林股份有限公司": "谷綠林成立於 2005 年，專注於系統傢俱與廚具的專業規劃、設計、拆圖報價與特殊造型加工，並擁有占地五千坪的現代化新莊廠房。",
    "富翔電機有限公司": "富翔電機成立於 1997 年，專注於製造高品質高低壓配電盤與控制盤，提供半導體廠房、儲能系統及 AI 數據中心等重電機整合方案。",
    "宜益股份有限公司": "宜益股份有限公司創立逾 50 年，以自有品牌「日農牌」中耕除草管理機聞名，專營農業機械及園藝球場設備的製造、銷售與維修服務。",
    "國郁企業股份有限公司": "國郁企業成立於 1991 年，以自有品牌 KUOYUH 專注於過載保護器與斷路器等電子零組件研發，提供全球客戶一站式的 OEM/ODM 服務。",
    "府城事業有限公司": "府城事業創立於 2003 年，通過 FSSC 22000 國際認證，專注於生鮮肉品、醬料與客製化調理食品的研發、充填包裝及商業滅菌代工。",
    "至得應用材料股份有限公司": "至得應用材料成立於 2004 年，專營不鏽鋼、馬口鐵及銅合金等特殊金屬材料進口與精密分條、CNC 自動整平切板與剪床裁切加工。",
    "大云股份有限公司": "大云股份成立於 1982 年，專注於高分子材料研發，生產製造仿木建材、塑鋼籐條、PVC/TPE 塑膠粒及橡膠製品，產品銷售全球 50 多國。",
    "順噠實業股份有限公司": "順噠實業成立於 1982 年，為通過 ISO 9001 認證的鋼捲加工自動化送料與沖壓週邊設備專業製造廠，提供整廠彈性製造系統規劃。",
    "展聖企業股份有限公司": "展聖企業專注於傳統與數位印刷、平面設計、網路行銷及多媒體有聲出版，致力於提供文創商品開發與客製化紙紮模型等多元化服務。",
    "誠鋒興業股份有限公司": "誠鋒興業創立逾 40 年，專注於製鞋自動化成型機器與智能化機械的研發製造，於多國設有辦事處，並致力於綠能相關節能設備與 ESG 佈局。",
    "大詳有限公司": "大詳有限公司成立於 1981 年，專注於拐杖、助行器、洗澡椅等五金醫療復健輔助器材的研發、生產與出口，提供 OEM/ODM 客製化服務。",
    "亞格齒輪企業股份有限公司": "亞格齒輪創立於 1991 年，專注於螺旋傘齒輪的專業設計規劃與製造，通過 ISO 9001 與 TS 16949 認證，廣泛應用於汽車、航太及工業工具。",
    "固品塑膠工業股份有限公司": "固品塑膠成立於 1995 年，專注於半導體導電與抗靜電複合材料的研發，在台灣擁有過半 IC Tray 原料供應市佔率，為行業領先者。"
}

def main():
    # 1. 備份原始 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 讀取並更新 CSV 資料
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = rows[0]
    
    # 尋找「公司名稱」與「說明」的欄位 index
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ CSV 標頭缺少必要欄位：{e}")
        return

    print(f"  → 「公司名稱」欄位 Index: {name_idx}, 「說明」欄位 Index: {desc_idx}")

    updated_count = 0
    skipped_count = 0
    temp_logs = []

    for i in range(1, len(rows)):
        row = rows[i]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        
        comp_name = row[name_idx].strip()
        orig_desc = row[desc_idx].strip()

        if comp_name in INTRO_MAPPING:
            new_desc = INTRO_MAPPING[comp_name]
            row[desc_idx] = new_desc
            updated_count += 1
            temp_logs.append({
                "company_name": comp_name,
                "original_description": orig_desc,
                "new_description": new_desc
            })
        else:
            skipped_count += 1
            print(f"  [跳過] 未找到匹配的重寫介紹：{comp_name}")

    # 3. 寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ 已成功更新 CSV 檔。更新數: {updated_count}, 跳過數: {skipped_count}")

    # 4. 寫入暫存 JSON 檔
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(temp_logs, f, ensure_ascii=False, indent=2)
    print(f"✅ 已成功將更新紀錄與對照暫存至：{TEMP_JSON_PATH}")

if __name__ == "__main__":
    main()
