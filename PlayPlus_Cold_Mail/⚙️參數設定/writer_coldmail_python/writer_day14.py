"""
writer_day14.py
===============
搭配「撰寫信件Day14.md」指令執行。
由 AI Agent 完成郵件撰寫後，呼叫本腳本將結果批量寫入 Google Sheets。

欄位：
  day14_title   → 第 14 天郵件標題
  day14_content → 第 14 天郵件內容（段落換行使用 <br>）

Day 14 原則（價值證明 / Value & Social Proof）：
  - 目標：用「別人的成功」解決對方的「不信任」
  - 做法：帶入普魯士成功實戰經歷，提供新資源（案例分析）
  - 參考：《冷郵件守則.md》### Day 14：價值證明

使用方式（由 AI Agent 在撰寫完畢後執行）：
    python3 writer_day14.py

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
    #     "title": "【Day14 標題】",
    #     "content": "您好，<br><br>..."
    # },
]


def main():
    print("=" * 60)
    print("  Day 14 冷郵件寫入工具 → Google Sheets")
    print("=" * 60)

    if not MAIL_DATA:
        print("[錯誤] MAIL_DATA 為空！請 AI Agent 填入撰寫好的郵件資料後再執行。")
        return

    print(f"[準備] 共 {len(MAIL_DATA)} 筆郵件資料待寫入")
    print("[GSheet] 連接 Google Sheets...")

    service = gs.get_service()
    gs.write_coldmail_to_sheet(service, day=14, mail_data=MAIL_DATA)

    print("\n" + "=" * 60)
    print(f"  Day 14 寫入完成！")
    print(f"  🔗 {gs.SHEET_URL}")
    print("=" * 60)


if __name__ == "__main__":
    main()
