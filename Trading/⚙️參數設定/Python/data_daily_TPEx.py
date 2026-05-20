"""
data_daily_TPEx.py
==================
從 FinMind API 抓取「櫃買指數 (TPEx)」每日交易資訊，
並將結果覆寫至關注名單對應的 Google Sheet。

任務邏輯 (依照 櫃買指數交易資訊.md):
1. 從關注名單 Google Sheet 讀取 stock_id="TPEx" 的 google_sheet_daily 網址。
2. 檢查 Google Sheet 中最新的交易日所在月份月初，以該日期作為 FinMind API 的 start_date。
   若 Sheet 內尚無資料，則從 2020-01-01 開始抓取。
3. 呼叫 FinMind API 取得新資料，並與 Sheet 現有資料合併（去除重複日期）。
4. 依照欄位規格格式化資料，並將 Google Sheet 公式填入 H~P 欄。
5. 依日期新到舊排序，從第 2 列開始覆寫 Google Sheet（保留第 1 列標題）。
"""

import os
import urllib.parse
import aiohttp
import asyncio
import pandas as pd
import gspread
import numpy as np
from typing import Union, Optional, List, Tuple, Dict

# ──────────────────────────────────────────────
# 路徑 / 常數設定
# ──────────────────────────────────────────────
BASE_URL = "https://api.finmindtrade.com/api/v4/data"
STOCK_ID = "TPEx"

# 關注名單 Google Sheet（股票清單來源）
WATCHLIST_URL   = 'https://docs.google.com/spreadsheets/d/1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE/edit?gid=1951214900#gid=1951214900'
CREDENTIAL_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json'
TEMP_DIR        = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/for_python'


# ──────────────────────────────────────────────
# 公式產生
# ──────────────────────────────────────────────
def get_h_to_p_formulas(row_index: int) -> list:
    """
    產生第 row_index 列的 H~P 欄 Google Sheet 公式。
    H~M：收盤 ($E) 移動平均，讀取儀表板 $A$4~$A$9
    N~P：成交金額 ($G) 移動平均，讀取儀表板 $B$4~$B$6
    """
    ri = row_index

    dashboard_a_refs = ['$A$4', '$A$5', '$A$6', '$A$7', '$A$8', '$A$9']
    close_formulas = [
        f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!{ref}, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))"""
        for ref in dashboard_a_refs
    ]

    dashboard_b_refs = ['$B$4', '$B$5', '$B$6']
    money_formulas = [
        f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!{ref}, range, OFFSET($G{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($G{ri})), COUNT(range) < N), "-", AVERAGE(range))))"""
        for ref in dashboard_b_refs
    ]

    return close_formulas + money_formulas  # H~M (6), N~P (3) = 9 個公式


# ──────────────────────────────────────────────
# API 呼叫
# ──────────────────────────────────────────────
async def fetch_api(session: aiohttp.ClientSession, start_date: str) -> list:
    """向 FinMind API 發出請求，回傳 data list。"""
    url = f"{BASE_URL}?dataset=TaiwanStockPrice&data_id={STOCK_ID}&start_date={start_date}"
    print(f"  → 呼叫 FinMind API: {url}")
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return data.get('data', [])
            else:
                print(f"  ✗ 無法取得資料，狀態碼：{response.status}")
                return []
    except Exception as e:
        print(f"  ✗ 發生例外：{e}")
        return []


# ──────────────────────────────────────────────
# Google Sheet 工具
# ──────────────────────────────────────────────
def parse_google_sheet_url(url: str) -> Tuple[str, Optional[str]]:
    """從 Google Sheet URL 解析出 doc_id 與 gid。"""
    parsed = urllib.parse.urlparse(url)
    qs = urllib.parse.parse_qs(parsed.query)
    gid = qs.get('gid', [None])[0]
    if gid is None and parsed.fragment and parsed.fragment.startswith('gid='):
        gid = parsed.fragment.split('=')[1]
    doc_id = parsed.path.split('/')[3]
    return doc_id, gid


def get_start_date(worksheet) -> tuple[str, pd.DataFrame]:
    """
    讀取 Google Sheet 現有資料，回傳 (start_date, df_old)。
    start_date：最新日期所在月份月初 (YYYY-MM-DD)，若無資料則為 '2020-01-01'。
    df_old：現有資料 DataFrame（欄位為原始中文欄名）。
    """
    try:
        all_values = worksheet.get_all_values()
        if len(all_values) > 1:
            df_old = pd.DataFrame(all_values[1:], columns=all_values[0])
            dates = pd.to_datetime(df_old.iloc[:, 0], errors='coerce')
            if not dates.isna().all():
                max_date = dates.max()
                start = max_date.replace(day=1).strftime('%Y-%m-%d')
                print(f"  Google Sheet 最新日期：{max_date.strftime('%Y-%m-%d')}，從 {start} 重新抓取")
                return start, df_old
        # 有資料但無法解析日期，或只有標題列
        return '2020-01-01', pd.DataFrame()
    except Exception as e:
        print(f"  ✗ 讀取 Google Sheet 失敗：{e}")
    return '2020-01-01', pd.DataFrame()


