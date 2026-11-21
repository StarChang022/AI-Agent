# syntax=docker/dockerfile:1
#
# 前端 production 用：multi-stage build
#   Stage 1 (builder)：Node + pnpm 把 Vite 打包成 dist/
#   Stage 2 (runtime)：Nginx 伺服靜態檔 + 反代 /api/* 到 backend
#
# 用法（通常由 compose.prod.yml 代為 build）：
#   docker build -t quickey-web -f frontend/Dockerfile frontend/
#   docker run -p 80:80 quickey-web

ARG NODE_VERSION=20
ARG NGINX_VERSION=1.27
ARG PNPM_VERSION=9.15.0

# ---------- Stage 1: build ----------
FROM node:${NODE_VERSION}-alpine AS builder

WORKDIR /app

ARG PNPM_VERSION
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

# ---------- Stage 2: runtime ----------
FROM nginx:${NGINX_VERSION}-alpine AS runtime

RUN rm -rf /etc/nginx/conf.d/* /usr/share/nginx/html/*

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
