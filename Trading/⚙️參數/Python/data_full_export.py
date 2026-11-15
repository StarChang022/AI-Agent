#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
全數據更新 + CSV 匯出 整合程序 (data_full_export.py)
──────────────────────────────────────────────────────────────────────────────────
依序執行以下 4 個階段任務：
  1. data_daily.py      (每日交易資訊：個股、加權指數 TAIEX、櫃買指數 TPEx)
  2. data_monthly.py    (每月營收)
  3. data_quarterly.py  (每季財報)
  4. export_csv.py      (匯出 CSV 至本地暫存目錄 stocks/)
──────────────────────────────────────────────────────────────────────────────────
"""

import os
import sys
import time
import subprocess


# 定義執行的階段清單: (腳本檔案名稱, 階段說明描述)
TASKS = [
    ("data_daily.py", "每日交易資訊更新 (Daily)"),
    ("data_monthly.py", "每月營收更新 (Monthly)"),
    ("data_quarterly.py", "每季財報更新 (Quarterly)"),
    ("export_csv.py", "匯出 CSV 檔案 (Export CSV)"),
]


def run_script(script_name: str, description: str, step_num: int, total_steps: int) -> tuple[bool, float, int]:
    """
    執行指定的 Python 腳本並輸出結果。
    回傳: (是否成功, 耗時秒數, returncode)
    """
    base_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(base_dir, script_name)

    print("=" * 65)
    print(f"🚀 【第 {step_num}/{total_steps} 階段】正在啟動: {description}")
    print(f"📄 執行腳本: {script_name}")
    print(f"⏰ 開始時間: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 65)

    start_time = time.time()
    returncode = 0
    success = False

    if not os.path.exists(script_path):
        print(f"❌ 找不到檔案: {script_path}")
        elapsed = time.time() - start_time
        return False, elapsed, -1

    try:
        # 使用目前的 Python 解譯器執行，即時將輸出顯示在終端
        res = subprocess.run([sys.executable, script_path], check=True)
        print("-" * 65)
        print(f"✅ 【第 {step_num}/{total_steps} 階段】{description} 執行成功！")
        success = True
        returncode = res.returncode
    except subprocess.CalledProcessError as e:
        print("-" * 65)
        print(f"❌ 【第 {step_num}/{total_steps} 階段】{description} 執行失敗！錯誤代碼: {e.returncode}")
        returncode = e.returncode
    except Exception as e:
        print("-" * 65)
        print(f"❌ 【第 {step_num}/{total_steps} 階段】{description} 執行時發生例外: {e}")
        returncode = -1
    finally:
        elapsed = time.time() - start_time
        print(f"⏱️ 階段耗時: {elapsed:.2f} 秒")
        print(f"⏰ 結束時間: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    return success, elapsed, returncode


def main():
    total_start = time.time()
    total_steps = len(TASKS)

    print("★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★")
    print("  🌟 全數據更新 (Daily + Monthly + Quarterly) + CSV 匯出 整合程序")
    print(f"  ⏰ 開始時間: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★\n")

    summary_records = []

    for idx, (script, desc) in enumerate(TASKS, start=1):
        ok, elapsed, code = run_script(script, desc, idx, total_steps)
        summary_records.append({
            "step": idx,
            "script": script,
            "desc": desc,
            "ok": ok,
            "elapsed": elapsed,
            "code": code
        })

    total_elapsed = time.time() - total_start

    # ── 最終執行摘要報告 ──────────────────────────────────────────
    print("═" * 65)
    print("📋 全流程執行摘要報告")
    print("═" * 65)
    all_succeeded = True
    for item in summary_records:
        status_icon = "✅ 成功" if item["ok"] else f"❌ 失敗 (代碼 {item['code']})"
        if not item["ok"]:
            all_succeeded = False
        print(f"  [{item['step']}/{total_steps}] {item['desc']:<28}: {status_icon} (耗時 {item['elapsed']:.2f}s)")

    print("─" * 65)
    print(f"⏱️ 總執行耗時: {total_elapsed:.2f} 秒")
    if all_succeeded:
        print("🎉 所有數據更新與 CSV 匯出任務皆已圓滿完成！")
    else:
        print("⚠️ 部分階段任務執行失敗，請檢查上方相關日誌輸出。")
    print("═" * 65 + "\n")

    if not all_succeeded:
        sys.exit(1)


if __name__ == "__main__":
    main()
