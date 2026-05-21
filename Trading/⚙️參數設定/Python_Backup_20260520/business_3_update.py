"""
business_2_update.py
═══════════════════════════════════════════════════════════════════
收集個股情報 Step 3：將 business_database.json 資料回寫至 Google Sheet

這支腳本在 AI Agent 執行「收集個股情報_2_分析整理.md」完成後執行：
  Step 1  business_1_crawler.py   → 爬蟲收集 → business_database.json
  Step 2  AI Agent（分析整理）     → 分析整理 → 更新 business_database.json
  Step 3  business_2_update.py    ← 本腳本：讀 JSON → 覆寫 Google Sheet B2:B10

流程：
  1. 讀取 business_database.json（本地，無需額外 API）
  2. 從關注名單 Google Sheet 讀取股票清單（僅 1 次 API 呼叫）
     - 跳過 TAIEX、TPEx
     - 跳過 google_sheet_business == "xxx" 的股票
  3. 分批（每批 BATCH_SIZE 支）批次寫入各股票的 Google Sheet 情報分頁
     - 完全覆寫 B2:B10
     - 同一試算表若有多支股票，只開啟一次（最小化 API 次數）

Google Sheet 欄位對應（情報分頁）：
  A 欄 = 欄位標籤（由本腳本寫入或保持既有）
  B2  = 報告日期
  B3  = 產品營收佔比
  B4  = 客戶與區域營收佔比
  B5  = 企業營運概況與基本介紹
  B6  = 主力產品與服務及獲利模式
  B7  = 未來展望
  B8  = 潛在風險
  B9  = 競爭對手
  B10 = 其他
═══════════════════════════════════════════════════════════════════
"""

import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import gspread
from google.oauth2.service_account import Credentials

# ──────────────────────────────────────────────────────────────
# 路徑設定
# ──────────────────────────────────────────────────────────────
BASE_DIR  = Path(__file__).resolve().parents[2]         # Trading/
CACHE_DIR = BASE_DIR / "⌚️暫存" / "for_python"
GCP_JSON  = BASE_DIR / "⚙️參數設定" / "rosy-zoo-447904-j1-a600c9e990ca.json"
DB_PATH   = CACHE_DIR / "business_database.json"

WATCHLIST_URL = (
    "https://docs.google.com/spreadsheets/d/"
    "1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE"
    "/edit?gid=1951214900#gid=1951214900"
)

# ──────────────────────────────────────────────────────────────
# 設定
# ──────────────────────────────────────────────────────────────
BATCH_SIZE   = 5     # 每批寫入的股票數（避免觸發 Google Sheets 速率限制）
BATCH_SLEEP  = 3     # 批次間等待秒數

EXCLUDED_IDS = {"TAIEX", "TPEx"}

# ──────────────────────────────────────────────────────────────
# Google Sheet 欄位對應表
# ──────────────────────────────────────────────────────────────
# 每一行：(A欄標籤, B欄對應的 JSON key 候選清單（依優先順序嘗試）)
FIELD_MAP: List[Tuple[str, List[str]]] = [
    ("報告日期",               ["報告日期", "last_updated", "date"]),
    ("產品營收佔比",            ["產品營收佔比", "產品營收占比", "product_revenue"]),
    ("客戶與區域營收佔比",       ["客戶與區域營收佔比", "客戶區域營收佔比", "客戶與區域營收占比", "customer_revenue"]),
    ("企業營運概況與基本介紹",    ["企業營運概況與基本介紹", "企業營運概況", "company_intro", "企業概況"]),
    ("主力產品與服務及獲利模式",  ["主力產品與服務及獲利模式", "主力產品與服務", "products", "主力產品"]),
    ("未來展望",               ["未來展望", "outlook", "future"]),
    ("潛在風險",               ["潛在風險", "risks", "risk"]),
    ("競爭對手",               ["競爭對手", "competitors", "competitor"]),
    ("其他",                  ["其他", "others", "other"]),
]

