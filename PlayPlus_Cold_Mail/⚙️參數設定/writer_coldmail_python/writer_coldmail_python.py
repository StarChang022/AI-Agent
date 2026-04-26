"""
writer_coldmail_python.py  (v2 - Gemini Auto Writer)
=====================================================
用途：
    呼叫 Google Gemini API，為 CSV 名單中每位潛在客戶自動撰寫
    Day 1 / Day 7 / Day 14 / Day 30 / Day 60 的冷郵件，
    並直接覆寫回 CSV 檔案。完全不需要手動在對話框按 RUN。

使用方式：
    1. 在下方 ★ 設定區 ★ 填入你的 Gemini API Key。
    2. 執行：
         python3 writer_coldmail_python.py

    若只想重寫空白欄位（跳過已有內容的列）：
         python3 writer_coldmail_python.py --skip-existing

    若只想重寫特定公司：
         python3 writer_coldmail_python.py --company 西海

依賴套件：
    pip install google-generativeai
"""

import argparse
import csv
import json
import os
import sys
import time

# ─────────────────────────────────────────────
# ★ 設定區 ★  ← 請填入你的 Gemini API Key
# ─────────────────────────────────────────────

GEMINI_API_KEY = "YOUR_GEMINI_API_KEY_HERE"

# 使用的模型（建議 gemini-1.5-flash 速度快、費用低；如需更高品質可改 gemini-1.5-pro）
GEMINI_MODEL = "gemini-2.0-flash"

# CSV 檔案路徑（相對於本腳本的路徑）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(SCRIPT_DIR, "..", "..", "冷郵件對象", "名單副本.csv")

# 每次 API 呼叫之間的等待秒數（避免觸發 rate limit）
API_DELAY_SECONDS = 2

# ─────────────────────────────────────────────
# 冷郵件風格規定（從 冷郵件規定.md 萃取核心原則）
# ─────────────────────────────────────────────

COLD_EMAIL_RULES = """
# PlayPlus 冷郵件撰寫規範

## 我們的品牌
PlayPlus（https://playplus.com.tw/）專注於協助企業將現有網站升級為高質感、高轉換率的數位平台。

## 風格
- 歐美俐落風格：拋棄冗長寒暄，開門見山點出問題或價值。語氣像一位平起平坐的專業顧問在與對方喝咖啡聊天，自然、口語、充滿自信。
- 開場即鉤子（Hook）：第一句就點出對方的痛點或觀察（可用問句開場），直接抓住注意力。
- 極簡架構：「個人化開場 → 點出問題 → 提出解方/價值 → 單一且低壓力的 CTA」
- 吸睛標題：讓目標受眾自然地想開啟郵件。
- 客製化：針對對方公司資料進行客製化，展現你對收件人的了解。

## 寫作規定
### 該做的事
- 採用歐美俐落風格，自然口語，充滿自信
- 打造可信度：提及我們的專業度與真實案例（Social Proof）
- 保持體貼與低壓：「我知道您業務繁忙，若無法回覆我完全能理解」
- 文字簡短有力，段落要短，方便掃視
- 如果聯絡人名稱是「官方」或類似非具名對象，開頭僅寫「您好，」
- 如果有具名聯絡人，開頭寫「[姓名] 您好，」
- 郵件標題及內容必須客製化，參考公司資料後撰寫
- 內容最後放上 https://playplus.com.tw/ 並說明可參考我們的服務及作品集

### 不該做的事
- 禁用傳統公文客套：「素仰貴公司...」「久聞...」「特此致信...」
- 避免浮誇自滿
- 別在第一封信要求太多
- 減少重複內容：每封信都是客製化內容
- 不要用「得知貴司正在招聘」作為開頭，應從產業面找切入點
- 結尾不需要寫寄件人姓名，只需固定寫「感謝您」

## 格式規定
- 換行一律使用 HTML <br> 格式（即使欄位中也要換行）
- 例如：您好，<br><br>內文...<br><br>感謝您

## 五個階段策略
### Day 1：建立關聯 (Initial Outreach)
- 目標：證明有做過功課，建立連結
- 做法：保持提問與觀察，不具侵略性。提出低壓力 CTA

### Day 7：快速溫和提醒 (The Gentle Nudge)
- 目標：測試對方是否只是「忙碌中漏看」
- 做法：簡短不超過 3 句話，不給壓力

### Day 14：價值證明 (Value & Social Proof)
- 目標：用「別人的成功」解決對方的「不信任」
- 做法：帶入成功的實戰案例，提供新資源（如案例分析）

### Day 30：處理潛在異議 (Handling Objections)
- 目標：解決客戶「想回但不敢回」的顧慮（怕貴、怕花時間）
- 做法：主動列出常見問題並給予解方。例如「模組化開發」「分階段優化」「主管每週只需 15 分鐘確認進度」

### Day 60：優雅退場 (The Break-up Email)
- 目標：利用「失去感」引發最後回覆，同時釐清名單
- 做法：宣告不再主動打擾，重申我們的專業，並開放未來合作大門
"""

