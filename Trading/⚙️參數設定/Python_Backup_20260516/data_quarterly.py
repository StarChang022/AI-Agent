"""
更新每季財報資料 (data_quarterly.py)
────────────────────────────────────────────────────
功能：
  1. 從 Stocks.csv 讀取非指數個股（排除 TAIEX / TPEx），
     且 google_sheet_quarterly 欄位必須是有效的 Google Sheet URL。
  2. 並行從 FinMind API 抓取四張表（資產負債表、損益表、
     現金流量表、股利政策），全程非同步高效。
  3. 將原始資料暫存於 Trading/⌚️暫存/for_python/quarterly_{stock_id}.json。
  4. 批次覆寫至各股票對應的 Google Sheet（季報分頁）：
       - 欄 A：項目名稱（不覆蓋）
       - 欄 B 起：每季數據，由左至右由新到舊
       - 可計算列填入 Google Sheets 公式（ROE、毛利率等）
────────────────────────────────────────────────────
直接執行：python data_quarterly.py
"""

import asyncio
import aiohttp
import json
import csv
import re
import math
from datetime import datetime, date
from pathlib import Path
from typing import Optional
from string import ascii_uppercase
from itertools import product

import gspread
from google.oauth2.service_account import Credentials


# ═══════════════════════════════════════════════════
# 路徑設定
# ═══════════════════════════════════════════════════
BASE_DIR   = Path(__file__).resolve().parents[2]          # Trading/
CACHE_DIR  = BASE_DIR / "⌚️暫存" / "for_python"
STOCKS_CSV = BASE_DIR / "⚙️參數設定" / "Stocks.csv"
GCP_JSON   = BASE_DIR / "⚙️參數設定" / "rosy-zoo-447904-j1-a600c9e990ca.json"

CACHE_DIR.mkdir(parents=True, exist_ok=True)


# ═══════════════════════════════════════════════════
# Google Sheets 授權
# ═══════════════════════════════════════════════════
SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

def get_gspread_client():
    creds = Credentials.from_service_account_file(str(GCP_JSON), scopes=SCOPES)
    return gspread.authorize(creds)


# ═══════════════════════════════════════════════════
# 欄號轉換工具（1-based → A、B、…、Z、AA、AB…）
# ═══════════════════════════════════════════════════
def col_letter(n: int) -> str:
    """將整數欄號（1-based）轉換為 A1 表示法欄名"""
    result = ""
    while n > 0:
        n, rem = divmod(n - 1, 26)
        result = chr(65 + rem) + result
    return result


# ═══════════════════════════════════════════════════
# 讀取 Stocks.csv
# ═══════════════════════════════════════════════════
EXCLUDED_IDS = {"TAIEX", "TPEx"}

