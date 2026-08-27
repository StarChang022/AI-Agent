#!/bin/bash
# ValueCafe 一鍵打包靜態網站腳本

# 取得腳本所在的根目錄
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "開始執行靜態網站打包..."
/Users/starchang/Library/Python/3.9/lib/python/site-packages/playwright/driver/node "$BASE_DIR/⚙️參數設定/build/build.js"
