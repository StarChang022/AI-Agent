# 全域正規表達式逾時：避免寫出會回溯爆量的 regex 時，一張圖就卡死整條 Puma thread。
# OCR 抽欄位逾時會由 Api::OcrController 接住，當作該檔沒有結果。見 docs/OCR辨識規格.md §3.1。
Regexp.timeout = 1
