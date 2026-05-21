import os
import csv
import time
import urllib.parse
import gspread

from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
import time as _time_module

# ==================== CONFIGURATION ====================
# Absolute path to Service Account JSON key
CREDENTIAL_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json'

# Watchlist Sheet URL (股票名單)
WATCHLIST_URL = 'https://docs.google.com/spreadsheets/d/1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE/edit?gid=1951214900#gid=1951214900'

# Portfolio Sheet URL (資產組合 / 資產管理)
PORTFOLIO_URL = 'https://docs.google.com/spreadsheets/d/1YecgMfK1i4hnsiledS5dYwwyBsMCTUPc6H6mfj0G1_0/edit?gid=0#gid=0'

# Output directory for exported CSVs（若資料夾不存在會自動建立）
OUTPUT_DIR = '/Users/starchang/Desktop/csv'

# Parallel worker count（執行緒數）
# 多個執行緒可以讓網路 I/O 重疊，加速下載。
MAX_WORKERS = 3

# 全域速率上限（每分鐘最多幾個 API 請求，所有 worker 合計）
# Google Sheets API 預設限額：60 req/min per service account
# 建議設為 45，留 25% 安全邊距。
REQUESTS_PER_MINUTE = 45

# 429 發生時最多重試幾次（每次 backoff 加倍：15s → 30s → 60s…）
MAX_RETRIES = 5
# =======================================================


def get_gspread_client(credential_path: str) -> gspread.Client:
    """Authorize and return the gspread client."""
    resolved_path = credential_path
    if not os.path.exists(resolved_path):
        fallbacks = [
            'Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json',
            '../rosy-zoo-447904-j1-a600c9e990ca.json',
            'rosy-zoo-447904-j1-a600c9e990ca.json',
        ]
        for p in fallbacks:
            if os.path.exists(p):
                resolved_path = p
                break
    print(f"Using credentials from: {resolved_path}")
    return gspread.service_account(filename=resolved_path)


def parse_gsheet_url(url: str):
    """Parse doc_id and gid from a Google Sheet URL. Returns (doc_id, gid)."""
    if not url or not url.startswith('https://'):
        return None, None
    try:
        parsed = urllib.parse.urlparse(url)
        qs = urllib.parse.parse_qs(parsed.query)
        gid = qs.get('gid', [None])[0]
        if gid is None and parsed.fragment:
            if parsed.fragment.startswith('gid='):
                gid = parsed.fragment.split('=')[1]
        parts = parsed.path.split('/')
        doc_id = parts[3] if len(parts) > 3 else None
        return doc_id, gid
    except Exception as e:
        print(f"Error parsing URL {url}: {e}")
        return None, None


def is_true(val) -> bool:
    """Check if the cell value is boolean True or 'true' string."""
    if isinstance(val, bool):
        return val
    if isinstance(val, str):
        return val.strip().upper() == 'TRUE'
    return False


class RateLimiter:
    """
    Thread-safe global rate limiter (fixed-interval token bucket).

    All workers share one instance. Before every API call, a worker must
    call `acquire()`, which blocks until the minimum inter-request interval
    has elapsed since the *previous* release across ANY thread.

    With REQUESTS_PER_MINUTE=45 the interval is 60/45 ≈ 1.33 s per request,
    so the combined throughput across all workers stays ≤ 45 req/min.
    """

    def __init__(self, requests_per_minute: float):
        self._interval = 60.0 / requests_per_minute   # seconds between requests
        self._lock = Lock()
        self._next_allowed = 0.0   # monotonic timestamp when the next slot opens

    def acquire(self):
        """Block the calling thread until a request slot is available."""
        with self._lock:
            now = _time_module.monotonic()
            wait = self._next_allowed - now
            if wait > 0:
                _time_module.sleep(wait)
            # Reserve the next slot immediately so other threads queue up
            self._next_allowed = _time_module.monotonic() + self._interval


class SheetCache:
    """
    Thread-safe cache for gspread Spreadsheet objects.
    Ensures each unique doc_id is opened via API only once,
    regardless of how many concurrent workers need it.
    """

    def __init__(self, gc: gspread.Client):
        self._gc = gc
        self._cache: dict[str, gspread.Spreadsheet] = {}
        self._lock = Lock()

    def get_spreadsheet(self, doc_id: str) -> gspread.Spreadsheet:
        with self._lock:
            if doc_id not in self._cache:
                self._cache[doc_id] = self._gc.open_by_key(doc_id)
            return self._cache[doc_id]


def _permission_hint():
    print(f"\033[93m💡 提示：請確保該試算表已「共用」給服務帳戶 email：\033[0m")
    print(f"      \033[96mtrading-agent@rosy-zoo-447904-j1.iam.gserviceaccount.com\033[0m 並給予「檢視者」權限。")