# ──────────────────────────────────────────────
# 資料整合
# ──────────────────────────────────────────────
def build_new_df(raw_data: list) -> pd.DataFrame:
    """
    將 FinMind 原始資料整合成 DataFrame，欄位對應 A~G 欄。
    - 成交金額除以 1 億，四捨五入為整數
    """
    if not raw_data:
        return pd.DataFrame()

    df = pd.DataFrame(raw_data)

    # 指數的成交金額欄位可能是 Trading_money 或 Trading_Amount
    money_col = 'Trading_money' if 'Trading_money' in df.columns else ('Trading_Amount' if 'Trading_Amount' in df.columns else None)

    if money_col:
        # 成交金額除以 1 億，四捨五入為整數
        df['Trading_money_fmt'] = (df[money_col] / 1e8).round(0).astype('Int64')
    else:
        df['Trading_money_fmt'] = 0

    # 日期格式 YYYY/MM/DD
    df['date'] = df['date'].str.replace('-', '/')

    return df[['date', 'open', 'max', 'min', 'close', 'spread', 'Trading_money_fmt']].copy()


def merge_with_old(df_new: pd.DataFrame, df_old: pd.DataFrame) -> pd.DataFrame:
    """
    合併新舊資料，以新資料優先，去除重複日期後依日期新到舊排序。
    """
    if df_old.empty:
        df = df_new
    else:
        # 舊資料欄位改名，使其與新資料一致
        col_map = {
            '交易日期': 'date', '日期': 'date', '開盤': 'open', '最高': 'max', '最低': 'min',
            '收盤': 'close', '漲跌': 'spread', '成交金額': 'Trading_money_fmt', '成交量': 'Trading_money_fmt',
        }
        df_old_int = df_old.rename(columns=col_map)
        # 強制去除重複欄位名稱（避免同時存在 '日期' 與 '交易日期' 導致衝突）
        df_old_int = df_old_int.loc[:, ~df_old_int.columns.duplicated()]

        # 確保選取的欄位清單是唯一的
        target_cols = list(set(col_map.values()))
        keep_cols = [c for c in target_cols if c in df_old_int.columns]
        df_old_int = df_old_int[keep_cols]

        # 合併前重設索引確保唯一性
        df_new = df_new.reset_index(drop=True)
        df_old_int = df_old_int.reset_index(drop=True)

        df = pd.concat([df_new, df_old_int], ignore_index=True).drop_duplicates(subset=['date'])

    # 日期排序：新 → 舊
    df['_date_dt'] = pd.to_datetime(df['date'], format='%Y/%m/%d', errors='coerce')
    df = df.sort_values('_date_dt', ascending=False).drop(columns=['_date_dt']).reset_index(drop=True)
    return df


