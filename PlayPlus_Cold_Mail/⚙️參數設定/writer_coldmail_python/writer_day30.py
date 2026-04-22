"""
writer_day30.py
===============
搭配「撰寫信件Day30.md」指令執行。
由 AI Agent 完成郵件撰寫後，呼叫本腳本將結果批量寫入 Google Sheets。

欄位：
  day30_title   → 第 30 天郵件標題
  day30_content → 第 30 天郵件內容（段落換行使用 <br>）

Day 30 原則（處理潛在異議 / Handling Objections）：
  - 目標：解決客戶「想回但不敢回」的顧慮（怕貴、怕花時間）
  - 做法：主動列出常見問題並給予解方，強調模組化與分階段方案
  - 參考：《冷郵件守則.md》### Day 30：處理潛在異議

使用方式（由 AI Agent 在撰寫完畢後執行）：
    python3 writer_day30.py

需要安裝的套件：
    pip install google-auth google-auth-httplib2 google-api-python-client
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gsheet_helper as gs

# ──────────────────────────────────────────────
# AI Agent 請在此填入撰寫好的冷郵件資料
# ──────────────────────────────────────────────

MAIL_DATA = [
    # {
    #     "公司品牌簡稱": "公司A",
    #     "email": "info@companya.com",
    #     "title": "【Day30 標題】",
    #     "content": "您好，<br><br>..."
    # },
]


def main():
    print("=" * 60)
    print("  Day 30 冷郵件寫入工具 → Google Sheets")
    print("=" * 60)

    if not MAIL_DATA:
        print("[錯誤] MAIL_DATA 為空！請 AI Agent 填入撰寫好的郵件資料後再執行。")
        return

    print(f"[準備] 共 {len(MAIL_DATA)} 筆郵件資料待寫入")
    print("[GSheet] 連接 Google Sheets...")

    service = gs.get_service()
    gs.write_coldmail_to_sheet(service, day=30, mail_data=MAIL_DATA)

    print("\n" + "=" * 60)
    print(f"  Day 30 寫入完成！")
    print(f"  🔗 {gs.SHEET_URL}")
    print("=" * 60)


if __name__ == "__main__":
    main()