def download_sheet_as_csv(
    rate_limiter: RateLimiter,
    cache: SheetCache,
    url: str,
    file_path: str,
    label: str = '',
    max_retries: int = MAX_RETRIES,
) -> bool:
    """
    Download a specific Google Sheet tab as a CSV file.

    - Acquires a rate-limiter token before every API call (including retries)
      to ensure the global throughput stays within Google's quota.
    - Retries on 429 / Quota errors with exponential backoff.
    - Uses SheetCache so the same spreadsheet object is never opened twice.
    """
    doc_id, gid = parse_gsheet_url(url)
    if not doc_id:
        print(f"\033[91m[錯誤] 無法解析網址{' (' + label + ')' if label else ''}: {url}\033[0m")
        return False

    for attempt in range(1, max_retries + 1):
        try:
            rate_limiter.acquire()   # ← 全域速率閥門，所有 worker 共用
            sh = cache.get_spreadsheet(doc_id)
            if gid:
                worksheet = sh.get_worksheet_by_id(int(gid))
                if worksheet is None:
                    print(f"找不到工作表 GID={gid}，改用第一個工作表。")
                    worksheet = sh.sheet1
            else:
                worksheet = sh.sheet1

            rows = worksheet.get_all_values()

            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            with open(file_path, 'w', newline='', encoding='utf-8-sig') as f:
                csv.writer(f).writerows(rows)

            print(f"\033[92m[成功] {label or file_path}\033[0m → {file_path}")
            return True

        except Exception as e:
            error_str = str(e)
            is_rate_limit = '429' in error_str or 'Quota exceeded' in error_str

            if is_rate_limit and attempt < max_retries:
                # backoff: 15s → 30s → 60s → 120s（最多 120s）
                wait_sec = min(15 * (2 ** (attempt - 1)), 120)
                print(
                    f"\033[93m[警告] Rate limit{' (' + label + ')' if label else ''}，"
                    f"等待 {wait_sec}s 後重試（{attempt}/{max_retries}）...\033[0m"
                )
                time.sleep(wait_sec)
            else:
                print(f"\033[91m[錯誤] 匯出失敗 (doc={doc_id}, gid={gid}): {e}\033[0m")
                # ✅ 只在確定是 403 / PERMISSION_DENIED 時才顯示「共用」提示
                # ❌ 不用 'APIError' in error_str — 因為 429 也是 APIError，會誤判
                if '403' in error_str or 'PERMISSION_DENIED' in error_str:
                    _permission_hint()
                return False

    return False


def fetch_watchlist_data(gc: gspread.Client):
    """
    Open the watchlist spreadsheet and return (headers, data_rows) in a
    single API call (get_all_values fetches the entire sheet at once).
    """
    doc_id, gid = parse_gsheet_url(WATCHLIST_URL)
    if not doc_id:
        print(f"\033[91m[錯誤] 無法解析關注名單 URL: {WATCHLIST_URL}\033[0m")
        return None, None

    try:
        sh = gc.open_by_key(doc_id)
        ws = sh.get_worksheet_by_id(int(gid)) if gid else sh.sheet1
        values = ws.get_all_values()      # ← single API call for the whole sheet
    except Exception as e:
        error_str = str(e)
        print(f"\033[91m[錯誤] 無法讀取主試算表: {e}\033[0m")
        if '403' in error_str or 'PERMISSION_DENIED' in error_str:
            _permission_hint()
        return None, None

    if not values or len(values) < 2:
        print("未在主表格中找到任何資料。")
        return None, None

    return values[0], values[1:]   # headers, data rows


def build_download_tasks(headers: list, rows: list) -> list[dict]:
    """
    Scan all rows once and collect every (url, file_path, label) triple
    that needs to be downloaded. No API calls are made here.
    """

    def col(name, default):
        try:
            return headers.index(name)
        except ValueError:
            return default

    sid_col = col('stock_id', 0)
    task_defs = [
        (col('daily',     5), col('google_sheet_daily',     2), 'daily',     'Task_F_C (每日交易)'),
        (col('monthly',   6), col('google_sheet_monthly',   3), 'monthly',   'Task_G_D (每月營收)'),
        (col('quarterly', 7), col('google_sheet_quarterly', 4), 'quarterly', 'Task_H_E (每季財報)'),
    ]

    tasks = []
    for row_idx, row in enumerate(rows, start=2):
        # Pad short rows to avoid IndexError
        while len(row) < 8:
            row.append('')

        stock_id = row[sid_col].strip() if row[sid_col] else f"Row_{row_idx}"
        if not stock_id:
            continue

        for check_col, url_col, suffix, task_name in task_defs:
            if is_true(row[check_col]):
                url_val = row[url_col]
                if not url_val:
                    print(f"\033[93m[跳過] 第 {row_idx} 行 [{stock_id}] {task_name}：URL 為空\033[0m")
                    continue
                file_path = os.path.join(OUTPUT_DIR, f"{stock_id}_{suffix}.csv")
                label = f"第 {row_idx} 行 [{stock_id}] - {task_name}"
                print(f"發現觸發條件 - {label}")
                tasks.append({'url': url_val, 'file_path': file_path, 'label': label})

    return tasks


