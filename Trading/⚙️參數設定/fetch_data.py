import gspread
import pandas as pd
import json
import os

# Set up gspread client
gc = gspread.service_account(filename='/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json')

links = {
    '大盤': 'https://docs.google.com/spreadsheets/d/1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE/edit?gid=1966091264#gid=1966091264',
    '投資組合': 'https://docs.google.com/spreadsheets/d/1YecgMfK1i4hnsiledS5dYwwyBsMCTUPc6H6mfj0G1_0/edit?gid=0#gid=0',
    '1342八貫_交易資料': 'https://docs.google.com/spreadsheets/d/1h4g0wzPkS2wTNxTacsWfTDcMWNGCcI4SZFEsEbySjwk/edit?gid=1850720630#gid=1850720630',
    '1342八貫_財報': 'https://docs.google.com/spreadsheets/d/1h4g0wzPkS2wTNxTacsWfTDcMWNGCcI4SZFEsEbySjwk/edit?gid=318796871#gid=318796871',
    '1342八貫_月報': 'https://docs.google.com/spreadsheets/d/1h4g0wzPkS2wTNxTacsWfTDcMWNGCcI4SZFEsEbySjwk/edit?gid=1972602237#gid=1972602237',
    
    '2308台達電_交易資料': 'https://docs.google.com/spreadsheets/d/108F28v9cHpQ-YPioM6zq_ifNov3DGuSGF8b8WdpoG08/edit?gid=1850720630#gid=1850720630',
    '2308台達電_財報': 'https://docs.google.com/spreadsheets/d/108F28v9cHpQ-YPioM6zq_ifNov3DGuSGF8b8WdpoG08/edit?gid=318796871#gid=318796871',
    '2308台達電_月報': 'https://docs.google.com/spreadsheets/d/108F28v9cHpQ-YPioM6zq_ifNov3DGuSGF8b8WdpoG08/edit?gid=1972602237#gid=1972602237',
    
    '2317鴻海_交易資料': 'https://docs.google.com/spreadsheets/d/1_9oQMc8nP2P48pGiwcpyCxrBIlDaueuyOODZR5AGB3A/edit?gid=1850720630#gid=1850720630',
    '2317鴻海_財報': 'https://docs.google.com/spreadsheets/d/1_9oQMc8nP2P48pGiwcpyCxrBIlDaueuyOODZR5AGB3A/edit?gid=318796871#gid=318796871',
    '2317鴻海_月報': 'https://docs.google.com/spreadsheets/d/1_9oQMc8nP2P48pGiwcpyCxrBIlDaueuyOODZR5AGB3A/edit?gid=1972602237#gid=1972602237',
    
    '2327國巨_交易資料': 'https://docs.google.com/spreadsheets/d/1XvT6J2SyPtCwgbJJscEVInw7ngxk0pWmHsCu3kZbxsI/edit?gid=1850720630#gid=1850720630',
    '2327國巨_財報': 'https://docs.google.com/spreadsheets/d/1XvT6J2SyPtCwgbJJscEVInw7ngxk0pWmHsCu3kZbxsI/edit?gid=318796871#gid=318796871',
    '2327國巨_月報': 'https://docs.google.com/spreadsheets/d/1XvT6J2SyPtCwgbJJscEVInw7ngxk0pWmHsCu3kZbxsI/edit?gid=1972602237#gid=1972602237',
    
    '2330台積電_交易資料': 'https://docs.google.com/spreadsheets/d/130JTSKJsVXbOD1H1sqCo16UANJZJ_Okxxmg5cvHrrMM/edit?gid=1850720630#gid=1850720630',
    '2330台積電_財報': 'https://docs.google.com/spreadsheets/d/130JTSKJsVXbOD1H1sqCo16UANJZJ_Okxxmg5cvHrrMM/edit?gid=318796871#gid=318796871',
    '2330台積電_月報': 'https://docs.google.com/spreadsheets/d/130JTSKJsVXbOD1H1sqCo16UANJZJ_Okxxmg5cvHrrMM/edit?gid=1972602237#gid=1972602237',
    
    '2345智邦_交易資料': 'https://docs.google.com/spreadsheets/d/1syn3CdivSXQ7DemXVM59FlNZwDZKqx3IqyBiwZmqjEo/edit?gid=1850720630#gid=1850720630',
    '2345智邦_財報': 'https://docs.google.com/spreadsheets/d/1syn3CdivSXQ7DemXVM59FlNZwDZKqx3IqyBiwZmqjEo/edit?gid=318796871#gid=318796871',
    '2345智邦_月報': 'https://docs.google.com/spreadsheets/d/1syn3CdivSXQ7DemXVM59FlNZwDZKqx3IqyBiwZmqjEo/edit?gid=1972602237#gid=1972602237',
    
    '2357華碩_交易資料': 'https://docs.google.com/spreadsheets/d/1lLAyqGWGi5e3HpZqLhj0Vq-PMpIxUtzi_TRtdZIud2k/edit?gid=1850720630#gid=1850720630',
    '2357華碩_財報': 'https://docs.google.com/spreadsheets/d/1lLAyqGWGi5e3HpZqLhj0Vq-PMpIxUtzi_TRtdZIud2k/edit?gid=318796871#gid=318796871',
    '2357華碩_月報': 'https://docs.google.com/spreadsheets/d/1lLAyqGWGi5e3HpZqLhj0Vq-PMpIxUtzi_TRtdZIud2k/edit?gid=1972602237#gid=1972602237',
    
    '2887台新新光金_交易資料': 'https://docs.google.com/spreadsheets/d/16sZuqNK-vHlk8rptXsLO5UtfbLWsvUSMgpEZfBTIxB8/edit?gid=811214680#gid=811214680',
    '2887台新新光金_財報': 'https://docs.google.com/spreadsheets/d/16sZuqNK-vHlk8rptXsLO5UtfbLWsvUSMgpEZfBTIxB8/edit?gid=992201504#gid=992201504',
    '2887台新新光金_月報': 'https://docs.google.com/spreadsheets/d/16sZuqNK-vHlk8rptXsLO5UtfbLWsvUSMgpEZfBTIxB8/edit?gid=40343087#gid=40343087',
    
    '8086宏捷科_交易資料': 'https://docs.google.com/spreadsheets/d/1iBksB0xSaKMNo4HwRPUaiAA_UlHO4QaZQR7fHSxVea8/edit?gid=1038125572#gid=1038125572',
    '8086宏捷科_財報': 'https://docs.google.com/spreadsheets/d/1iBksB0xSaKMNo4HwRPUaiAA_UlHO4QaZQR7fHSxVea8/edit?gid=318796871#gid=318796871',
    '8086宏捷科_月報': 'https://docs.google.com/spreadsheets/d/1iBksB0xSaKMNo4HwRPUaiAA_UlHO4QaZQR7fHSxVea8/edit?gid=1972602237#gid=1972602237',
}

import urllib.parse
output_dir = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/data'
os.makedirs(output_dir, exist_ok=True)

for name, url in links.items():
    # Parse gid from url
    parsed = urllib.parse.urlparse(url)
    qs = urllib.parse.parse_qs(parsed.query)
    gid = qs.get('gid', [None])[0]
    if gid is None and parsed.fragment:
        # e.g., #gid=1966091264
        if parsed.fragment.startswith('gid='):
            gid = parsed.fragment.split('=')[1]

    # get doc id
    doc_id = parsed.path.split('/')[3]
    print(f"Fetching {name} (doc: {doc_id}, gid: {gid})...")
    try:
        sh = gc.open_by_key(doc_id)
        if gid:
            worksheet = sh.get_worksheet_by_id(int(gid))
        else:
            worksheet = sh.sheet1
        
        df = pd.DataFrame(worksheet.get_all_records())
        out_path = os.path.join(output_dir, f"{name}.csv")
        df.to_csv(out_path, index=False)
        print(f"Saved {name} with {len(df)} rows.")
    except Exception as e:
        print(f"Error fetching {name}: {e}")