# ─────────────────────────────────────────────
# 以下為核心邏輯
# ─────────────────────────────────────────────


def build_prompt(company: dict) -> str:
    """為單一公司建立 Gemini 呼叫的 Prompt。"""
    name = company.get("公司品牌簡稱", "")
    website = company.get("官方網站", "")
    industry = company.get("產業", "")
    size = company.get("員工人數", "")
    contact = company.get("聯絡人名稱", "")
    description = company.get("說明", "")

    # 決定開頭稱謂
    if contact and contact not in ("官方", "窗口") and "窗口" not in contact:
        greeting_hint = f"開頭稱謂使用「{contact} 您好，」"
    else:
        greeting_hint = "開頭稱謂使用「您好，」"

    prompt = f"""
你是 PlayPlus 的業務顧問，負責撰寫 B2B 冷郵件開發潛在客戶。

請嚴格遵守以下規範：
{COLD_EMAIL_RULES}

---
## 目標公司資料
- 公司名稱：{name}
- 官方網站：{website}
- 產業：{industry}
- 員工人數：{size}
- 聯絡人：{contact}
- 公司說明：{description}

---
## 任務
請為這家公司撰寫完整的五天冷郵件序列（Day 1、Day 7、Day 14、Day 30、Day 60）。
{greeting_hint}

每封信都必須針對這家公司的產業、業務特性進行客製化，不可使用通用模板。
標題必須吸睛且客製化，絕對不要五封都長得差不多。

---
## 輸出格式
請以 JSON 格式回傳，嚴格符合以下結構，不要有任何多餘說明：

{{
  "day1_title": "...",
  "day1_content": "...",
  "day7_title": "...",
  "day7_content": "...",
  "day14_title": "...",
  "day14_content": "...",
  "day30_title": "...",
  "day30_content": "..."
  "day60_title": "...",
  "day60_content": "..."
}}

注意：
- content 欄位的換行必須使用 <br>（HTML 格式），不要使用 \\n
- 每封信結尾固定以「感謝您」結尾，不要加任何簽名
- 僅回傳 JSON，不要加上 ```json``` 或任何其他說明文字
"""
    return prompt.strip()


def call_gemini(prompt: str) -> dict | None:
    """呼叫 Gemini API 並回傳解析後的 JSON dict。"""
    try:
        import google.generativeai as genai
    except ImportError:
        print("❌ 缺少套件，請執行：pip install google-generativeai")
        sys.exit(1)

    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(GEMINI_MODEL)

    try:
        response = model.generate_content(prompt)
        raw = response.text.strip()

        # 清除可能的 markdown code block 包裝
        if raw.startswith("```"):
            lines = raw.split("\n")
            raw = "\n".join(lines[1:-1]) if lines[-1].strip() == "```" else "\n".join(lines[1:])

        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"  ⚠️  JSON 解析失敗：{e}")
        print(f"  原始回應：{raw[:300]}...")
        return None
    except Exception as e:
        print(f"  ⚠️  API 呼叫失敗：{e}")
        return None


def read_csv(path: str) -> tuple[list[str], list[dict]]:
    """讀取 CSV，回傳 (fieldnames, rows)。"""
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)
    return fieldnames, rows


def write_csv(path: str, fieldnames: list[str], rows: list[dict]) -> None:
    """覆寫 CSV 檔案。"""
    with open(path, encoding="utf-8-sig", newline="") as f:
        # 偵測原始換行符
        content = f.read()
    line_terminator = "\r\n" if "\r\n" in content else "\n"

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator=line_terminator)
        writer.writeheader()
        writer.writerows(rows)