def _worker(rate_limiter: RateLimiter, cache: SheetCache, task: dict) -> bool:
    """Thread worker: delegates to download_sheet_as_csv with shared rate limiter."""
    return download_sheet_as_csv(
        rate_limiter, cache, task['url'], task['file_path'], task['label']
    )


def run_parallel_downloads(
    rate_limiter: RateLimiter,
    cache: SheetCache,
    tasks: list[dict],
) -> tuple[int, list[str]]:
    """
    Execute all download tasks in parallel using a thread pool.
    The shared RateLimiter ensures the combined throughput of all workers
    stays within REQUESTS_PER_MINUTE.
    Returns (success_count, failed_files).
    """
    if not tasks:
        return 0, []

    success = 0
    failed_files: list[str] = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {
            executor.submit(_worker, rate_limiter, cache, t): t
            for t in tasks
        }

        for future in as_completed(futures):
            task = futures[future]
            try:
                ok = future.result()
            except Exception as exc:
                print(f"\033[91m[例外] {task['label']}: {exc}\033[0m")
                ok = False
            if ok:
                success += 1
            else:
                failed_files.append(os.path.basename(task['file_path']))

    return success, failed_files


def main():
    print("正在初始化 Google API 服務...")
    try:
        gc = get_gspread_client(CREDENTIAL_PATH)
    except Exception as e:
        print(f"\033[91m[錯誤] 初始化 gspread 服務失敗: {e}\033[0m")
        return

    # ── 建立共用物件（整個執行期間共用）─────────────────────────────────
    rate_limiter = RateLimiter(REQUESTS_PER_MINUTE)
    cache = SheetCache(gc)
    interval_str = f"{60 / REQUESTS_PER_MINUTE:.1f}s"
    print(f"速率限制：{REQUESTS_PER_MINUTE} req/min（每 {interval_str} 一次，{MAX_WORKERS} 個執行緒共用）")

    # ── Step 1: 匯出資產組合 (Portfolio) ─────────────────────────────────
    print("\n正在匯出資產組合 (Portfolio) → stocks.csv ...")
    stocks_file_path = os.path.join(OUTPUT_DIR, 'stocks.csv')
    pf_ok = download_sheet_as_csv(rate_limiter, cache, PORTFOLIO_URL, stocks_file_path, label='資產組合')
    if not pf_ok:
        print("\033[91m[失敗] 資產組合匯出未完成，請檢查權限後再試。\033[0m")

    # ── Step 2: 讀取股票名單（單次 API 呼叫取得整張表）─────────────────────
    print("\n正在讀取股票名單主表格（單次 API 呼叫）...")
    headers, rows = fetch_watchlist_data(gc)
    if headers is None:
        return
    print(f"成功讀取 {len(rows) + 1} 行資料（含表頭）。開始分析觸發條件...")

    # ── Step 3: 掃描所有 row，收集需要下載的任務清單（不呼叫 API）─────────
    tasks = build_download_tasks(headers, rows)
    est_min = len(tasks) / REQUESTS_PER_MINUTE
    print(f"\n共發現 {len(tasks)} 個下載任務，啟動 {MAX_WORKERS} 個平行執行緒下載...")
    print(f"預估耗時：約 {est_min:.1f} 分鐘（{REQUESTS_PER_MINUTE} req/min 限速）")

    # ── Step 4: 平行下載所有任務 ────────────────────────────────────────
    t_start = time.perf_counter()
    ok_count, failed_files = run_parallel_downloads(rate_limiter, cache, tasks)
    elapsed = time.perf_counter() - t_start

    # ── 最終摘要 ────────────────────────────────────────────────────────
    print(f"\n{'─' * 50}")
    print(f"所有任務處理完畢｜耗時 {elapsed:.1f}s")
    print(f"  ✅ 成功：{ok_count} 個")
    if failed_files:
        print(f"  ❌ 失敗：{len(failed_files)} 個，以下檔案未能匯出：")
        for fname in sorted(failed_files):
            print(f"      • {fname}")
    else:
        print(f"  🎉 所有檔案均已成功匯出！")
    print('─' * 50)


if __name__ == '__main__':
    main()
