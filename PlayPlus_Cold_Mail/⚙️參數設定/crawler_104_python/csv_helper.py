import csv
import os
from typing import List, Dict

# CSV 路徑
CSV_PATH = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "..", "冷郵件對象", "名單副本.csv")
)

FIELDNAMES = [
    "公司品牌簡稱", "序號", "官方網站", "產業", "員工人數",
    "email", "聯絡人名稱", "來源", "說明"
]

def get_service():
    """CSV 版本不需認證，回傳 None。"""
    return None

def read_all_rows(service=None) -> tuple[List[Dict], List[str]]:
    """讀取 CSV，回傳 (rows, fieldnames)。"""
    if not os.path.exists(CSV_PATH):
        return [], FIELDNAMES
    
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames if reader.fieldnames else FIELDNAMES
        rows = list(reader)
    return rows, fieldnames

def write_all_rows(service, rows: List[Dict], fieldnames: List[str]) -> None:
    """將全部資料完整覆寫回 CSV。"""
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[CSV] ✅ 已覆寫 {len(rows)} 列資料至 {CSV_PATH}")

def append_rows(service, new_rows: List[Dict], fieldnames: List[str]) -> int:
    """將新資料附加至 CSV 末尾。"""
    if not new_rows:
        return 0
    
    file_exists = os.path.exists(CSV_PATH)
    with open(CSV_PATH, "a", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if not file_exists:
            writer.writeheader()
        writer.writerows(new_rows)
    
    print(f"[CSV] ✅ 已附加 {len(new_rows)} 列資料至 {CSV_PATH}")
    return len(new_rows)

def ensure_header(service=None) -> List[str]:
    """確保 CSV 存在且有標題列。"""
    if not os.path.exists(CSV_PATH):
        with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
            writer.writeheader()
        print(f"[CSV] 已初始化 CSV 檔案與標題列")
        return FIELDNAMES
    
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return reader.fieldnames if reader.fieldnames else FIELDNAMES

def get_existing_sources(service=None) -> set:
    """讀取所有已存在的「來源」欄 URL。"""
    rows, fieldnames = read_all_rows()
    existing = set()
    src_col = "來源"
    if src_col not in fieldnames:
        return existing
    for row in rows:
        src = row.get(src_col, "").strip()
        if src:
            clean = src.split("?")[0].rstrip("/")
            existing.add(clean)
    return existing
