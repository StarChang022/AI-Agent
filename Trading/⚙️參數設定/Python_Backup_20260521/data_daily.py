import subprocess
import sys
import os
import time
import gspread
import urllib.parse

# 關注名單 Google Sheet（股票清單來源）
WATCHLIST_URL   = 'https://docs.google.com/spreadsheets/d/1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE/edit?gid=1951214900#gid=1951214900'
CREDENTIAL_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json'
EXCLUDE_IDS     = {"TAIEX", "TPEx"}

def _parse_gsheet_url(url: str):
    parsed = urllib.parse.urlparse(url)
    qs = urllib.parse.parse_qs(parsed.query)
    gid = qs.get('gid', [None])[0]
    if gid is None and parsed.fragment and parsed.fragment.startswith('gid='):
        gid = parsed.fragment.split('=')[1]
    doc_id = parsed.path.split('/')[3]
    return doc_id, gid

def run_script(script_name, description):
    """
    執行指定的 Python 腳本並輸出結果。
    """
    # 獲取目前檔案所在的目錄
    base_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(base_dir, script_name)
    
    print("=" * 50)
    print(f"🚀 正在啟動: {description} ({script_name})")
    print(f"⏰ 開始時間: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 50)
    
    try:
        # 使用目前的 Python 解譯器執行
        result = subprocess.run([sys.executable, script_path], check=True)
        print("-" * 50)
        print(f"✅ {description} 執行成功！")
    except subprocess.CalledProcessError as e:
        print("-" * 50)
        print(f"❌ {description} 執行失敗。錯誤代碼: {e.returncode}")
        # 如果需要可以在失敗時中斷
        # sys.exit(1)
    except FileNotFoundError:
        print("-" * 50)
        print(f"❌ 找不到檔案: {script_path}")
    
    print(f"⏰ 結束時間: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

def main():
    start_all = time.time()
    
    print("🌟🌟🌟  開始執行每日數據更新程序  🌟🌟🌟")
    
    # 讀取關注名單確認哪些腳本需要執行
    try:
        gc = gspread.service_account(filename=CREDENTIAL_PATH)
        wl_doc_id, wl_gid = _parse_gsheet_url(WATCHLIST_URL)
        wl_sh = gc.open_by_key(wl_doc_id)
        wl_ws = wl_sh.get_worksheet_by_id(int(wl_gid)) if wl_gid else wl_sh.sheet1
        wl_values = wl_ws.get_all_values()
    except Exception as e:
        print(f"❌ 無法讀取關注名單 Google Sheet: {e}")
        print("將直接嘗試運行所有腳本。")
        wl_values = []

    # 解析啟用狀態
    run_stocks = False
    run_taiex = False
    run_tpex = False

    if wl_values and len(wl_values) >= 2:
        wl_headers = wl_values[0]
        sid_col = wl_headers.index('stock_id') if 'stock_id' in wl_headers else 0
        daily_col = wl_headers.index('daily') if 'daily' in wl_headers else 5

        for row in wl_values[1:]:
            stock_id = row[sid_col].strip() if len(row) > sid_col else ""
            is_enabled = len(row) > daily_col and row[daily_col].strip().upper() == 'TRUE'
            if is_enabled:
                if stock_id == "TAIEX":
                    run_taiex = True
                elif stock_id == "TPEx":
                    run_tpex = True
                elif stock_id and stock_id not in EXCLUDE_IDS:
                    run_stocks = True
    else:
        # 如果無法讀取，預設為全部運行，由子腳本自行判斷
        run_stocks = True
        run_taiex = True
        run_tpex = True

    # 定義要執行的腳本及其描述
    scripts_to_run = []
    if run_stocks:
        scripts_to_run.append(("data_daily_Stocks.py", "個股交易資訊"))
    else:
        print("💡 個股交易資訊 (data_daily_Stocks.py) 已在關注名單中被停用（沒有啟用的個股），跳過。")

    if run_taiex:
        scripts_to_run.append(("data_daily_TAIEX.py", "加權指數交易資訊 (TAIEX)"))
    else:
        print("💡 加權指數交易資訊 (data_daily_TAIEX.py) 已在關注名單中被停用，跳過。")

    if run_tpex:
        scripts_to_run.append(("data_daily_TPEx.py", "櫃買指數交易資訊 (TPEx)"))
    else:
        print("💡 櫃買指數交易資訊 (data_daily_TPEx.py) 已在關注名單中被停用，跳過。")
    
    for script, desc in scripts_to_run:
        run_script(script, desc)
        
    duration = time.time() - start_all
    print("=" * 50)
    print(f"🎉 所有更新任務已完成！")
    print(f"⏱️ 總耗時: {duration:.2f} 秒")
    print("=" * 50 + "\n")

if __name__ == "__main__":
    main()