# ──────────────────────────────────────────────────────────────
# Google Sheets 授權
# ──────────────────────────────────────────────────────────────
SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

def get_gspread_client() -> gspread.Client:
    creds = Credentials.from_service_account_file(str(GCP_JSON), scopes=SCOPES)
    return gspread.authorize(creds)

def parse_sheet_url(url: str) -> Tuple[str, str]:
    """從 Google Sheet URL 解析 (spreadsheet_id, gid)"""
    m_id  = re.search(r"/spreadsheets/d/([a-zA-Z0-9_-]+)", url)
    m_gid = re.search(r"gid=(\d+)", url)
    if not m_id or not m_gid:
        raise ValueError(f"無法解析 URL: {url}")
    return m_id.group(1), m_gid.group(1)

# ──────────────────────────────────────────────────────────────
# 讀取 business_database.json
# ──────────────────────────────────────────────────────────────
def load_database() -> Dict:
    """
    讀取本地 business_database.json。
    如果檔案不存在或解析失敗，直接終止並提示。
    """
    if not DB_PATH.exists():
        print(f"✗ 找不到 business_database.json：{DB_PATH}")
        print("  請先執行 business_1_crawler.py，再由 AI Agent 分析整理後再執行本腳本。")
        sys.exit(1)

    try:
        with open(DB_PATH, encoding="utf-8") as f:
            db = json.load(f)
        print(f"  ✅ 已載入 {len(db)} 筆股票資料")
        return db
    except json.JSONDecodeError as e:
        print(f"✗ business_database.json 解析失敗：{e}")
        sys.exit(1)

# ──────────────────────────────────────────────────────────────
# 讀取關注名單（僅 1 次 Google Sheets API 呼叫）
# ──────────────────────────────────────────────────────────────
def load_stocks(gc: gspread.Client) -> List[dict]:
    """
    從關注名單 Google Sheet 讀取股票清單，
    跳過 TAIEX、TPEx，以及 google_sheet_business == 'xxx' 的股票。
    """
    ss_id, gid = parse_sheet_url(WATCHLIST_URL)
    sh = gc.open_by_key(ss_id)
    ws = sh.get_worksheet_by_id(int(gid))
    vals = ws.get_all_values()

    if len(vals) < 2:
        print("✗ 關注名單無資料")
        return []

    headers = vals[0]
    required = {"stock_id", "stock_name", "google_sheet_business"}
    for col in required:
        if col not in headers:
            print(f"✗ 關注名單缺少欄位：{col}，目前欄位：{headers}")
            return []

    stocks = []
    for row in vals[1:]:
        d = dict(zip(headers, row))
        sid     = d.get("stock_id", "").strip()
        biz_url = d.get("google_sheet_business", "").strip()

        if not sid:
            continue
        if sid in EXCLUDED_IDS:
            print(f"  ⏭  跳過指數：{sid}")
            continue
        if biz_url.lower() == "xxx" or not biz_url.startswith("https://"):
            print(f"  ⏭  跳過（business=xxx 或無 URL）：{sid} {d.get('stock_name','')}")
            continue

        stocks.append({
            "stock_id":              sid,
            "stock_name":            d.get("stock_name", "").strip(),
            "google_sheet_business": biz_url,
        })

    return stocks

# ──────────────────────────────────────────────────────────────
# 從 JSON 資料提取 B2:B10 欄位值
# ──────────────────────────────────────────────────────────────
def extract_field_value(stock_data: dict, candidate_keys: List[str]) -> str:
    """
    依候選 key 清單依序嘗試，回傳第一個非空的值（字串）。
    若全部都空，回傳空字串。
    """
    for key in candidate_keys:
        val = stock_data.get(key, "")
        if val and str(val).strip():
            return str(val).strip()
    return ""

