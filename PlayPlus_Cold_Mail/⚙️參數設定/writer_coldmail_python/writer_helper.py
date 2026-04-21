"""
writer_helper.py
================
冷郵件撰寫共用輔助模組 (Google AI SDK 版本)。

功能：
  - 連接 Google Sheets（透過同層級的 gs_helper.py）
  - 初始化 Google Gemini (使用 API Key)
  - generate_email(model, prompt) → 回傳 AI 生成的郵件文字
"""

import os
import sys
import time
import random
import google.generativeai as genai

# ──────────────────────────────────────────────
# 路徑設定
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# 引入共用 Google Sheets 模組
sys.path.insert(0, os.path.join(SCRIPT_DIR, "..", "crawler_104_python"))
from gs_helper import get_worksheet, load_sheet_as_rows, save_rows_to_sheet  # noqa: E402

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

# API Key 路徑
API_KEY_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "crawler_api", "gemini_api_key.txt")
)

# 模型設定
MODEL_NAME = "gemini-1.5-flash"  # Flash 版本速度快且穩定

# 是否覆寫已有內容
OVERWRITE_EXISTING = False

# 呼叫間隔
API_DELAY_MIN = 1.0
API_DELAY_MAX = 2.0


# ──────────────────────────────────────────────
# Gemini 初始化 (Google AI SDK)
# ──────────────────────────────────────────────

def init_gemini_ai():
    """
    從檔案讀取 API Key 並初始化 Google AI SDK。
    """
    if not os.path.exists(API_KEY_PATH):
        raise FileNotFoundError(f"找不到 API Key 檔案：{API_KEY_PATH}\n請在該檔案中貼上您的 Gemini API Key。")

    with open(API_KEY_PATH, "r", encoding="utf-8") as f:
        api_key = f.read().strip()
        # 過濾掉預設說明文字
        if "貼上您的" in api_key or not api_key:
             raise ValueError(f"請先在 {API_KEY_PATH} 中貼上有效的 API Key！")

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(MODEL_NAME)
    print(f"[AI] Gemini SDK 已初始化 → 模型：{MODEL_NAME}\n")
    return model


# ──────────────────────────────────────────────
# 生成函式
# ──────────────────────────────────────────────

def generate_email(model, prompt: str) -> str:
    """
    呼叫 Gemini 生成郵件內容。
    """
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        
        # 去除 markdown 程式碼包覆
        if text.startswith("```"):
            lines = text.split("\n")
            if len(lines) > 2:
                text = "\n".join(lines[1:-1]).strip()
        return text
    except Exception as e:
        print(f"    [AI錯誤] 生成失敗：{e}")
        return ""


def api_delay():
    time.sleep(random.uniform(API_DELAY_MIN, API_DELAY_MAX))


# ──────────────────────────────────────────────
# 通用寫信規則 (保持不變)
# ──────────────────────────────────────────────

COMMON_RULES = """
【格式規定】
- 使用繁體中文撰寫。
- 郵件內容（body）的每個換行必須使用 HTML 的 <br> 格式。
- 郵件結尾固定附上 PlayPlus 官網連結：https://playplus.com.tw/
- 最後一行固定寫「感謝您」，不需要署名。

【開頭規定】
- 如果聯絡人名稱為「官方」，開頭只寫「您好，<br>」。
- 如果聯絡人名稱為具名人士，以「[姓氏] 您好，<br>」開頭。

【風格規定】
- 採歐美俐落風格，第一句就是 Hook。
- 禁止客套話（如：在此先感謝您、久聞貴公司）。
- 禁止以「得知招聘」開頭。

【輸出格式】
只輸出：
標題：[title]
內容：[content]
"""
