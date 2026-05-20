import os
import urllib.parse
import aiohttp
import asyncio
import pandas as pd
import gspread
import numpy as np
from typing import Union, Optional, List, Tuple, Dict

# ============================================================
# 加權指數 (TAIEX) 每日交易資訊
# 指令來源：加權指數交易資訊.md
# ============================================================

BASE_URL = "https://api.finmindtrade.com/api/v4/data"
STOCK_ID = "TAIEX"

CONFIG_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/Stocks.csv'
CREDENTIAL_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json'
TEMP_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/for_python'


def get_o_to_w_formulas(row_index: int) -> list:
    """
    產生第 row_index 列的 O~W 欄 Google Sheet 公式。
    對應 加權指數交易資訊.md 的 ## O欄公式 ~ ## W欄公式。
    """
    ri = row_index

    # O~T：以 $E (收盤) 為 OFFSET 基準，讀取儀表板 $A$4 ~ $A$9
    dashboard_a_refs = ['$A$4', '$A$5', '$A$6', '$A$7', '$A$8', '$A$9']
    close_formulas = [
        f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!{ref}, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))"""
        for ref in dashboard_a_refs
    ]

    # U~W：以 $G (成交金額) 為 OFFSET 基準，讀取儀表板 $B$4 ~ $B$6
    dashboard_b_refs = ['$B$4', '$B$5', '$B$6']
    money_formulas = [
        f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!{ref}, range, OFFSET($G{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($G{ri})), COUNT(range) < N), "-", AVERAGE(range))))"""
        for ref in dashboard_b_refs
    ]

    return close_formulas + money_formulas  # O, P, Q, R, S, T, U, V, W


async def fetch_api(session: aiohttp.ClientSession, dataset: str, start_date: str) -> tuple:
    """向 FinMind API 發出請求，回傳 (dataset, data_list)。"""
    url = f"{BASE_URL}?dataset={dataset}&data_id={STOCK_ID}&start_date={start_date}"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return dataset, data.get('data', [])
            else:
                print(f"  ✗ 無法取得 {dataset}，狀態碼：{response.status}")
                return dataset, []
    except Exception as e:
        print(f"  ✗ 發生例外 {dataset}：{e}")
        return dataset, []


async def fetch_all(session: aiohttp.ClientSession, start_date: str) -> dict:
    """並行呼叫三支 FinMind API。"""
    datasets = [
        'TaiwanStockPrice',                          # 交易資訊
        'TaiwanStockTotalInstitutionalInvestors',     # 三大法人明細
        'TaiwanStockTotalMarginPurchaseShortSale',    # 融資融券
    ]
    tasks = [fetch_api(session, ds, start_date) for ds in datasets]
    results = await asyncio.gather(*tasks)
    return {ds: data for ds, data in results}


def parse_google_sheet_url(url: str) -> Tuple[str, Optional[str]]:
    """從 Google Sheet URL 解析出 doc_id 與 gid。"""
    parsed = urllib.parse.urlparse(url)
    qs = urllib.parse.parse_qs(parsed.query)
    gid = qs.get('gid', [None])[0]
    if gid is None and parsed.fragment and parsed.fragment.startswith('gid='):
        gid = parsed.fragment.split('=')[1]
    doc_id = parsed.path.split('/')[3]
    return doc_id, gid