def load_stocks() -> list[dict]:
    """
    讀取 Stocks.csv，僅回傳個股（排除 TAIEX / TPEx），
    且 google_sheet_quarterly 欄位必須是有效的 Google Sheet URL。
    """
    stocks = []
    with open(STOCKS_CSV, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sid = row.get("stock_id", "").strip()
            q_url = row.get("google_sheet_quarterly", "").strip()
            if (
                sid
                and sid not in EXCLUDED_IDS
                and q_url.startswith("https://")
            ):
                stocks.append(row)
    return stocks


# ═══════════════════════════════════════════════════
# 解析 Google Sheet URL → (spreadsheet_id, gid)
# ═══════════════════════════════════════════════════
def parse_sheet_url(url: str) -> tuple[str, str]:
    m_id  = re.search(r"/spreadsheets/d/([a-zA-Z0-9_-]+)", url)
    m_gid = re.search(r"gid=(\d+)", url)
    if not m_id or not m_gid:
        raise ValueError(f"無法解析 Google Sheet URL: {url}")
    return m_id.group(1), m_gid.group(1)


# ═══════════════════════════════════════════════════
# 取得 Google Sheet 最新季度（B1 儲存格）
# ═══════════════════════════════════════════════════
def get_latest_quarter_from_sheet(worksheet) -> str:
    """
    讀取 B1（第 1 列第 2 欄），即最新季度日期。
    若無資料，回傳 '2020-01-01'。
    """
    try:
        val = worksheet.cell(1, 2).value
        if val and str(val).strip():
            return str(val).strip()
        return "2020-01-01"
    except Exception:
        return "2020-01-01"


# ═══════════════════════════════════════════════════
# FinMind API 端點定義
# ═══════════════════════════════════════════════════
FINMIND_BASE = "https://api.finmindtrade.com/api/v4/data"

APIS = {
    "balance_sheet": {
        "dataset": "TaiwanStockBalanceSheet",
        "fields": [
            "CashAndCashEquivalents",
            "AccountsReceivableNet",
            "Inventories",
            "CurrentAssets",
            "PropertyPlantAndEquipment",
            "NoncurrentAssets",
            "TotalAssets",
            "AccountsPayable",
            "CurrentLiabilities",
            "LongtermBorrowings",
            "BondsPayable",
            "NoncurrentLiabilities",
            "Liabilities",
            "RetainedEarnings",
            "Equity",
        ],
    },
    "income_statement": {
        "dataset": "TaiwanStockFinancialStatements",
        "fields": [
            "Revenue",
            "GrossProfit",
            "OperatingIncome",
            "PreTaxIncome",
            "IncomeAfterTaxes",
            "TotalNonoperatingIncomeAndExpense",
            "EPS",
        ],
    },
    "cash_flow": {
        "dataset": "TaiwanStockCashFlowsStatement",
        "fields": [
            "Depreciation",
            "AmortizationExpense",
            "PropertyAndPlantAndEquipment",
            "ProceedsFromLongTermDebt",
            "RepaymentOfLongTermDebt",
            "RedemptionOfBonds",
            "CashFlowsFromOperatingActivities",
            "CashProvidedByInvestingActivities",
            "CashFlowsProvidedFromFinancingActivities",
        ],
    },
    "dividend": {
        "dataset": "TaiwanStockDividend",
        "fields": [
            "CashEarningsDistribution",
            "StockEarningsDistribution",
            "CashDividendPaymentDate",
            "StockExDividendTradingDate",
        ],
    },
}


# ═══════════════════════════════════════════════════
# 非同步抓取單一 API
# ═══════════════════════════════════════════════════
async def fetch_api(
    session: aiohttp.ClientSession,
    dataset: str,
    stock_id: str,
    start_date: str,
) -> list[dict]:
    params = {
        "dataset": dataset,
        "data_id": stock_id,
        "start_date": start_date,
    }
    async with session.get(
        FINMIND_BASE,
        params=params,
        timeout=aiohttp.ClientTimeout(total=60),
    ) as resp:
        resp.raise_for_status()
        data = await resp.json()
    return data.get("data", [])


# ═══════════════════════════════════════════════════
# 並行抓取單支股票的所有 API
# ═══════════════════════════════════════════════════
async def fetch_stock_all_apis(
    session: aiohttp.ClientSession,
    stock_id: str,
    start_date: str,
) -> dict[str, list[dict]]:
    """
    並行呼叫 4 個 FinMind API，回傳各 API 的原始 records。
    {api_key: [records]}
    """
    tasks = {
        key: fetch_api(session, info["dataset"], stock_id, start_date)
        for key, info in APIS.items()
    }
    results = await asyncio.gather(*tasks.values(), return_exceptions=True)
    return {key: ([] if isinstance(r, Exception) else r)
            for key, r in zip(tasks.keys(), results)}


# ═══════════════════════════════════════════════════
# 資料整理：將各 API records 轉換為 {date: {field: value}}
# ═══════════════════════════════════════════════════
def parse_records(api_data: dict[str, list[dict]]) -> dict[str, dict[str, any]]:
    """
    將各 API 的 records（每筆 {date, type, value}）整合成：
    { "2024-Q3": { "CashAndCashEquivalents": 12345, "EPS": 5.6, ... } }

    日期格式：
    - 資產負債表、損益表、現金流量表：date 欄通常是 YYYY-MM-DD（季末），
      轉為 YYYY-Qn 標籤
    - 股利政策：date 欄是年度（YYYY），用另一種 key 儲存
    """
    merged: dict[str, dict[str, any]] = {}

    def to_quarter_key(date_str: str) -> str:
        """YYYY-MM-DD → YYYY-Qn"""
        try:
            d = datetime.strptime(date_str[:10], "%Y-%m-%d")
            q = math.ceil(d.month / 3)
            return f"{d.year}-Q{q}"
        except ValueError:
            return date_str[:10]

    # ── 資產負債表、損益表、現金流量表 ──
    for api_key in ("balance_sheet", "income_statement", "cash_flow"):
        records = api_data.get(api_key, [])
        for r in records:
            q_key = to_quarter_key(r.get("date", ""))
            field = r.get("type", "")
            value = r.get("value", None)
            if not q_key or not field:
                continue
            if q_key not in merged:
                merged[q_key] = {"_date_raw": r.get("date", "")[:10]}
            merged[q_key][field] = value

    # ── 股利政策（date 是年度 YYYY，轉為 YYYY-Q4 對齊）──
    div_records = api_data.get("dividend", [])
    for r in div_records:
        year_str = r.get("date", "")[:4]
        q_key = f"{year_str}-Q4"  # 股利通常與年報（Q4）對齊
        if q_key not in merged:
            merged[q_key] = {"_date_raw": f"{year_str}-12-31"}

        for field in APIS["dividend"]["fields"]:
            if field in r:
                # 若已存在不覆蓋（以最後一筆為主）
                merged[q_key][field] = r[field]

    return merged


# ═══════════════════════════════════════════════════
# 本地暫存（JSON）
# ═══════════════════════════════════════════════════
def save_cache(stock_id: str, quarter_data: dict[str, dict]):
    """將 {quarter_key: {field: value}} 合併寫入快取"""
    path = CACHE_DIR / f"quarterly_{stock_id}.json"
    existing: dict[str, dict] = {}
    if path.exists():
        try:
            with open(path, encoding="utf-8") as f:
                existing = json.load(f)
        except Exception:
            existing = {}

    # 新資料覆蓋舊資料（以 quarter_key 為鍵）
    existing.update(quarter_data)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)


