import csv
import os
import time

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("【系統提示】執行此腳本需要安裝 Playwright。")
    print("請開啟終端機 (Terminal) 並依序執行以下兩行指令安裝：")
    print("1. pip3 install playwright")
    print("2. playwright install chromium")
    exit(1)

def run():
    input_file = os.path.join('冷郵件對象', '名單副本104.csv')
    
    if not os.path.exists(input_file):
        print(f"找不到檔案: {input_file}")
        return

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = list(reader)

    new_rows = []
    
    # 檢查是否有名單需要處理
    urls_to_process = [row for row in rows if "104.com.tw/company" in row[8]]
    if not urls_to_process:
        print("沒有需要處理的 104 網址。")
        return

    print("正在啟動瀏覽器背景作業，請稍候...")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for i, row in enumerate(rows):
            source_url = row[8]
            existing_website = row[2]

            # 只要是 104 公司頁面，不論官方網站是否已填，都進行爬蟲
            if "104.com.tw/company/" in source_url:
                print(f"[{i+1}/{len(rows)}] 正在擷取 104 頁面 ({source_url}) ...")
                try:
                    # 載入頁面並等待網路閒置
                    page.goto(source_url, wait_until='networkidle', timeout=15000)
                    time.sleep(2) # 給予 Vue 一點時間渲染畫面
                    
                    new_row = row.copy()
                    
                    # 1. 抓取官方網站（僅在欄位為空時才填入，有資料則維持現狀）
                    if not existing_website.strip():
                        website_url = ""
                        try:
                            # 搜尋「公司網址」標籤旁的連結
                            target_link = page.locator('div:has-text("公司網址") + div a').first
                            if target_link.count() > 0:
                                website_url = target_link.get_attribute("href")
                        except Exception as e:
                            print(f"    找尋網址時發生錯誤：{e}")

                        if website_url:
                            print(f"  -> ✅ 找到官方網站：{website_url}")
                            new_row[2] = website_url
                        else:
                            print("  -> 💔 未在 104 頁面上明確標示「公司網址」，保持空白。")
                    else:
                        print(f"  -> 🔒 官方網站已有資料，維持現狀：{existing_website}")
                        
                    # 2. 抓取公司品牌簡稱（僅在欄位為空時才填入）
                    if not row[0].strip():
                        try:
                            name_text = page.locator('h1').first.inner_text().strip()
                            company_name = name_text.replace('股份有限公司', '').replace('有限公司', '').replace('企業', '').strip()
                            if company_name:
                                new_row[0] = company_name
                        except:
                            pass
                        
                    # 3. 抓取徵才職缺名稱（僅在欄位為空時才填入）
                    if not row[9].strip() or row[9].strip() == '無徵才':
                        jobs = []
                        try:
                            # 針對 104 新版頁面的職缺標題選擇器
                            job_elements = page.locator('.job-list__title, .job-name').all()
                            for elem in job_elements[:5]:
                                title = elem.inner_text().strip()
                                if title and title not in jobs:
                                    jobs.append(title)
                        except:
                            pass
                            
                        if jobs:
                            new_row[9] = "、".join(jobs)
                        
                    # 4. 抓取公司說明介紹（僅在欄位為空或「無」時才填入）
                    if not row[10].strip() or row[10].strip() == '無':
                        try:
                            # 優先抓取「公司介紹」下的文字
                            desc_elem = page.locator('.profile__desc, .company-description').first
                            if desc_elem.count() > 0:
                                intro = desc_elem.inner_text().strip()
                                intro = intro.replace('\n', ' ')
                                if len(intro) > 100:
                                    intro = intro[:97] + "..."
                                if intro:
                                    new_row[10] = intro
                                    print(f"  -> 📝 已填寫說明：{intro[:30]}...")
                            else:
                                print("  -> 💔 未找到公司說明欄位。")
                        except:
                            pass
                    else:
                        print(f"  -> 🔒 說明已有資料，維持現狀。")
                        
                    new_rows.append(new_row)
                    
                except Exception as e:
                    print(f"  -> 發生錯誤 (可能為逾時): {e}")
                    new_rows.append(row)
            else:
                new_rows.append(row)

        browser.close()

    if new_rows != rows:
        with open(input_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(header)
            writer.writerows(new_rows)
        print(f"\n✅ 104 資料爬取完成！已更新 {input_file} 檔案。")
    else:
        print("\n任務結束，資料庫無任何更動。")

if __name__ == '__main__':
    run()
