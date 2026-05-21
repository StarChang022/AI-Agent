"""
business_2_analyze.py
═══════════════════════════════════════════════════════════════════
收集個股情報 Step 2：AI 分析整理（純 Python，不需搭配 AI Agent）

流程：
  1. 讀取 business_database.json（Step 1 產出）
  2. 讀取收集個股情報_2_分析整理.md 指令（動態載入分析要求）
  3. 逐一對每支股票的新聞內文呼叫 Gemini API 進行分析
     - 每支股票的新聞內文打包成一個 prompt
     - Gemini 回傳結構化 JSON，填入分析欄位
  4. 更新 business_database.json（覆寫分析結果）

API 設定：
  - API Key 讀取自 Trading/⚙️參數設定/business-report.env
  - 模型優先順序：gemini-2.5-flash-lite → gemini-2.0-flash-lite → gemini-2.0-flash
  - 內建重試與指數退避機制
═══════════════════════════════════════════════════════════════════
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

# ──────────────────────────────────────────────────────────────
# 路徑設定
# ──────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parents[2]          # Trading/
CACHE_DIR  = BASE_DIR / "⌚️暫存" / "for_python"
DB_PATH    = CACHE_DIR / "business_database.json"
ENV_PATH   = BASE_DIR / "⚙️參數設定" / "business-report.env"
INST_PATH  = BASE_DIR / "💼指令" / "收集個股情報_2_分析整理.md"

# ──────────────────────────────────────────────────────────────
# Gemini API 設定
# ──────────────────────────────────────────────────────────────
GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"

# 模型優先順序（依免費額度從大到小）
MODEL_PRIORITY = [
    "gemini-2.5-flash-lite",
    "gemini-2.0-flash-lite",
    "gemini-2.0-flash",
    "gemini-2.5-flash",
]

# API 呼叫設定
REQUEST_TIMEOUT   = 60      # 單次請求逾時（秒）
RETRY_TIMES       = 3       # 失敗重試次數
RETRY_BASE_DELAY  = 5       # 重試基礎等待（秒）
INTER_STOCK_DELAY = 4       # 每支股票之間的等待（秒），避免觸發速率限制
MAX_OUTPUT_TOKENS = 4096    # Gemini 回應最大 token 數
TEMPERATURE       = 0.3     # 生成溫度（越低越精準）

# ──────────────────────────────────────────────────────────────
# 載入 API Key
# ──────────────────────────────────────────────────────────────
def load_api_key() -> str:
    """從 .env 檔案載入 GEMINI_API_KEY"""
    if not ENV_PATH.exists():
        print(f"✗ 找不到 API Key 檔案：{ENV_PATH}")
        print("  請在該路徑建立 .env 檔案，內容為：GEMINI_API_KEY=你的Key")
        sys.exit(1)

    with open(ENV_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            if key.strip() == "GEMINI_API_KEY":
                api_key = val.strip()
                if not api_key:
                    print("✗ GEMINI_API_KEY 為空值")
                    sys.exit(1)
                return api_key

    print("✗ .env 檔案中找不到 GEMINI_API_KEY")
    sys.exit(1)

# ──────────────────────────────────────────────────────────────
# 載入與儲存 JSON 資料庫
# ──────────────────────────────────────────────────────────────
def load_database() -> Dict:
    if not DB_PATH.exists():
        print(f"✗ 找不到 business_database.json：{DB_PATH}")
        print("  請先執行 business_1_crawler.py")
        sys.exit(1)
    try:
        with open(DB_PATH, encoding="utf-8") as f:
            db = json.load(f)
        return db
    except json.JSONDecodeError as e:
        print(f"✗ JSON 解析失敗：{e}")
        sys.exit(1)

def save_database(db: Dict):
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)

# ──────────────────────────────────────────────────────────────
# 建構分析用的 System Prompt
# ──────────────────────────────────────────────────────────────
SYSTEM_PROMPT = """你是一位專精於美國股市與亞太股市的頂級情報分析員。
你的任務是根據提供的新聞資料，為指定股票撰寫結構化的情報報告。