def build_sheet_data(df: pd.DataFrame) -> list:
    """
    將整合後的 DataFrame 轉換為 Google Sheet 寫入格式（含標題列與公式）。
    數值欄位寫入真實數值（int/float），讓 Google Sheet 可正確計算。
    """
    headers = [
        '日期', '開盤', '最高', '最低', '收盤', '漲跌', '成交金額',
        "='儀表板'!$A$4&'儀表板'!$A$3",
        "='儀表板'!$A$5&'儀表板'!$A$3",
        "='儀表板'!$A$6&'儀表板'!$A$3",
        "='儀表板'!$A$7&'儀表板'!$A$3",
        "='儀表板'!$A$8&'儀表板'!$A$3",
        "='儀表板'!$A$9&'儀表板'!$A$3",
        "='儀表板'!$B$4&'儀表板'!$B$3",
        "='儀表板'!$B$5&'儀表板'!$B$3",
        "='儀表板'!$B$6&'儀表板'!$B$3",
    ]

    sheet_data = [headers]

    for i, r in df.iterrows():
        row_idx = i + 2  # 第1列為標題，資料從第2列起

        def safe(val):
            """將 NA / NaN / inf 轉為空字串，其餘保留原型別（數值型別）。"""
            if val is None:
                return ''
            try:
                if pd.isna(val):
                    return ''
            except (TypeError, ValueError):
                pass
            if isinstance(val, float) and (np.isnan(val) or np.isinf(val)):
                return ''
            if isinstance(val, (np.integer,)):
                return int(val)
            if isinstance(val, (np.floating,)):
                return float(val)
            # 嘗試將字串轉為數值（處理舊資料從 Sheet 讀回的字串格式）
            if isinstance(val, str):
                val_clean = val.replace(',', '').strip()
                try:
                    f = float(val_clean)
                    return int(f) if f == int(f) else f
                except (ValueError, OverflowError):
                    pass
            return val

        row_data = [
            r['date'],                        # A 交易日期
            safe(r['open']),                  # B 開盤
            safe(r['max']),                   # C 最高
            safe(r['min']),                   # D 最低
            safe(r['close']),                 # E 收盤
            safe(r['spread']),                # F 漲跌
            safe(r['Trading_money_fmt']),      # G 成交金額（億）
        ]

        formulas = get_h_to_p_formulas(row_idx)  # H~P（9 個公式）
        row_data.extend(formulas)
        sheet_data.append(row_data)

    return sheet_data


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────
async def main():
    print("=" * 60)
    print("  櫃買指數 (TPEx) 每日交易資訊更新")
    print("=" * 60)

    # ── 步驟1：從關注名單找 TPEx 的 google_sheet_daily ──────
    os.makedirs(TEMP_DIR, exist_ok=True)
    gc = gspread.service_account(filename=CREDENTIAL_PATH)

    wl_doc_id, wl_gid = parse_google_sheet_url(WATCHLIST_URL)
    wl_sh = gc.open_by_key(wl_doc_id)
    wl_ws = wl_sh.get_worksheet_by_id(int(wl_gid)) if wl_gid else wl_sh.sheet1

    wl_values = wl_ws.get_all_values()
    if len(wl_values) < 2:
        print("✗ 關注名單 Google Sheet 無資料，結束。")
        return

    wl_headers = wl_values[0]
    if 'stock_id' not in wl_headers or 'google_sheet_daily' not in wl_headers:
        print(f"✗ 關注名單缺少必要欄位，目前欄位：{wl_headers}")
        return

    sid_col = wl_headers.index('stock_id')
    gsd_col = wl_headers.index('google_sheet_daily')

    tpex_row = next((r for r in wl_values[1:] if r[sid_col].strip() == STOCK_ID), None)
    if tpex_row is None:
        print(f"✗ 關注名單中找不到 stock_id={STOCK_ID}，結束。")
        return

    google_sheet_url = tpex_row[gsd_col].strip()
    if not google_sheet_url.startswith('https://'):
        print(f"✗ TPEx 的 google_sheet_daily 欄位為空，請先填入 Google Sheet URL。")
        return

    print(f"▶ 關注名單找到 TPEx，寫入目標：{google_sheet_url}")

    # ── 步驟2：開啟寫入目標 Google Sheet ───────────────
    doc_id, gid = parse_google_sheet_url(google_sheet_url)
    sh = gc.open_by_key(doc_id)
    worksheet = sh.get_worksheet_by_id(int(gid)) if gid else sh.sheet1

    # ── 決定起始日期（從現有資料最新日期的月初）────────────────
    start_date, df_old = get_start_date(worksheet)
    print(f"▶ 開始抓取 TPEx 資料，起始日期：{start_date}")

    # ── 呼叫 FinMind API ──────────────────────────────────────
    async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(limit=5)) as session:
        raw_data = await fetch_api(session, start_date)

    # ── 整合新資料 ────────────────────────────────────────────
    df_new = build_new_df(raw_data)
    if df_new.empty:
        print("✗ FinMind API 未回傳任何交易資訊，結束。")
        return

    print(f"  取得新資料：{len(df_new)} 筆")

    # ── 合併新舊資料並排序 ────────────────────────────────────
    df_final = merge_with_old(df_new, df_old)
    print(f"  合併後共：{len(df_final)} 筆（含歷史資料）")

    # ── 建立 Sheet 寫入資料（含公式）────────────────────────────
    sheet_data = build_sheet_data(df_final)

    # ── 儲存暫存 CSV ──────────────────────────────────────────
    temp_csv = os.path.join(TEMP_DIR, 'TPEx_daily.csv')
    headers = sheet_data[0]
    pd.DataFrame(sheet_data[1:], columns=headers).to_csv(temp_csv, index=False, encoding='utf-8-sig')
    print(f"  暫存 CSV 已儲存：{temp_csv}")

    # ── 寫入 Google Sheet ─────────────────────────────────────
    try:
        worksheet.batch_clear(["A2:P9999"])
        if len(sheet_data) > 1:
            worksheet.update(values=sheet_data[1:], range_name="A2", value_input_option='USER_ENTERED')

            # B~F：千分位 + 小數點後2位（指數數值）
            worksheet.format("B2:F9999", {
                "numberFormat": {"type": "NUMBER", "pattern": "#,##0.00"}
            })
            # G：千分位整數（成交金額，億）
            worksheet.format("G2:G9999", {
                "numberFormat": {"type": "NUMBER", "pattern": "#,##0"}
            })

        print(f"✔ TPEx 更新完成，共寫入 {len(sheet_data) - 1} 筆資料。")
    except Exception as e:
        print(f"✗ 寫入 Google Sheet 失敗：{e}")


if __name__ == "__main__":
    asyncio.run(main())