def get_start_date(worksheet) -> str:
    """
    讀取 Google Sheet 現有資料，回傳應開始抓取的日期字串 (YYYY-MM-DD)。
    若尚無資料則回傳 '2020-01-01'。
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


def build_new_df(data_dict: dict) -> pd.DataFrame:
    """
    將三支 API 的原始資料整合成一個 DataFrame，欄位對應 A~N 欄。
    """
    # ── 交易資訊 ────────────────────────────────────────────
    df_price = pd.DataFrame(data_dict['TaiwanStockPrice'])
    if df_price.empty:
        return pd.DataFrame()

    # 指數的成交金額欄位可能是 Trading_money 或 Trading_Amount
    money_col = 'Trading_money' if 'Trading_money' in df_price.columns else ('Trading_Amount' if 'Trading_Amount' in df_price.columns else None)

    if money_col:
        # 成交金額除以 1 億，四捨五入為整數
        df_price['Trading_money_fmt'] = (df_price[money_col] / 1e8).round(0).astype('Int64')
    else:
        df_price['Trading_money_fmt'] = 0

    # ── 三大法人 ─────────────────────────────────────────────
    df_inst_raw = pd.DataFrame(data_dict['TaiwanStockTotalInstitutionalInvestors'])
    if not df_inst_raw.empty:
        df_inst_raw['net_buy'] = df_inst_raw['buy'] - df_inst_raw['sell']
        df_inst_pivot = (
            df_inst_raw
            .pivot_table(index='date', columns='name', values='net_buy', aggfunc='sum')
            .reset_index()
        )
    else:
        df_inst_pivot = pd.DataFrame(columns=['date'])

    # 確保所有法人欄位存在
    for col in ['Foreign_Investor', 'Foreign_Dealer_Self', 'Investment_Trust', 'Dealer_self', 'Dealer_Hedging']:
        if col not in df_inst_pivot.columns:
            df_inst_pivot[col] = 0.0
    df_inst_pivot.fillna(0, inplace=True)

    # H：外資（Foreign_Investor + Foreign_Dealer_Self）/ 1000 四捨五入
    df_inst_pivot['H'] = ((df_inst_pivot['Foreign_Investor'] + df_inst_pivot['Foreign_Dealer_Self']) / 1000).round(0).astype('Int64')
    # I：投信 / 1000 四捨五入
    df_inst_pivot['I'] = (df_inst_pivot['Investment_Trust'] / 1000).round(0).astype('Int64')
    # J：自營（Dealer_self + Dealer_Hedging）/ 1000 四捨五入
    df_inst_pivot['J'] = ((df_inst_pivot['Dealer_self'] + df_inst_pivot['Dealer_Hedging']) / 1000).round(0).astype('Int64')
    # K：法人合計
    df_inst_pivot['K'] = df_inst_pivot['H'] + df_inst_pivot['I'] + df_inst_pivot['J']

    # ── 融資融券 ──────────────────────────────────────────────
    df_margin_raw = pd.DataFrame(data_dict['TaiwanStockTotalMarginPurchaseShortSale'])
    if not df_margin_raw.empty:
        df_margin_pivot = (
            df_margin_raw
            .pivot_table(index='date', columns='name', values='TodayBalance', aggfunc='sum')
            .reset_index()
        )
    else:
        df_margin_pivot = pd.DataFrame(columns=['date'])

    for col in ['MarginPurchase', 'ShortSale']:
        if col not in df_margin_pivot.columns:
            df_margin_pivot[col] = 0

    # ── 合併 ──────────────────────────────────────────────────
    df = pd.merge(
        df_price[['date', 'open', 'max', 'min', 'close', 'spread', 'Trading_money_fmt']],
        df_inst_pivot[['date', 'H', 'I', 'J', 'K']],
        on='date', how='left'
    )
    df = pd.merge(df, df_margin_pivot[['date', 'MarginPurchase', 'ShortSale']], on='date', how='left')

    # 融資融券填 0
    df['MarginPurchase'] = df['MarginPurchase'].fillna(0).astype('Int64')
    df['ShortSale'] = df['ShortSale'].fillna(0).astype('Int64')

    # N：券資比%
    df['N'] = np.where(
        df['MarginPurchase'] > 0,
        (df['ShortSale'] / df['MarginPurchase']) * 100,
        0.0
    )

    # 日期格式 YYYY/MM/DD
    df['date'] = df['date'].str.replace('-', '/')

    return df


def merge_with_old(df_new: pd.DataFrame, df_old: pd.DataFrame) -> pd.DataFrame:
    """
    合併新舊資料，以新資料優先，去除重複日期後依日期新到舊排序。
    """
    if df_old.empty:
        df = df_new
    else:
        # 將舊資料欄位改名，使其與新資料一致
        col_map = {
            '交易日期': 'date', '日期': 'date', '開盤': 'open', '最高': 'max', '最低': 'min',
            '收盤': 'close', '漲跌': 'spread', '成交金額': 'Trading_money_fmt', '成交量': 'Trading_money_fmt',
            '外資': 'H', '投信': 'I', '自營': 'J', '法人合計': 'K',
            '融資餘額': 'MarginPurchase', '融券餘額': 'ShortSale', '券資比%': 'N'
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
    """
    headers = [
        '日期', '開盤', '最高', '最低', '收盤', '漲跌', '成交金額',
        '外資', '投信', '自營', '法人合計', '融資餘額', '融券餘額', '券資比%',
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
            """將 NA / NaN / inf 轉為空字串，其餘保留原型別。"""
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
            r['date'],                   # A 交易日期
            safe(r['open']),             # B 開盤
            safe(r['max']),              # C 最高
            safe(r['min']),              # D 最低
            safe(r['close']),            # E 收盤
            safe(r['spread']),           # F 漲跌
            safe(r['Trading_money_fmt']),# G 成交金額
            safe(r['H']),                # H 外資
            safe(r['I']),                # I 投信
            safe(r['J']),                # J 自營
            safe(r['K']),                # K 法人合計
            safe(r['MarginPurchase']),   # L 融資餘額
            safe(r['ShortSale']),        # M 融券餘額
            safe(r['N']),                # N 券資比%
        ]

        formulas = get_o_to_w_formulas(row_idx)  # O~W（9 個公式）
        row_data.extend(formulas)
        sheet_data.append(row_data)

    return sheet_data


