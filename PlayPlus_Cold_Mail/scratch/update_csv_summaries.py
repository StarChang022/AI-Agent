import csv
import json
import os

# Define paths
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_104_python/temp_profiles.json"

# Summaries from AI
summaries = {
    "永琴實業": "永琴實業成立於2005年，身為日本避震器領導品牌KYB的台灣總代理，專精於汽機車底盤及避震器零組件的經銷。結合母公司永華機械強大的製造與OEM經驗，永琴在台深耕專業服務，建立全台完善的經銷據點，穩坐底盤系統供應商的領導地位。",
    "福金剛": "福金剛深耕電腦周邊與電競市場十餘年，代理IROKS與LEXMA等知名品牌。公司秉持「共好」與「善念」的經營哲學，不僅致力於產品創新如與藝人蕭敬騰聯名開發，更重視企業社會責任與人性化的工作環境，提供高效且具備設計感的生活與電競周邊解決方案。",
    "嘉聯醫藥生技": "嘉聯醫藥生技成立於2021年，是一家新興且充滿活力的醫藥物流服務商，專注於為診所、藥局等基層醫療體系提供精準、高效的物資配送。公司秉持以人為本，致力打造高品質的流通環境，並透過不斷優化的物流系統，支援台灣醫藥產業的精緻化發展。",
    "普明能流體控制": "德商ProMinent成立於1960年，為全球水處理與加藥系統的領航者。台灣分公司專精於半導體、化工及水處理領域的化學加藥混合設備。產品包含高效定量泵、專利水質電極與二氧化氯殺菌系統，協助台積電等企業達成製程回收水的高準度控制。",
    "立聖實驗器材": "立聖實驗器材起源於專業玻璃儀器加工，現已發展為多元化的理化實驗室耗材供應商。產品涵蓋玻璃器皿與各式實驗耗材，憑藉客製化生產能力與具競爭力的價格，服務於廣大化工業界，不僅堅持產品質量，更透過專業諮詢協助客戶提升實驗室運作效能。",
    "旭鋒企業": "旭鋒企業自1973年成立以來，代理歐洲軸承品牌如FAG、INA等已逾五十年。服務範圍涵蓋工具機、鋼鐵與自動化產業，提供各階層軸承的一條龍式購足服務。旭鋒以深厚的產業知識搭配原廠失效分析技術，為台灣製造業提供穩定、高精度的關鍵機械零組件解決方案。",
    "傢寓美學": "MOOYU睦寓是一家專注於空間美學與客製化傢俱設計的品牌。跳脫標準化生產，睦寓結合空間諮詢顧問與自有產線，為客戶量身裁縫專屬生活餘裕。從尺寸至面料細節皆極度講究，致力於將美感與工藝深度結合，透過毫米級的精準度，將客戶心目中的理想居家場景具現化。",
    "友和國際": "友和國際創立於1991年，專精於塑膠加工自動化除濕、送料工程及代理國外知名處理設備。服務範圍涵蓋射出成形、醫療及光電產業，提供從規劃設計、施工到維修的完整解決方案。憑藉三十年專業經驗，協助企業優化流程、降低成本，是塑膠產業自動化的關鍵合作夥伴。",
    "倚新": "倚新由資深研發工程師團隊創立，專精於多螢幕顯示卡及客製化電腦OEM/ODM服務。產品廣泛應用於數位看板、遊戲機、醫療、金融證券及安全監控等領域。以紮實的技術研發能量及彈性靈活的客製能力，為全球客戶提供高品質且具備高度兼容性的工業級顯示解決方案。",
    "荷康乳品": "荷康乳品代理荷蘭皇家菲仕蘭（FrieslandCampina）奶油，旨在提供客戶安全、健康、高品質之乳製品原料。面對市場多變性與各項挑戰，竭力滿足客戶需求。在積極拓展下顯著成長，致力將菲仕蘭打造為台灣乳業領導品牌，成為供應鏈中的品質標竿。",
    "康盛國際貿易": "康盛國際貿易成立於2006年，是台灣牙科專業矯正器械的領導代理商，取得歐美多家知名製造大廠的獨家代理權。專注於牙科矯正牙材與器械的代理與銷售，憑藉最佳的產品品質與專業的工作團隊，在業內展現出強大的市場潛力與專業信譽。",
    "名笙": "名笙股份有限公司創立三十年，專業於旅館客房控制系統，為國際五星級酒店指定的客房控制品牌。產品通過多國安規認證，擅長整合燈光、空調與各類客控系統。以科技引領服務，協助旅館業數位轉型，實現節能環保與高效管理，打造高品質的高端旅宿體驗。"
}

def update_csv():
    # Read CSV
    rows = []
    fieldnames = []
    with open(csv_path, mode='r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            rows.append(row)
    
    # Update rows
    for row in rows:
        company = row.get("公司品牌簡稱")
        if company in summaries:
            row["說明"] = summaries[company]
    
    # Write CSV
    with open(csv_path, mode='w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print("CSV updated successfully.")

if __name__ == "__main__":
    update_csv()
    # Cleanup JSON
    if os.path.exists(json_path):
        os.remove(json_path)
        print("temp_profiles.json deleted.")
