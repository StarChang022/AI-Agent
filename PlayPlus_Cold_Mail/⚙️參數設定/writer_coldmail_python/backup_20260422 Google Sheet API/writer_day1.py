"""
writer_day1.py
==============
搭配「撰寫信件Day1.md」指令執行。
由 AI Agent 完成郵件撰寫後，呼叫本腳本將結果批量寫入 Google Sheets。

欄位：
  day1_title   → 第 1 天郵件標題
  day1_content → 第 1 天郵件內容（段落換行使用 <br>）

Day 1 原則（建立關聯 / Initial Outreach）：
  - 目標：證明有做過功課，建立連結
  - 做法：保持提問與觀察，不具侵略性，提出低壓力 CTA
  - 參考：《冷郵件守則.md》### Day 1：建立關聯

使用方式（由 AI Agent 在撰寫完畢後執行）：
    python3 writer_day1.py

需要安裝的套件：
    pip install google-auth google-auth-httplib2 google-api-python-client
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gsheet_helper as gs

# ──────────────────────────────────────────────
# AI Agent 請在此填入撰寫好的冷郵件資料
# 格式為 list of dict，每個 dict 代表一列
# ──────────────────────────────────────────────

MAIL_DATA = [
    # 範例格式（請 AI Agent 依照名單副本的實際資料填入）：
    # {
    #     "公司品牌簡稱": "公司A",
    #     "email": "info@companya.com",
    #     "title": "【Day1 標題】關於貴公司的數位轉型機會",
    #     "content": "您好，<br><br>..."
    # },
]


# ──────────────────────────────────────────────
# 主程式（無需修改）
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Day 1 冷郵件寫入工具 → Google Sheets")
    print("=" * 60)

    if not MAIL_DATA:
        print("[錯誤] MAIL_DATA 為空！請 AI Agent 填入撰寫好的郵件資料後再執行。")
        return

    print(f"[準備] 共 {len(MAIL_DATA)} 筆郵件資料待寫入")
    print("[GSheet] 連接 Google Sheets...")

    service = gs.get_service()
    gs.write_coldmail_to_sheet(service, day=1, mail_data=MAIL_DATA)

    print("\n" + "=" * 60)
    print(f"  Day 1 寫入完成！")
    print(f"  🔗 {gs.SHEET_URL}")
    print("=" * 60)


if __name__ == "__main__":
    main()