def load_cache(stock_id: str) -> dict[str, dict]:
    path = CACHE_DIR / f"quarterly_{stock_id}.json"
    if path.exists():
        try:
            with open(path, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


# ═══════════════════════════════════════════════════
# Google Sheets 公式（以欄號產生動態公式）
# ═══════════════════════════════════════════════════
def make_formulas(col: int) -> dict[int, str]:
    """
    依照指定欄號（1-based）產生各列的 Google Sheets 公式。
    對應關係（列號對欄位）請見命令文件 # Google Sheet 公式。

    回傳 {row: formula_string}
    欄 B = col_letter(2)，以此類推。
    """
    c  = col_letter(col)       # 此欄
    nc = col_letter(col + 1)   # 右邊一欄（用於 ROE 計算）

    formulas = {
        # 第4列：ROE = 稅後淨利(row32) / ((本期權益(row26) + 上期權益(nc26)) / 2)
        4:  f"=IF(ISNUMBER({nc}26), {c}32 / (({c}26 + {nc}26) / 2), \"-\")",
        # 第5列：毛利率 = 毛利(row29) / 營收(row28)
        5:  f"={c}29/{c}28",
        # 第6列：營業利益率 = 營業利益(row30) / 營收(row28)
        6:  f"={c}30/{c}28",
        # 第7列：稅後淨利率 = 稅後淨利(row32) / 營收(row28)
        7:  f"={c}32/{c}28",
        # 第8列：負債率 = 負債總額(row23) / 資產總額(row16)
        8:  f"={c}23/{c}16",
    }
    return formulas


# ═══════════════════════════════════════════════════
# Google Sheet 列號對欄位名稱的對應
# ═══════════════════════════════════════════════════
# row → field_name（或 None 表示公式列）
ROW_TO_FIELD: dict[int, Optional[str]] = {
    1:  "date",                               # 季度（特殊處理）
    3:  "EPS",
    4:  None,                                 # ROE 公式
    5:  None,                                 # 毛利率 公式
    6:  None,                                 # 營業利益率 公式
    7:  None,                                 # 稅後淨利率 公式
    8:  None,                                 # 負債率 公式
    10: "CashAndCashEquivalents",
    11: "AccountsReceivableNet",
    12: "Inventories",
    13: "CurrentAssets",
    14: "PropertyPlantAndEquipment",
    15: "NoncurrentAssets",
    16: "TotalAssets",
    18: "AccountsPayable",
    19: "CurrentLiabilities",
    20: "LongtermBorrowings",
    21: "BondsPayable",
    22: "NoncurrentLiabilities",
    23: "Liabilities",
    25: "RetainedEarnings",
    26: "Equity",
    28: "Revenue",
    29: "GrossProfit",
    30: "OperatingIncome",
    31: "PreTaxIncome",
    32: "IncomeAfterTaxes",
    33: "TotalNonoperatingIncomeAndExpense",
    35: "Depreciation",
    36: "AmortizationExpense",
    37: "PropertyAndPlantAndEquipment",
    38: "ProceedsFromLongTermDebt",
    39: "RepaymentOfLongTermDebt",
    40: "RedemptionOfBonds",
    41: "CashFlowsFromOperatingActivities",
    42: "CashProvidedByInvestingActivities",
    43: "CashFlowsProvidedFromFinancingActivities",
    45: "CashEarningsDistribution",
    46: "StockEarningsDistribution",
    47: "CashDividendPaymentDate",
    48: "StockExDividendTradingDate",
}

MAX_ROW = 48  # 最大列號


# ═══════════════════════════════════════════════════
# 將資料覆寫至 Google Sheet
# ═══════════════════════════════════════════════════
def write_to_sheet(worksheet, quarter_data: dict[str, dict]):
    """
    quarter_data: { "2024-Q3": {field: value, ...}, ... }
    欄位排列：B 欄起，由左至右由新到舊（最新在 B 欄）。
    """
    if not quarter_data:
        print("    ⚠ 無資料可寫入")
        return

    # 依季度排序（新 → 舊）
    sorted_quarters = sorted(quarter_data.keys(), reverse=True)
    n_cols = len(sorted_quarters)

    # 每欄的欄號（從 2 = B 開始）
    start_col = 2

    # ── 準備 batch_update 的 cells list ──
    updates = []

    # 找出所有需要寫入的列號（來自 ROW_TO_FIELD）
    all_rows = sorted(ROW_TO_FIELD.keys())

    for col_offset, q_key in enumerate(sorted_quarters):
        col_num = start_col + col_offset           # 1-based
        q_dict  = quarter_data[q_key]

        # 產生此欄的公式
        formulas = make_formulas(col_num)

        for row in all_rows:
            field = ROW_TO_FIELD[row]

            if row in formulas:
                # 公式列
                value = formulas[row]
            elif field == "date":
                # 第1列：季度標籤
                value = q_key
            elif field is not None:
                raw = q_dict.get(field)
                if raw is None:
                    value = ""
                else:
                    value = raw
            else:
                value = ""

            updates.append({
                "range": f"{col_letter(col_num)}{row}",
                "values": [[value]],
            })

    # ── 自動擴充工作表欄數（避免超出 grid limits）──
    needed_cols = start_col + n_cols - 1   # 最後一欄的 1-based 欄號
    current_cols = worksheet.col_count
    if needed_cols > current_cols:
        worksheet.resize(rows=worksheet.row_count, cols=needed_cols + 5)  # 多預留 5 欄
        print(f"    📐 工作表欄數擴充至 {needed_cols + 5} 欄（原 {current_cols} 欄）")

    # ── 清除舊有資料（B欄以後），避免舊季度殘留 ──
    clear_end_col = col_letter(needed_cols + 5)
    clear_range   = f"B1:{clear_end_col}{MAX_ROW}"
    worksheet.batch_clear([clear_range])
    print(f"    🧹 已清除舊資料範圍 {clear_range}")

    # ── 批次寫入 ──
    worksheet.batch_update(
        updates,
        value_input_option="USER_ENTERED",  # 讓公式和數字格式生效
    )
    print(f"    ✅ 已寫入 {n_cols} 季資料（{len(updates)} 個儲存格）")


# ═══════════════════════════════════════════════════
# Step 1：並行抓取所有股票的所有財報 API
# ═══════════════════════════════════════════════════
async def fetch_all(stocks: list[dict], gc) -> dict[str, dict[str, dict]]:
    """
    回傳 { stock_id: { quarter_key: {field: value} } }
    """
    results = {}

    # ── 預先讀取各股票 Google Sheet 最新季度（用於增量更新）──
    start_dates: dict[str, str] = {}
    for stock in stocks:
        sid   = stock["stock_id"]
        q_url = stock["google_sheet_quarterly"]
        try:
            ss_id, gid = parse_sheet_url(q_url)
            ss = gc.open_by_key(ss_id)
            ws = ss.get_worksheet_by_id(int(gid))
            latest = get_latest_quarter_from_sheet(ws)

            # 若本地快取不存在，則從 2020-01-01 重抓全部
            if not (CACHE_DIR / f"quarterly_{sid}.json").exists():
                latest = "2020-01-01"

            start_dates[sid] = latest
            print(f"  [{sid}] 起始日期: {latest}")
        except Exception as e:
            print(f"  [{sid}] 讀取 Sheet 失敗，使用預設起始日: {e}")
            start_dates[sid] = "2020-01-01"

    # ── 並行從 FinMind 抓取（每支股票同時打 4 個 API）──
    connector = aiohttp.TCPConnector(limit=20)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = {
            stock["stock_id"]: fetch_stock_all_apis(
                session, stock["stock_id"], start_dates[stock["stock_id"]]
            )
            for stock in stocks
        }
        fetched = await asyncio.gather(*tasks.values(), return_exceptions=True)

    for stock_id, result in zip(tasks.keys(), fetched):
        if isinstance(result, Exception):
            print(f"  [{stock_id}] ⚠ 抓取失敗: {result}")
            # 嘗試使用本地快取
            results[stock_id] = load_cache(stock_id)
        else:
            # 整合原始 records → {quarter_key: {field: value}}
            new_data = parse_records(result)
            print(
                f"  [{stock_id}] 抓取 {sum(len(v) for v in result.values())} 筆"
                f" → {len(new_data)} 季"
            )
            # 合併至快取（新資料覆蓋舊資料）
            save_cache(stock_id, new_data)
            # 後續寫入使用完整快取
            results[stock_id] = load_cache(stock_id)

    return results


# ═══════════════════════════════════════════════════
# 主程式
# ═══════════════════════════════════════════════════
def main():
    print("=" * 55)
    print(f"🚀 開始更新每季財報  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 55)

    stocks = load_stocks()
    if not stocks:
        print("⛔ 無符合條件的股票（請確認 Stocks.csv 中 google_sheet_quarterly 欄位）")
        return
    print(f"\n📋 共 {len(stocks)} 支股票待處理")
    for s in stocks:
        print(f"   {s['stock_id']} {s['stock_name']}")
    print()

    # Google Sheets 授權
    gc = get_gspread_client()

    # ── Step 1：並行抓取所有資料並暫存至本地 ──
    print("─" * 55)
    print("Step 1｜從 FinMind API 並行抓取財報資料")
    print("─" * 55)
    all_data = asyncio.run(fetch_all(stocks, gc))

    # ── Step 2：批次覆寫至 Google Sheet ──
    print()
    print("─" * 55)
    print("Step 2｜批次覆寫至 Google Sheet")
    print("─" * 55)

    for stock in stocks:
        sid   = stock["stock_id"]
        name  = stock["stock_name"]
        q_url = stock["google_sheet_quarterly"]
        data  = all_data.get(sid, {})

        print(f"\n  [{sid}] {name}")

        if not data:
            data = load_cache(sid)
            if data:
                print(f"    ⚠ 使用本地快取（{len(data)} 季）")
            else:
                print("    ⛔ 無資料可寫入，略過")
                continue

        try:
            ss_id, gid = parse_sheet_url(q_url)
            ss = gc.open_by_key(ss_id)
            ws = ss.get_worksheet_by_id(int(gid))
            write_to_sheet(ws, data)
        except Exception as e:
            print(f"    ⛔ 寫入失敗: {e}")

    print()
    print("=" * 55)
    print(f"✅ 全部完成  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 55)


if __name__ == "__main__":
    main()