def build_b_column_values(stock_data: dict) -> List[str]:
    """
    依照 FIELD_MAP 產生 B2~B10 的值（共 9 個）。
    B2 = 報告日期，若為空則使用今天日期。
    """
    values = []
    for label, candidates in FIELD_MAP:
        val = extract_field_value(stock_data, candidates)
        # B2（報告日期）若無值，填入今天日期
        if label == "報告日期" and not val:
            val = datetime.now().strftime("%Y-%m-%d")
        values.append(val)
    return values  # 長度 9，對應 B2:B10

def build_a_column_labels() -> List[str]:
    """回傳 A2:A10 的標籤（9 個）"""
    return [label for label, _ in FIELD_MAP]

# ──────────────────────────────────────────────────────────────
# 寫入單一 Google Sheet 情報分頁
# ──────────────────────────────────────────────────────────────
def write_stock_to_sheet(
    ws: gspread.Worksheet,
    stock_id: str,
    stock_name: str,
    stock_data: dict,
) -> bool:
    """
    將情報資料覆寫至 Google Sheet 情報分頁的 A2:B10。
    使用 1 次 batch_update 完成所有欄位，最小化 API 呼叫。

    回傳 True 表示成功，False 表示失敗。
    """
    labels = build_a_column_labels()
    values = build_b_column_values(stock_data)

    # 建構 A2:B10 的完整資料（9 列 × 2 欄）
    rows = [[labels[i], values[i]] for i in range(9)]

    try:
        # 清除 A2:B10 舊資料（1 次 API）
        ws.batch_clear(["A2:B10"])

        # 批次寫入 A2:B10（1 次 API，USER_ENTERED 讓公式生效）
        ws.update(
            range_name="A2",
            values=rows,
            value_input_option="USER_ENTERED",
        )

        # 格式設定：A 欄標籤加粗（1 次 API）
        try:
            ws.format("A2:A10", {
                "textFormat": {"bold": True},
                "wrapStrategy": "WRAP",
            })
            ws.format("B2:B10", {
                "wrapStrategy": "WRAP",
            })
        except Exception as fmt_err:
            print(f"    ⚠ 格式設定失敗（不影響資料）：{fmt_err}")

        print(f"    ✅ {stock_id} {stock_name} → 寫入 B2:B10 完成")
        return True

    except gspread.exceptions.APIError as e:
        print(f"    ✗ {stock_id} Google Sheets API 錯誤：{e}")
        return False
    except Exception as e:
        print(f"    ✗ {stock_id} 寫入失敗：{e}")
        return False