MAIL_FIELDS = [
    "day1_title", "day1_content",
    "day7_title", "day7_content",
    "day14_title", "day14_content",
    "day30_title", "day30_content",
    "day60_title", "day60_content",
]


def row_has_content(row: dict) -> bool:
    """檢查該列是否已有任何信件內容。"""
    return any(row.get(f, "").strip() for f in MAIL_FIELDS)


def main():
    parser = argparse.ArgumentParser(description="PlayPlus 冷郵件全自動撰寫工具（Gemini API）")
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="跳過已有信件內容的列，只處理空白列"
    )
    parser.add_argument(
        "--company",
        type=str,
        default=None,
        help="只處理指定公司名稱（公司品牌簡稱欄位）"
    )
    args = parser.parse_args()

    # 確認 API Key 已設定
    if GEMINI_API_KEY == "YOUR_GEMINI_API_KEY_HERE":
        print("❌ 請先在腳本設定區填入你的 Gemini API Key！")
        print("   取得方式：https://aistudio.google.com/app/apikey")
        sys.exit(1)

    # 讀取 CSV
    print(f"📂  讀取名單：{CSV_PATH}")
    if not os.path.exists(CSV_PATH):
        print(f"❌  找不到 CSV 檔案：{CSV_PATH}")
        sys.exit(1)

    fieldnames, rows = read_csv(CSV_PATH)
    print(f"    ✅ 共讀取 {len(rows)} 筆資料列")

    # 篩選需要處理的列（同一公司的多個 email 都需處理）
    # 以 email 為單位，每個 email 對應一列
    to_process = []
    seen_emails = set()

    for i, row in enumerate(rows):
        email = row.get("email", "").strip()
        company = row.get("公司品牌簡稱", "").strip()

        if not email:
            continue

        # 若指定公司，只處理該公司
        if args.company and company != args.company:
            continue

        # 若 skip-existing，跳過已有內容的列
        if args.skip_existing and row_has_content(row):
            print(f"  ⏭️  跳過（已有內容）：{company} <{email}>")
            continue

        # 同一 email 不重複處理（資料不應有重複 email，但以防萬一）
        if email in seen_emails:
            continue
        seen_emails.add(email)

        to_process.append(i)

    if not to_process:
        print("ℹ️  沒有需要處理的列。")
        sys.exit(0)

    print(f"\n🚀  即將處理 {len(to_process)} 筆資料...\n")

    # 以公司為單位批次呼叫 Gemini（同一公司多個 email 共用同一份信件內容）
    # 建立 公司名稱 → 生成結果 的快取
    company_mail_cache: dict[str, dict] = {}
    success_count = 0
    fail_count = 0

    for idx, row_index in enumerate(to_process, 1):
        row = rows[row_index]
        email = row.get("email", "").strip()
        company = row.get("公司品牌簡稱", "").strip()

        print(f"[{idx}/{len(to_process)}] {company} <{email}>")

        # 若已有該公司的快取結果，直接套用
        if company in company_mail_cache:
            mail_data = company_mail_cache[company]
            print(f"  ♻️  使用快取結果（同公司其他 email）")
        else:
            print(f"  🤖  呼叫 Gemini API 生成信件...")
            prompt = build_prompt(row)
            mail_data = call_gemini(prompt)

            if mail_data is None:
                print(f"  ❌  生成失敗，跳過此列。")
                fail_count += 1
                time.sleep(API_DELAY_SECONDS)
                continue

            company_mail_cache[company] = mail_data
            print(f"  ✅  生成成功")
            time.sleep(API_DELAY_SECONDS)

        # 將生成結果寫入對應列
        for field in MAIL_FIELDS:
            if field in mail_data and mail_data[field]:
                rows[row_index][field] = mail_data[field]

        success_count += 1

    # 覆寫 CSV
    print(f"\n💾  覆寫 CSV 檔案...")
    write_csv(CSV_PATH, fieldnames, rows)
    print(f"✅  完成！成功 {success_count} 筆，失敗 {fail_count} 筆。")
    print(f"    CSV 路徑：{CSV_PATH}")


if __name__ == "__main__":
    main()