## 輸出格式要求

你必須回傳一個合法的 JSON 物件，包含以下欄位（全部使用繁體中文撰寫）：

{
  "產品營收佔比": "根據新聞與公開資訊，列出該公司主要產品或業務線的營收佔比。若無法取得精確數字，提供概估或描述主要營收結構。",
  "客戶區域營收佔比": "列出主要客戶或區域的營收貢獻。若查不到具體客戶，提供區域營收佔比（如：亞洲 60%、北美 25%、歐洲 15%）。",
  "企業營運概況": "簡要介紹公司的核心業務、市場地位與近期營運表現。2-3 段落即可。",
  "主力產品與服務": "說明公司的主力產品和服務是什麼？這家公司到底是如何賺錢的？",
  "未來展望": "根據新聞與法人觀點，分析公司未來 1-2 年的成長動能、新產品或市場機會。",
  "潛在風險": "列出可能影響公司營運的風險因素，包含產業競爭、地緣政治、供應鏈等。",
  "競爭對手": "列出主要競爭對手及其與本公司的比較重點。",
  "其他": "任何上述欄位未涵蓋但重要的資訊，例如近期併購、股東結構變化、ESG 議題等。若無則填寫「無」。"
}

## 重要規則

1. 只回傳 JSON，不要加任何其他文字、markdown 標記或程式碼區塊。
2. 不要使用「---」分隔線。
3. 每個欄位的內容都要有實質分析，不要只寫「資料不足」就帶過。盡可能從新聞內文中提取有價值的資訊。
4. 如果新聞中沒有直接提及某些資訊（如營收佔比），請根據產業知識和新聞線索進行合理推估，並標明「根據產業資訊推估」。
5. 使用繁體中文撰寫。
6. 段落使用 Markdown ## 和 ### 標題格式。"""

def build_stock_prompt(stock_id: str, stock_name: str, industry: str, news_list: List[dict]) -> str:
    """為單支股票建構分析 prompt"""
    # 只取有 content 的新聞，並組織成可讀文本
    news_texts = []
    for i, news in enumerate(news_list, 1):
        title = news.get("title", "")
        content = news.get("content", "")
        source = news.get("source", "")
        date = news.get("date", "")

        if content and len(content.strip()) > 30:
            news_texts.append(
                f"【新聞 {i}】\n"
                f"標題：{title}\n"
                f"來源：{source}　日期：{date}\n"
                f"內文：{content}\n"
            )
        elif title and len(title) > 5:
            news_texts.append(
                f"【新聞 {i}】\n"
                f"標題：{title}\n"
                f"來源：{source}　日期：{date}\n"
            )

    if not news_texts:
        news_block = "（本股票暫無可用的新聞資料，請根據你的知識庫提供分析。）"
    else:
        news_block = "\n".join(news_texts)

    return (
        f"## 分析目標\n\n"
        f"股票代號：{stock_id}\n"
        f"公司名稱：{stock_name}\n"
        f"產業類別：{industry}\n\n"
        f"## 新聞資料（共 {len(news_texts)} 則）\n\n"
        f"{news_block}\n\n"
        f"請根據以上新聞資料，為 {stock_id} {stock_name} 撰寫結構化情報報告。"
    )

