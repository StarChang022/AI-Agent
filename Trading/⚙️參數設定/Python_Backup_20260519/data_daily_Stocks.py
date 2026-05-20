import os
import urllib.parse
import aiohttp
import asyncio
import pandas as pd
import gspread
import math
import numpy as np

# API URLs
BASE_URL = "https://api.finmindtrade.com/api/v4/data"

def clean_formula(formula):
    return formula.replace('\n', '').replace('\t', '').strip()

def get_p_to_x_formulas(row_index):
    ri = row_index
    formulas = {
        'P': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$4, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'Q': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$5, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'R': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$6, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'S': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$7, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'T': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$8, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'U': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$A$9, range, OFFSET($E{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($E{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'V': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$B$4, range, OFFSET($G{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($G{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'W': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$B$5, range, OFFSET($G{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($G{ri})), COUNT(range) < N), "-", AVERAGE(range))))""",
        'X': f"""=IF(COUNTA($D{ri}:$G{ri}) = 0, "", LET(N, '儀表板'!$B$6, range, OFFSET($G{ri}, 0, 0, N, 1), IF(OR(NOT(ISNUMBER($G{ri})), COUNT(range) < N), "-", AVERAGE(range))))"""
    }
    return [clean_formula(formulas[col]) for col in ['P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X']]

async def fetch_api(session, dataset, stock_id, start_date):
    url = f"{BASE_URL}?dataset={dataset}&data_id={stock_id}&start_date={start_date}"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return dataset, data.get('data', [])
            else:
                print(f"Failed to fetch {dataset} for {stock_id}: {response.status}")
                return dataset, []
    except Exception as e:
        print(f"Error fetching {dataset} for {stock_id}: {e}")
        return dataset, []

async def get_stock_data(session, stock_id, start_date):
    datasets = [
        'TaiwanStockPrice',
        'TaiwanStockInstitutionalInvestorsBuySell',
        'TaiwanStockMarginPurchaseShortSale',
        'TaiwanStockPER'
    ]
    tasks = [fetch_api(session, ds, stock_id, start_date) for ds in datasets]
    results = await asyncio.gather(*tasks)
    return {ds: data for ds, data in results}

EXCLUDE_IDS = {"TAIEX", "TPEx"}

async def process_all_stocks():
    config_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/Stocks.csv'
    if not os.path.exists(config_path):
        print(f"Config file not found: {config_path}")
        return

    df_config = pd.read_csv(config_path)
    
    # Ensure temporary directory exists
    temp_dir = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/for_python'
    os.makedirs(temp_dir, exist_ok=True)
    
    gc = gspread.service_account(filename='/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json')

    async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(limit=10)) as session:
        for index, row in df_config.iterrows():
            stock_id = str(row['stock_id']).strip()
            if stock_id in EXCLUDE_IDS:
                print(f"Skipping {stock_id} (index, not a stock)")
                continue
            stock_name = row['stock_name']
            google_sheet_daily_url = row['google_sheet_daily']
            
            print(f"Processing {stock_id} {stock_name}...")
            
            # 1. Get existing data and latest date
            if pd.isna(google_sheet_daily_url) or not isinstance(google_sheet_daily_url, str):
                print(f"Invalid google_sheet_daily URL for {stock_id}")
                continue
                
            parsed = urllib.parse.urlparse(google_sheet_daily_url)
            qs = urllib.parse.parse_qs(parsed.query)
            gid = qs.get('gid', [None])[0]
            if gid is None and parsed.fragment:
                if parsed.fragment.startswith('gid='):
                    gid = parsed.fragment.split('=')[1]
                    
            doc_id = parsed.path.split('/')[3]
            
            start_date = "2020-01-01"
            df_old = pd.DataFrame()
            worksheet = None
            
            # 優先從本地 CSV 讀取舊資料並決定最新日期，避免過度讀取 Google Sheets API
            temp_csv = os.path.join(temp_dir, f"{stock_id}_daily.csv")
            if os.path.exists(temp_csv):
                try:
                    df_old = pd.read_csv(temp_csv)
                    if not df_old.empty:
                        # Convert 日期 to YYYY-MM-DD for comparison and API
                        dates = pd.to_datetime(df_old['日期'], errors='coerce')
                        if not dates.isna().all():
                            max_date = dates.max()
                            start_date = max_date.replace(day=1).strftime('%Y-%m-%d')
                            print(f"Found latest date in local CSV: {max_date.strftime('%Y-%m-%d')}, fetching from month start: {start_date}")
                except Exception as e:
                    print(f"Error reading local CSV for {stock_id}: {e}")
                    df_old = pd.DataFrame()

            # 不論本地是否有讀到舊資料，我們都打開 worksheet 備用，但只有在 df_old 為空時才去 get_all_values()
            try:
                sh = gc.open_by_key(doc_id)
                worksheet = sh.get_worksheet_by_id(int(gid)) if gid else sh.sheet1
                if df_old.empty:
                    all_values = worksheet.get_all_values()
                    if len(all_values) > 1:
                        df_old = pd.DataFrame(all_values[1:], columns=all_values[0])
                        dates = pd.to_datetime(df_old['日期'], errors='coerce')
                        if not dates.isna().all():
                            max_date = dates.max()
                            start_date = max_date.replace(day=1).strftime('%Y-%m-%d')
                            print(f"Found latest date in sheet: {max_date.strftime('%Y-%m-%d')}, fetching from month start: {start_date}")
            except Exception as e:
                print(f"Error reading existing data for {stock_id}: {e}")

            print(f"Fetching data for {stock_id} {stock_name} from {start_date}...")
            data_dict = await get_stock_data(session, stock_id, start_date)
            
            # 1. Price Data
            df_price = pd.DataFrame(data_dict['TaiwanStockPrice'])
            if df_price.empty and df_old.empty:
                print(f"No price data for {stock_id}")
                continue
            
            # 2. Institutional Investors
            df_inst = pd.DataFrame(data_dict['TaiwanStockInstitutionalInvestorsBuySell'])
            if not df_inst.empty:
                df_inst['net_buy'] = df_inst['buy'] - df_inst['sell']
                df_inst_pivot = df_inst.pivot_table(index='date', columns='name', values='net_buy', aggfunc='sum').reset_index()
            else:
                df_inst_pivot = pd.DataFrame(columns=['date'])
            
            # Ensure columns exist
            for col in ['Foreign_Investor', 'Foreign_Dealer_Self', 'Investment_Trust', 'Dealer_self', 'Dealer_Hedging']:
                if col not in df_inst_pivot.columns:
                    df_inst_pivot[col] = 0.0
            
            # Fillna
            df_inst_pivot.fillna(0, inplace=True)
            
            # Calculate H, I, J, K (divided by 1000 and rounded)
            df_inst_pivot['H'] = ((df_inst_pivot['Foreign_Investor'] + df_inst_pivot['Foreign_Dealer_Self']) / 1000).round()
            df_inst_pivot['I'] = (df_inst_pivot['Investment_Trust'] / 1000).round()
            df_inst_pivot['J'] = ((df_inst_pivot['Dealer_self'] + df_inst_pivot['Dealer_Hedging']) / 1000).round()
            df_inst_pivot['K'] = df_inst_pivot['H'] + df_inst_pivot['I'] + df_inst_pivot['J']
            
            # 3. Margin & Short
            df_margin = pd.DataFrame(data_dict['TaiwanStockMarginPurchaseShortSale'])
            if df_margin.empty:
                df_margin = pd.DataFrame(columns=['date', 'MarginPurchaseTodayBalance', 'ShortSaleTodayBalance'])
            
            # 4. PER
            df_per = pd.DataFrame(data_dict['TaiwanStockPER'])
            if df_per.empty:
                df_per = pd.DataFrame(columns=['date', 'PER'])
            
            # Merge new data using df_price as the base
            if not df_price.empty:
                df_new = pd.merge(df_price[['date', 'open', 'max', 'min', 'close', 'spread', 'Trading_Volume']], 
                                  df_inst_pivot[['date', 'H', 'I', 'J', 'K']], on='date', how='left')
                df_new = pd.merge(df_new, df_margin[['date', 'MarginPurchaseTodayBalance', 'ShortSaleTodayBalance']], on='date', how='left')
                df_new = pd.merge(df_new, df_per[['date', 'PER']], on='date', how='left')
                
                # Formatting new data
                df_new['date'] = df_new['date'].str.replace('-', '/')
                df_new['Trading_Volume'] = (df_new['Trading_Volume'] / 1000).round()
                df_new['MarginPurchaseTodayBalance'] = df_new['MarginPurchaseTodayBalance'].fillna(0)
                df_new['ShortSaleTodayBalance'] = df_new['ShortSaleTodayBalance'].fillna(0)
                
                # N: 券資比%
                df_new['N'] = np.where(df_new['MarginPurchaseTodayBalance'] > 0, 
                                   (df_new['ShortSaleTodayBalance'] / df_new['MarginPurchaseTodayBalance']) * 100, 
                                   0.0)
                df_new = df_new.fillna('')
            else:
                df_new = pd.DataFrame()

            # Merge with existing data
            if not df_old.empty:
                # Rename columns of df_old to match internal names if necessary
                column_map = {
                    "日期": "date", "開盤": "open", "最高": "max", "最低": "min", "收盤": "close", 
                    "漲跌": "spread", "成交股數": "Trading_Volume", "外資": "H", "投信": "I", 
                    "自營": "J", "法人合計": "K", "融資餘額": "MarginPurchaseTodayBalance", 
                    "融券餘額": "ShortSaleTodayBalance", "券資比%": "N", "本益比": "PER"
                }
                df_old_internal = df_old.rename(columns=column_map)
                # Select only the columns we need for columns A-O
                df_old_internal = df_old_internal[[c for c in column_map.values() if c in df_old_internal.columns]]
                
                df = pd.concat([df_new, df_old_internal]).drop_duplicates(subset=['date'])
            else:
                df = df_new

            # Sort by date descending (newest to oldest)
            df['date_dt'] = pd.to_datetime(df['date'], format='%Y/%m/%d')
            df = df.sort_values('date_dt', ascending=False).drop(columns=['date_dt'])
            
            # Create final columns A to X
            sheet_data = []
            headers = ["日期", "開盤", "最高", "最低", "收盤", "漲跌", "成交股數", "外資", "投信", "自營", "法人合計", "融資餘額", "融券餘額", "券資比%", "本益比", "='儀表板'!$A$4&'儀表板'!$A$3", "='儀表板'!$A$5&'儀表板'!$A$3", "='儀表板'!$A$6&'儀表板'!$A$3", "='儀表板'!$A$7&'儀表板'!$A$3", "='儀表板'!$A$8&'儀表板'!$A$3", "='儀表板'!$A$9&'儀表板'!$A$3", "='儀表板'!$B$4&'儀表板'!$B$3", "='儀表板'!$B$5&'儀表板'!$B$3", "='儀表板'!$B$6&'儀表板'!$B$3"]
            sheet_data.append(headers)
            
            # Reset index to ensure correct formula generation
            df = df.reset_index(drop=True)
            
            for i, r in df.iterrows():
                row_idx = i + 2  # row 1 is header
                
                row_data = [
                    r['date'],           # A
                    r['open'],           # B
                    r['max'],            # C
                    r['min'],            # D
                    r['close'],          # E
                    r['spread'],         # F
                    r['Trading_Volume'], # G
                    r['H'],              # H
                    r['I'],              # I
                    r['J'],              # J
                    r['K'],              # K
                    r['MarginPurchaseTodayBalance'], # L
                    r['ShortSaleTodayBalance'],      # M
                    r['N'],              # N
                    r['PER']             # O
                ]
                
                formulas = get_p_to_x_formulas(row_idx)
                row_data.extend(formulas)
                
                # Format specific numeric types
                formatted_row = []
                for val in row_data:
                    if val == '' or pd.isna(val):
                        formatted_row.append('')
                    elif isinstance(val, (np.integer, int)):
                        formatted_row.append(int(val))
                    elif isinstance(val, (np.floating, float)):
                        if np.isnan(val) or np.isinf(val):
                            formatted_row.append('')
                        else:
                            formatted_row.append(float(val))
                    else:
                        formatted_row.append(val)
                sheet_data.append(formatted_row)
            
            # Save to temporary CSV
            df_out = pd.DataFrame(sheet_data[1:], columns=headers)
            temp_csv = os.path.join(temp_dir, f"{stock_id}_daily.csv")
            df_out.to_csv(temp_csv, index=False, encoding='utf-8-sig')
            
            # Upload to Google Sheet
            if worksheet:
                try:
                    # Clear existing data from row 2 downwards and update with new data starting at A2
                    worksheet.batch_clear(["A2:X9999"])
                    if len(sheet_data) > 1:
                        worksheet.update(values=sheet_data[1:], range_name="A2", value_input_option='USER_ENTERED')
                        
                        # Apply formatting to columns B-F (Price data: thousands separator, 2 decimal places)
                        worksheet.format("B2:F9999", {
                            "numberFormat": {
                                "type": "NUMBER",
                                "pattern": "#,##0.00"
                            }
                        })
                        # Apply formatting to column G-K (Volume and Institutional Investors: thousands separator, integer)
                        worksheet.format("G2:K9999", {
                            "numberFormat": {
                                "type": "NUMBER",
                                "pattern": "#,##0"
                            }
                        })
                    print(f"Successfully updated {stock_id} ({len(sheet_data)-1} rows)")
                except Exception as e:
                    print(f"Error updating Google Sheet for {stock_id}: {e}")

if __name__ == "__main__":
    asyncio.run(process_all_stocks())
