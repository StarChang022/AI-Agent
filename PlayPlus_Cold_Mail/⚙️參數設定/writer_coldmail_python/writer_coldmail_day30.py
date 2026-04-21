"""
writer_coldmail_day30.py
========================
使用 API Key 版本。
"""

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from writer_helper import (
    init_gemini_ai, generate_email, api_delay,
    get_worksheet, load_sheet_as_rows, save_rows_to_sheet,
    OVERWRITE_EXISTING, COMMON_RULES
)

TITLE_COL = "day30_title"
CONTENT_COL = "day30_content"
STRATEGY = "處理潛在異議 (Handling Objections)"

def build_prompt(row: dict) -> str:
    company = row.get("公司品牌簡稱", "").strip()
    contact = row.get("聯絡人名稱", "官方").strip()
    description = row.get("說明", "").strip()
    
    return f"{COMMON_RULES}\n【策略：{STRATEGY}】\n\n對象：{company}\n聯絡人：{contact}\n描述：{description}\n\n請撰寫 Day 30 信件（處理預算、時程、溝通成本等疑慮）。"

def parse_response(text: str) -> tuple[str, str]:
    title, content = "", ""
    lines = text.strip().split("\n")
    for line in lines:
        if line.startswith("標題："): title = line[3:].strip()
        if line.startswith("內容："): content = text.split("內容：")[1].strip()
    return title, content

def main():
    print(f"執行 {STRATEGY}...")
    try:
        model = init_gemini_ai()
    except Exception as e:
        print(e); return

    ws = get_worksheet()
    rows, fieldnames = load_sheet_as_rows(ws)
    
    for i, row in enumerate(rows, start=1):
        if (row.get(TITLE_COL) or row.get(CONTENT_COL)) and not OVERWRITE_EXISTING:
            continue
        
        prompt = build_prompt(row)
        result = generate_email(model, prompt)
        title, content = parse_response(result)
        
        if title and content:
            row[TITLE_COL], row[CONTENT_COL] = title, content
            print(f"✅ {row.get('公司品牌簡稱')}")
        
        api_delay()
    
    save_rows_to_sheet(ws, rows, fieldnames)
    print("完成！")

if __name__ == "__main__":
    main()