# ──────────────────────────────────────────────────────────────
# Gemini API 呼叫（含重試與模型 fallback）
# ──────────────────────────────────────────────────────────────
def call_gemini_api(
    api_key: str,
    system_prompt: str,
    user_prompt: str,
    model: str = None,
) -> Optional[str]:
    """
    呼叫 Gemini API，回傳生成的文字。
    包含重試機制與模型 fallback。
    """
    models_to_try = [model] if model else MODEL_PRIORITY

    for model_name in models_to_try:
        url = f"{GEMINI_API_BASE}/{model_name}:generateContent?key={api_key}"

        payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": f"{system_prompt}\n\n{user_prompt}"}]
                }
            ],
            "generationConfig": {
                "temperature": TEMPERATURE,
                "maxOutputTokens": MAX_OUTPUT_TOKENS,
                "responseMimeType": "application/json",
            },
        }

        data = json.dumps(payload).encode("utf-8")

        for attempt in range(RETRY_TIMES + 1):
            try:
                req = urllib.request.Request(
                    url,
                    data=data,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                    result = json.loads(resp.read().decode("utf-8"))

                # 提取回應文字
                candidates = result.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    if parts:
                        return parts[0].get("text", "")

                print(f"    ⚠ {model_name} 回應結構異常，重試中…")

            except urllib.error.HTTPError as e:
                body = ""
                try:
                    body = e.read().decode("utf-8")[:300]
                except Exception:
                    pass

                if e.code == 429:
                    # 速率限制：嘗試下一個模型
                    wait = RETRY_BASE_DELAY * (2 ** attempt)
                    if attempt < RETRY_TIMES:
                        print(f"    ⚠ {model_name} 速率限制 (429)，等待 {wait} 秒後重試…")
                        time.sleep(wait)
                    else:
                        print(f"    ⚠ {model_name} 連續被限速，嘗試下一個模型…")
                        break  # 跳到下一個模型
                elif e.code == 503:
                    wait = RETRY_BASE_DELAY * (attempt + 1)
                    print(f"    ⚠ {model_name} 服務暫時不可用 (503)，等待 {wait} 秒…")
                    time.sleep(wait)
                else:
                    print(f"    ✗ {model_name} HTTP {e.code}: {body}")
                    break

            except Exception as e:
                print(f"    ✗ {model_name} 連線錯誤：{e}")
                if attempt < RETRY_TIMES:
                    time.sleep(RETRY_BASE_DELAY)

    return None

# ──────────────────────────────────────────────────────────────
# 解析 Gemini 回傳的 JSON
# ──────────────────────────────────────────────────────────────
def parse_gemini_response(response_text: str) -> Optional[Dict]:
    """
    解析 Gemini 回傳的 JSON 字串。
    處理各種格式問題（markdown code block、多餘空白等）。
    """
    if not response_text:
        return None

    text = response_text.strip()

    # 移除可能的 markdown code block 標記
    if text.startswith("```"):
        # 移除開頭的 ```json 或 ```
        text = re.sub(r"^```(?:json)?\s*\n?", "", text)
        text = re.sub(r"\n?```\s*$", "", text)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # 嘗試找到第一個 { 和最後一個 }
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end != -1 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except json.JSONDecodeError:
                pass

    print(f"    ⚠ 無法解析 JSON 回應（長度 {len(text)}）")
    return None

# ──────────────────────────────────────────────────────────────
# 將分析結果寫回股票資料
# ──────────────────────────────────────────────────────────────
# JSON key → business_database.json 對應欄位
FIELD_MAPPING = {
    "產品營收佔比":     "產品營收佔比",
    "客戶區域營收佔比": "客戶區域營收佔比",
    "企業營運概況":     "企業營運概況",
    "主力產品與服務":   "主力產品與服務",
    "未來展望":         "未來展望",
    "潛在風險":         "潛在風險",
    "競爭對手":         "競爭對手",
    "其他":             "其他",
}

def apply_analysis_to_stock(stock_data: dict, analysis: dict) -> dict:
    """將 Gemini 分析結果覆寫至 stock_data 對應欄位"""
    for gemini_key, db_key in FIELD_MAPPING.items():
        value = analysis.get(gemini_key, "")
        if value and str(value).strip():
            stock_data[db_key] = str(value).strip()

    # 更新報告日期
    stock_data["報告日期"] = datetime.now().strftime("%Y-%m-%d")
    stock_data["last_updated"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    return stock_data

# ──────────────────────────────────────────────────────────────
# 主處理邏輯
# ──────────────────────────────────────────────────────────────
def analyze_all_stocks(db: Dict, api_key: str) -> Dict:
    """逐一分析所有股票"""
    stock_ids = list(db.keys())
    total = len(stock_ids)
    success = 0
    fail = 0

    for idx, sid in enumerate(stock_ids, 1):
        stock = db[sid]
        name = stock.get("stock_name", sid)
        industry = stock.get("產業類別", "")
        news_list = stock.get("新聞列表", [])

        print(f"\n  [{idx}/{total}] {sid} {name}（{industry}）")

        # 統計有內文的新聞數
        news_with_content = sum(
            1 for n in news_list
            if n.get("content", "") and len(n["content"].strip()) > 30
        )
        print(f"    📰 新聞：{len(news_list)} 則（含內文：{news_with_content} 則）")

        # 建構 prompt
        user_prompt = build_stock_prompt(sid, name, industry, news_list)

        # 呼叫 Gemini API
        print(f"    🤖 呼叫 Gemini API 分析中…")
        response = call_gemini_api(api_key, SYSTEM_PROMPT, user_prompt)

        if not response:
            print(f"    ✗ 分析失敗：Gemini 無回應")
            fail += 1
            continue

        # 解析回應
        analysis = parse_gemini_response(response)
        if not analysis:
            print(f"    ✗ 分析失敗：無法解析 JSON")
            fail += 1
            continue

        # 寫回資料
        db[sid] = apply_analysis_to_stock(stock, analysis)
        filled = sum(1 for k in FIELD_MAPPING.values() if db[sid].get(k, ""))
        print(f"    ✅ 分析完成（填入 {filled}/{len(FIELD_MAPPING)} 個欄位）")
        success += 1

        # 即時存檔（防止中途意外）
        save_database(db)

        # 請求間隔（避免觸發速率限制）
        if idx < total:
            print(f"    ⏸  等待 {INTER_STOCK_DELAY} 秒…")
            time.sleep(INTER_STOCK_DELAY)

    print(f"\n  📊 分析統計：成功 {success} 支 / 失敗 {fail} 支 / 共 {total} 支")
    return db

# ──────────────────────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────────────────────
def main():
    start_time = time.time()
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print("=" * 60)
    print(f"🚀 business_2_analyze.py  開始執行  {now_str}")
    print("=" * 60)

    # ── Step A：載入 API Key ──
    print("\n🔑 載入 Gemini API Key…")
    api_key = load_api_key()
    print(f"  ✅ Key: {api_key[:10]}...{api_key[-4:]}")

    # ── Step B：讀取 business_database.json ──
    print("\n📂 讀取 business_database.json…")
    db = load_database()
    print(f"  ✅ 已載入 {len(db)} 支股票")

    # ── Step C：顯示分析計畫 ──
    total_news = sum(len(s.get("新聞列表", [])) for s in db.values())
    total_content = sum(
        sum(1 for n in s.get("新聞列表", []) if n.get("content", "") and len(n["content"]) > 30)
        for s in db.values()
    )
    print(f"\n{'─'*60}")
    print("🤖 AI 分析計畫")
    print(f"   模型優先：{' → '.join(MODEL_PRIORITY)}")
    print(f"   股票數量：{len(db)} 支")
    print(f"   新聞總數：{total_news} 則（含內文：{total_content} 則）")
    print(f"   預估時間：{len(db) * (INTER_STOCK_DELAY + 5):.0f}~{len(db) * (INTER_STOCK_DELAY + 15):.0f} 秒")
    print(f"{'─'*60}")

    # ── Step D：逐一分析 ──
    db = analyze_all_stocks(db, api_key)

    # ── Step E：最終存檔 ──
    save_database(db)

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"✅ 全部完成  耗時：{elapsed:.1f} 秒")
    print(f"   執行時間：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   暫存路徑：{DB_PATH}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