# ──────────────────────────────────────────────────────────────
# 批次處理所有股票
# ──────────────────────────────────────────────────────────────
def process_all_stocks(
    stocks: List[dict],
    db: Dict,
    gc: gspread.Client,
) -> Tuple[int, int]:
    """
    分批開啟 Google Sheet 並寫入。
    關鍵優化：同一試算表（spreadsheet_id 相同）只開啟一次，
    避免重複呼叫 gc.open_by_key()。

    回傳 (成功數, 失敗數)。
    """
    success_count = 0
    fail_count    = 0
    total         = len(stocks)
    num_batches   = (total - 1) // BATCH_SIZE + 1

    # ── 預先按 spreadsheet_id 分組，同一試算表只開啟一次 ──
    # {spreadsheet_id: gspread.Spreadsheet}
    spreadsheet_cache: Dict[str, gspread.Spreadsheet] = {}

    def get_spreadsheet(ss_id: str) -> Optional[gspread.Spreadsheet]:
        if ss_id not in spreadsheet_cache:
            try:
                spreadsheet_cache[ss_id] = gc.open_by_key(ss_id)
            except Exception as e:
                print(f"    ✗ 無法開啟試算表 {ss_id}：{e}")
                return None
        return spreadsheet_cache[ss_id]

    for batch_idx, batch_start in enumerate(range(0, total, BATCH_SIZE)):
        batch = stocks[batch_start: batch_start + BATCH_SIZE]
        print(f"\n  📤 批次 {batch_idx + 1}/{num_batches}（{len(batch)} 支）")

        for stock in batch:
            sid     = stock["stock_id"]
            name    = stock["stock_name"]
            biz_url = stock["google_sheet_business"]

            print(f"\n    [{sid}] {name}")

            # 1. 從 JSON 找資料
            stock_data = db.get(sid)
            if not stock_data:
                print(f"    ⚠ business_database.json 中找不到 {sid} 的資料，略過")
                fail_count += 1
                continue

            # 2. 解析 Google Sheet URL
            try:
                ss_id, gid = parse_sheet_url(biz_url)
            except ValueError as e:
                print(f"    ✗ URL 解析失敗：{e}")
                fail_count += 1
                continue

            # 3. 開啟試算表（有快取，同一試算表只開啟一次）
            sh = get_spreadsheet(ss_id)
            if sh is None:
                fail_count += 1
                continue

            # 4. 取得 worksheet
            try:
                ws = sh.get_worksheet_by_id(int(gid))
            except Exception as e:
                print(f"    ✗ 找不到 worksheet gid={gid}：{e}")
                fail_count += 1
                continue

            # 5. 寫入
            ok = write_stock_to_sheet(ws, sid, name, stock_data)
            if ok:
                success_count += 1
            else:
                fail_count += 1

        # 批次間等待（避免觸發速率限制）
        if batch_start + BATCH_SIZE < total:
            print(f"\n    ⏸  等待 {BATCH_SLEEP} 秒…")
            time.sleep(BATCH_SLEEP)

    return success_count, fail_count

# ──────────────────────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────────────────────
def main():
    start_time = time.time()
    now_str    = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print("=" * 60)
    print(f"🚀 business_2_update.py  開始執行  {now_str}")
    print("=" * 60)

    # ── Step A：讀取 business_database.json（無需 API） ──
    print(f"\n📂 讀取 business_database.json…")
    db = load_database()

    # ── Step B：Google Sheets 授權 ──
    print("\n🔐 Google Sheets 授權中…")
    try:
        gc = get_gspread_client()
    except Exception as e:
        print(f"✗ 授權失敗：{e}")
        sys.exit(1)

    # ── Step C：讀取關注名單（僅 1 次 API 呼叫） ──
    print("\n📋 讀取關注名單…")
    stocks = load_stocks(gc)
    if not stocks:
        print("✗ 無有效股票，結束")
        sys.exit(0)

    # 僅處理 db 中有資料的股票（AI 尚未整理的直接顯示警告）
    stocks_to_process = []
    for s in stocks:
        if s["stock_id"] in db:
            stocks_to_process.append(s)
        else:
            print(f"  ⚠ JSON 中無資料（尚未爬取 or AI 尚未分析）：{s['stock_id']} {s['stock_name']}")

    print(f"  共 {len(stocks_to_process)} 支股票待寫入 Google Sheet")

    if not stocks_to_process:
        print("✗ 無可寫入的股票，結束")
        sys.exit(0)

    # ── Step D：預覽將寫入的欄位 ──
    print(f"\n{'─'*60}")
    print("📝 Google Sheet 欄位對應（B2:B10）")
    print(f"{'─'*60}")
    for i, (label, _) in enumerate(FIELD_MAP):
        print(f"  B{i+2}: {label}")

    # ── Step E：分批寫入 Google Sheet ──
    print(f"\n{'─'*60}")
    print(f"📊 開始批次寫入 Google Sheet（每批 {BATCH_SIZE} 支）")
    print(f"{'─'*60}")

    success, fail = process_all_stocks(stocks_to_process, db, gc)

    # ── 完成報告 ──
    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"✅ 全部完成  耗時：{elapsed:.1f} 秒")
    print(f"   執行時間：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   成功：{success} 支  失敗：{fail} 支")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
