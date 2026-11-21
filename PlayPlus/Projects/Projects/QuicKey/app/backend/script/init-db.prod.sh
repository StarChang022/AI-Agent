#!/bin/bash
#
# PostgreSQL 首次啟動初始化（production）
#
# 由 Postgres docker image 的 /docker-entrypoint-initdb.d/ 自動執行，
# 只在 data 目錄為空時跑一次。
#
# 功能：
#   1. 建立應用層 user `backend`（密碼來自 env BACKEND_DATABASE_PASSWORD）
#   2. 建立 Rails 8 production 需要的 4 個 DB：
#      - quickey_production         （primary）
#      - quickey_production_cache   （Solid Cache）
#      - quickey_production_queue   （Solid Queue）
#      - quickey_production_cable   （Solid Cable）
#   DB owner 都設為 backend，Rails 用 BACKEND_DATABASE_PASSWORD 連線。
#
# 密碼透過 psql 的 :'variable' 語法傳入，自動 escape 單引號。

set -e

if [ -z "${BACKEND_DATABASE_PASSWORD:-}" ]; then
    echo "ERROR: BACKEND_DATABASE_PASSWORD 未設定，請在 .env 填寫" >&2
    exit 1
fi

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     --set="password=$BACKEND_DATABASE_PASSWORD" <<-'EOSQL'
    CREATE USER backend WITH PASSWORD :'password';
    CREATE DATABASE quickey_production         OWNER backend;
    CREATE DATABASE quickey_production_cache   OWNER backend;
    CREATE DATABASE quickey_production_queue   OWNER backend;
    CREATE DATABASE quickey_production_cable   OWNER backend;
EOSQL
