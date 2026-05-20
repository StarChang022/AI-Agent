"""
更新每月營收資料
- 從 FinMind API 取得每支股票的每月營收
- 先暫存至本地 Trading/暫存/for_python/
- 再批次覆寫至各股票對應的 Google Sheet（月營收分頁）
"""

import asyncio
import aiohttp
import json
import csv
import os
import re
import math
from datetime import datetime, date
from pathlib import Path

import gspread
from google.oauth2.service_account import Credentials


# ─────────────────────────────────────────────
# 路徑設定
# ─────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]          # Trading/
CACHE_DIR  = BASE_DIR / "暫存" / "for_python"
STOCKS_CSV = BASE_DIR / "⚙️參數設定" / "Stocks.csv"
GCP_JSON   = BASE_DIR / "⚙️參數設定" / "rosy-zoo-447904-j1-a600c9e990ca.json"

CACHE_DIR.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────
# Google Sheets 授權
# ─────────────────────────────────────────────
SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

def get_gspread_client():
    creds = Credentials.from_service_account_file(str(GCP_JSON), scopes=SCOPES)
    return gspread.authorize(creds)

# ─────────────────────────────────────────────
# 讀取 stocks.csv
# ─────────────────────────────────────────────
def load_stocks() -> list[dict]:
    """
    讀取 Stocks.csv，僅回傳個股（排除 TAIEX、TPEx 等指數），
    且 google_sheet_monthly 欄位必須是有效的 Google Sheet URL。
    """
    # 排除的指數型 stock_id
    EXCLUDED_IDS = {"TAIEX", "TPEx"}

    stocks = []
    with open(STOCKS_CSV, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sid = row.get("stock_id", "").strip()
            monthly_url = row.get("google_sheet_monthly", "").strip()
            # 排除指數、排除無效 URL（例如 'xxx'）
            if (
                sid
                and sid not in EXCLUDED_IDS
                and monthly_url.startswith("https://")
            ):
                stocks.append(row)
    return stocks

# ─────────────────────────────────────────────
# 解析 Google Sheet URL → spreadsheet_id, gid
# ─────────────────────────────────────────────
def parse_sheet_url(url: str) -> tuple[str, str]:
    """回傳 (spreadsheet_id, gid)"""
    m_id  = re.search(r"/spreadsheets/d/([a-zA-Z0-9_-]+)", url)
    m_gid = re.search(r"gid=(\d+)", url)
    if not m_id or not m_gid:
        raise ValueError(f"無法解析 Google Sheet URL: {url}")
    return m_id.group(1), m_gid.group(1)

# ─────────────────────────────────────────────
# 取得 Google Sheet 最新日期（用於增量更新）
# ─────────────────────────────────────────────
def get_latest_date_from_sheet(worksheet) -> str:
    """
    讀取 A 欄第 2 列開始，找最新日期（排序最上面）。
    若無資料回傳 '2020-01-01'。
    """
    try:
        col_a = worksheet.col_values(1)   # A 欄全部值
        dates = [v.strip().replace("/", "-") for v in col_a[1:] if v.strip()]  # 跳過標題，並將 / 轉為 -
        if not dates:
            return "2020-01-01"
        # 格式為 YYYY-MM-DD，直接字串排序即可
        dates.sort(reverse=True)
        return dates[0]
    except Exception:
        return "2020-01-01"

# ─────────────────────────────────────────────
# 從 FinMind 非同步抓取月營收
# ─────────────────────────────────────────────
FINMIND_URL = (
    "https://api.finmindtrade.com/api/v4/data"
    "?dataset=TaiwanStockMonthRevenue"
    "&data_id={stock_id}"
    "&start_date={start_date}"
)

async def fetch_revenue(session: aiohttp.ClientSession, stock_id: str, start_date: str) -> list[dict]:
    url = FINMIND_URL.format(stock_id=stock_id, start_date=start_date)
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
        resp.raise_for_status()
        data = await resp.json()
    records = data.get("data", [])
    return records

# ─────────────────────────────────────────────
# 本地暫存（JSON）
# ─────────────────────────────────────────────
def save_cache(stock_id: str, new_records: list[dict]):
    """讀取現有快取，合併新資料並去重，最後存回"""
    path = CACHE_DIR / f"monthly_{stock_id}.json"
    existing = []
    if path.exists():
        try:
            with open(path, encoding="utf-8") as f:
                existing = json.load(f)
        except Exception:
            existing = []

    # 合併並以 date 為 key 去重
    combined_dict = {r["date"]: r for r in existing}
    for r in new_records:
        combined_dict[r["date"]] = r

    combined_list = list(combined_dict.values())
    
    with open(path, "w", encoding="utf-8") as f:
        json.dump(combined_list, f, ensure_ascii=False, indent=2)

def load_cache(stock_id: str) -> list[dict]:
    path = CACHE_DIR / f"monthly_{stock_id}.json"
    if path.exists():
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return []

# ─────────────────────────────────────────────
# 格式化：營收億（千分位 + 2 位小數）
# ─────────────────────────────────────────────
def fmt_revenue(raw: float) -> str:
    val = raw / 1e8
    # 四捨五入到 2 位小數，並加千分位
    val_rounded = round(val, 2)
    parts = f"{val_rounded:,.2f}"
    return parts

# ─────────────────────────────────────────────
# 產生 Google Sheet 公式（隨列號動態替換）
# ─────────────────────────────────────────────
def formula_e(row: int) -> str:
    """月增率%（D欄與下一列D欄比較）"""
    return (
        f'=IF(COUNTA($D{row}) = 0, "", '
        f'IF(OR(NOT(ISNUMBER($D{row+1})), $D{row+1} = 0), "-", '
        f'($D{row} - $D{row+1}) / $D{row+1}))'
    )

def formula_f(row: int) -> str:
    """年增率%（D欄與往後第12列D欄比較）"""
    return (
        f'=IF(COUNTA($D{row}) = 0, "", '
        f'IF(OR(NOT(ISNUMBER($D{row+12})), $D{row+12} = 0), "-", '
        f'($D{row} - $D{row+12}) / $D{row+12}))'
    )

# ─────────────────────────────────────────────
# 將資料覆寫至 Google Sheet
# ─────────────────────────────────────────────
def write_to_sheet(worksheet, records: list[dict]):
    """
    records: FinMind API 回傳的 list，每筆含 date / revenue / revenue_month / revenue_year
    排序：年份大→小，月份大→小（最新在最上方）
    從第 2 列開始寫入，不覆蓋第 1 列標題。
    """
    if not records:
        print("    ⚠ 無資料可寫入")
        return

    # 排序：年份降冪，月份降冪
    records_sorted = sorted(
        records,
        key=lambda r: (int(r["revenue_year"]), int(r["revenue_month"])),
        reverse=True
    )

    rows = []
    for i, r in enumerate(records_sorted):
        sheet_row = i + 2  # 從第 2 列開始
        revenue_str = fmt_revenue(float(r["revenue"]))
        row = [
            r["date"].replace("-", "/"),    # A: 代表日期 (格式改為 YYYY/MM/DD)
            int(r["revenue_year"]),          # B: 年份
            int(r["revenue_month"]),         # C: 月份
            revenue_str,                     # D: 營收億
            formula_e(sheet_row),            # E: 月增率%
            formula_f(sheet_row),            # F: 年增率%
        ]
        rows.append(row)

    # 清除舊資料（第 2 列以後）
    last_col = "F"
    clear_range = f"A2:{last_col}{len(rows) + 1 + 50}"  # 多清幾行確保舊資料清除
    worksheet.batch_clear([clear_range])

    # 批次寫入（value_input_option=USER_ENTERED 讓公式生效）
    worksheet.update(range_name="A2", values=rows, value_input_option="USER_ENTERED")
    print(f"    ✅ 寫入 {len(rows)} 筆資料")

# ─────────────────────────────────────────────
# 主流程：非同步抓取所有股票資料
# ─────────────────────────────────────────────
async def fetch_all(stocks: list[dict], gc) -> dict[str, list[dict]]:
    """
    並行從 FinMind 抓取所有股票的月營收。
    優先從本地快取讀取最新日期決定起始日，避免觸發 Google Sheets API 流量限制（Quota Exceeded）。
    回傳 {stock_id: records}
    """
    results = {}

    # 預先取得各股票最新日期，優先使用本地快取以防 Quota 限制
    start_dates = {}
    for stock in stocks:
        stock_id = stock["stock_id"]
        
        # 讀取本地快取以獲取最新日期
        cache_latest = "2020-01-01"
        cache_records = load_cache(stock_id)
        if cache_records:
            dates = [r["date"] for r in cache_records if r.get("date")]
            if dates:
                dates.sort(reverse=True)
                cache_latest = dates[0]
                
        start_dates[stock_id] = cache_latest
        print(f"  [{stock_id}] 起始日期 (本地快取): {cache_latest}")

    # 並行從 FinMind 抓取
    connector = aiohttp.TCPConnector(limit=10)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = {
            stock["stock_id"]: fetch_revenue(session, stock["stock_id"], start_dates[stock["stock_id"]])
            for stock in stocks
        }
        coros = list(tasks.values())
        ids   = list(tasks.keys())
        fetched = await asyncio.gather(*coros, return_exceptions=True)

    for stock_id, result in zip(ids, fetched):
        if isinstance(result, Exception):
            print(f"  [{stock_id}] ⚠ 抓取失敗: {result}")
            results[stock_id] = []
        else:
            print(f"  [{stock_id}] 抓取 {len(result)} 筆")
            # 這裡存快取時，會與舊快取合併
            save_cache(stock_id, result)
            # 回傳的是「完整的快取」內容，以便後續寫入 Google Sheet
            results[stock_id] = load_cache(stock_id)

    return results

# ─────────────────────────────────────────────
# 主程式
# ─────────────────────────────────────────────
def main():
    print("=" * 50)
    print(f"🚀 開始更新每月營收  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)

    stocks = load_stocks()
    print(f"\n📋 共 {len(stocks)} 支股票待處理\n")

    # Google Sheets 授權
    gc = get_gspread_client()

    # ── Step 1：並行抓取所有資料並暫存 ──
    print("── Step 1：從 FinMind 抓取資料 ──")
    all_records = asyncio.run(fetch_all(stocks, gc))

    # ── Step 2：批次寫入 Google Sheet ──
    print("\n── Step 2：寫入 Google Sheet ──")
    for stock in stocks:
        stock_id   = stock["stock_id"]
        stock_name = stock["stock_name"]
        url        = stock["google_sheet_monthly"]
        records    = all_records.get(stock_id, [])

        print(f"\n  [{stock_id}] {stock_name}")

        if not records:
            # 若本次抓取失敗，嘗試從快取讀取
            records = load_cache(stock_id)
            if records:
                print(f"    ⚠ 使用本地快取（{len(records)} 筆）")
            else:
                print(f"    ⛔ 無資料可寫入，略過")
                continue

        try:
            ss_id, gid = parse_sheet_url(url)
            ss = gc.open_by_key(ss_id)
            ws = ss.get_worksheet_by_id(int(gid))
            write_to_sheet(ws, records)
        except Exception as e:
            print(f"    ⛔ 寫入失敗: {e}")

    print("\n" + "=" * 50)
    print(f"✅ 全部完成  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)


if __name__ == "__main__":
    main()
