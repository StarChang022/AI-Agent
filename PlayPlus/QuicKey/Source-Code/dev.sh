#!/usr/bin/env bash
# Quickey 本地開發啟動腳本
# 用法：./dev.sh
#   - 啟動 Docker Postgres（背景）
#   - 跑 Rails migration
#   - 前景並行啟動 Rails API + Vite 前端
#   - Ctrl+C 一次全部關掉（Postgres 保留在背景，資料不會遺失）

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

# --- 前置檢查 ---
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker 沒在跑，請先開 Docker Desktop"
  exit 1
fi

# --- 1. 啟動 Postgres ---
echo "▸ 啟動 Postgres (docker compose up -d db)"
docker compose -f "$BACKEND/compose.yml" up -d db

echo "▸ 等 Postgres 就緒…"
until docker compose -f "$BACKEND/compose.yml" exec -T db pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
done
echo "  ✓ Postgres ready"

# --- 2. 跑 migration（有 pending 才會動，沒有就秒過）---
echo "▸ 跑 rails db:migrate"
(cd "$BACKEND" && bin/rails db:migrate)

# --- 3. 並行啟動 Rails + Vite ---
PIDS=()

cleanup() {
  echo ""
  echo "▸ 收工，關閉服務…"
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  echo "  ✓ Rails / Vite 已停止（Postgres 保留在背景；要關就手動 docker compose -f backend/compose.yml down）"
}
trap cleanup EXIT INT TERM

echo "▸ 啟動 Rails API (port 3000)"
(cd "$BACKEND" && bin/rails s) &
PIDS+=($!)

echo "▸ 啟動 Vite 前端 (port 5173)"
(cd "$FRONTEND" && pnpm dev) &
PIDS+=($!)

echo ""
echo "════════════════════════════════════════"
echo "  Rails API   →  http://localhost:3000"
echo "  Vite 前端   →  http://localhost:5173"
echo "  Ctrl+C 停止"
echo "════════════════════════════════════════"
echo ""

wait
