# -*- coding: utf-8 -*-
import csv
import json
import os
import shutil

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
BACKUP_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本_backup_intro.csv"
TEMP_JSON_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

INTRO_MAPPING = {
    "豆豆食品股份有限公司": "豆豆食品創立於1984年，專注於各式糕餅麵包甜點用餡料與餅皮的研發與製造，秉持「技術現代化，傳統古早味」的精神為客戶提供優質原料。",
    "博佳康健股份有限公司": "博佳康健成立已逾20年，長期代理德國百年健康品牌beurer博依與Rommelsbacher諾曼百赫廚房家電，並全方位經營各大實體與虛擬通路，提供優質售後服務。",
    "比德堡精密實業有限公司": "比德堡精密實業創立於1992年，專注於車用嵌入式晴雨窗及汽車掀頂帳篷等優質汽車零配件的設計與專利製造，致力成為亞洲專業領導品牌。",
    "台灣英飛特股份有限公司": "台灣英飛特為韓國Infinitt台灣分公司，專注於研發醫療影像處理、網路傳輸軟體與PACS解決方案，並提供全方位的醫院無紙化數位解決方案。",
    "上林實業有限公司": "上林實業以客為本，專注於提供大宗黑白影印、數位彩色輸出與變動性資料輸出等快速、高品質的列印與裝訂服務。",
    "ChizUP_熱柴有限公司": "ChizUP_熱柴有限公司創立於2015年，專注於研發減糖低脂、純手工製作的黃金比例重乳酪起司蛋糕，為消費者提供健康且充滿創意的美味甜點。",
    "國際電木板企業有限公司": "國際電木板企業創立於1984年，專注於電子絕緣材料（如電木板及纖維板）的製造以及各類工程塑膠的經銷批發與零售服務。",
    "翔光照明電器股份有限公司": "翔光照明以自有品牌「超光Ultralux」專營LED高功率燈具製造、OEM客製化生產及照明模擬規劃，致力為客製化場所提供全方位照明方案。",
    "國慶精密股份有限公司": "國慶精密創立於1987年，為通過ISO 9001認證的專業銅合金分條廠，專注於各類銅合金之經銷代理與客製化加工，服務廣大電子與汽車產業。",
    "貝特機械股份有限公司": "貝特機械創立於1984年，為全球領先的木工用自動送材機、貼邊機及相關週邊產品的專業研發與製造廠商。",
    "真善美廣告企業有限公司": "真善美廣告創立於1985年，提供各式廣告招牌、LED看板的規劃製作、外牆亮化工程及維護保養一條龍式的專業服務。",
    "賽恩斯國際有限公司": "賽恩斯國際以「賽先生科學工廠」為品牌，專注於結合科學、教育與設計，研發與銷售具美感和知識的趣味禮品，並提供客製化開發與體驗課程。",
    "串良股份有限公司": "串良股份有限公司設立於1979年，專注於人流與車流引導系統之塑膠鏈條、護欄及LED護欄的設計與製造，並提供專業的OEM與ODM技術合作服務。",
    "興友科技股份有限公司": "興友科技深耕生物阻抗分析技術（BIA）領域，專注於開發與製造高精準度的專業及家用體組成分析儀與體脂計，為全球醫療與健康管理提供精確的評估工具。",
    "宸鼎生物科技股份有限公司": "宸鼎生物科技創立於2017年，專注於以創新生物技術建構綠色循環經濟，研發與生產高品質的食用酒精、清潔用及電子用酒精。",
    "旺昕貿易有限公司": "旺昕貿易專注於足部健康領域，提供免費足部壓力檢測，並專業研發與經銷足部醫療輔具、特製鞋具及特製鞋墊等健康鞋款。",
    "鈦郁工業股份有限公司": "鈦郁工業成立於1996年，專注於鈦、不銹鋼等高端金屬的精密成型與焊接技術，為全球客戶提供完全客製化的自行車車架、零件及管材解決方案。",
    "瑞士商柏泰有限公司台灣分公司": "瑞士商柏泰創立於1831年，為全球緊固件與智慧物流管理的領導品牌，為高科技與工業客戶提供高品質緊固件、工程研發服務及智慧工廠物流方案。",
    "盛展泓精密股份有限公司": "盛展泓精密專研連續沖壓模具設計開發與五金零件代工生產（OEM/ODM）逾40年，產品廣泛應用於門鎖、電腦、汽車與電子五金等領域。",
    "橙澳科技股份有限公司": "橙澳科技成立於2017年，專注於客製化檢測設備與自動化產線設計，提供視覺辨識（AOI）、數據監控及物聯網（IoT）機台升級與改造服務。",
    "慶順五金股份有限公司": "慶順五金創立於1970年，專門經營與代理各國品牌軸承及各類機械五金工具，配備完善的倉儲管理與ERP系統，為工廠及研發團隊提供一應俱全的供應服務。",
    "永泰精密科技股份有限公司": "永泰精密科技創立於2010年，專注於高品質塑膠容器與配件生產，提供包含專利透氣瓶蓋、模內貼容器及環保PA多層瓶等客製化塑膠包裝解決方案。",
    "卓昇有限公司": "卓昇有限公司成立於1991年，專門獨家代理歐洲、美國及加拿大等多國生物科技研究用抗體試劑、檢測儀器與耗材，並提供專業電子商務服務。",
    "廣瀚儀器有限公司": "廣瀚儀器創立於1995年，專注於科學理化儀器、工安檢測器材及無塵室設備耗材之專業代理、經銷諮詢與客製化加工代工服務。",
    "弘佳工業股份有限公司": "弘佳工業成立逾25年，專注於生產合成橡膠跑道、球場鋪面與健身房地面鋪材，並提供運動場地設計、規劃與施工的專業一條龍服務。",
    "寶藝模具股份有限公司": "寶藝模具成立於2010年，專注於高精度鎢鋼與陶瓷模具零配件及精密機械零件的製造與銷售，為全球客戶提供高精度加工與優質售後服務。",
    "高傑工業股份有限公司": "高傑工業創立於1985年，專注於汽車零配件（如自行車架與行李架）之製造與外銷，以及風扇馬達、數控機床等各式機械設備的國外貿易服務。"
}

def main():
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return

    # 1. 備份原始 CSV
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 一次性讀取 CSV 內容 (使用 utf-8-sig 以免 BOM 亂碼)
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 內容為空")
        return

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ 缺少必要欄位：{e}")
        return

    print(f"ℹ️ 「公司名稱」欄位 Index: {name_idx}, 「說明」欄位 Index: {desc_idx}")

    updated_count = 0
    skipped_count = 0
    temp_records = []

    # 3. 在記憶體中逐行更新說明欄位 (跳過首行 header)
    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        
        comp_name = row[name_idx].strip()

        if comp_name in INTRO_MAPPING:
            new_desc = INTRO_MAPPING[comp_name]
            row[desc_idx] = new_desc
            updated_count += 1
            # 存入暫存記錄 (與 update_descriptions_new.py 格式一致)
            temp_records.append({
                "company_name": comp_name,
                "new_description": new_desc
            })
        else:
            skipped_count += 1

    # 4. 一次性寫回 CSV (保留 UTF-8 + BOM 格式)
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"✅ CSV 覆寫成功！共更新: {updated_count} 筆，無須更新/跳過: {skipped_count} 筆。")

    # 5. 寫入暫存 JSON 檔案
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(temp_records, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 暫存 JSON 寫入成功：{TEMP_JSON_PATH}")

if __name__ == '__main__':
    main()