async def main():
    # ── 讀取 Stocks.csv，找到 TAIEX 列 ───────────────────────
    if not os.path.exists(CONFIG_PATH):
        print(f"✗ 找不到設定檔：{CONFIG_PATH}")
        return

    df_config = pd.read_csv(CONFIG_PATH)
    taiex_row = df_config[df_config['stock_id'].astype(str) == STOCK_ID]

    if taiex_row.empty:
        print(f"✗ Stocks.csv 中找不到 stock_id={STOCK_ID}，請先新增該列。")
        return

    google_sheet_url = taiex_row.iloc[0]['google_sheet_daily']
    if pd.isna(google_sheet_url) or not isinstance(google_sheet_url, str):
        print(f"✗ TAIEX 的 google_sheet_daily 欄位為空，請先填入 Google Sheet URL。")
        return

    # ── 初始化 Google Sheet ───────────────────────────────────
    os.makedirs(TEMP_DIR, exist_ok=True)
    gc = gspread.service_account(filename=CREDENTIAL_PATH)

    doc_id, gid = parse_google_sheet_url(google_sheet_url)
    sh = gc.open_by_key(doc_id)
    worksheet = sh.get_worksheet_by_id(int(gid)) if gid else sh.sheet1

    # ── 決定起始日期（從現有資料最新日期的月初）────────────────
    start_date, df_old = get_start_date(worksheet)

    print(f"▶ 開始抓取 TAIEX 資料，起始日期：{start_date}")

    # ── 並行呼叫 FinMind API ──────────────────────────────────
    async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(limit=5)) as session:
        data_dict = await fetch_all(session, start_date)

    # ── 整合新資料 ────────────────────────────────────────────
    df_new = build_new_df(data_dict)
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
    temp_csv = os.path.join(TEMP_DIR, 'TAIEX_daily.csv')
    headers = sheet_data[0]
    pd.DataFrame(sheet_data[1:], columns=headers).to_csv(temp_csv, index=False, encoding='utf-8-sig')
    print(f"  暫存 CSV 已儲存：{temp_csv}")

    # ── 寫入 Google Sheet ─────────────────────────────────────
    try:
        worksheet.batch_clear(["A2:W9999"])
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
            # H~K：千分位整數（法人，千張）
            worksheet.format("H2:K9999", {
                "numberFormat": {"type": "NUMBER", "pattern": "#,##0"}
            })

        print(f"✔ TAIEX 更新完成，共寫入 {len(sheet_data) - 1} 筆資料。")
    except Exception as e:
        print(f"✗ 寫入 Google Sheet 失敗：{e}")


if __name__ == "__main__":
    asyncio.run(main())
