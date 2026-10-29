# QUICKEY 官網（Landing）

分支：`quickey-landing`，網站原始碼只放在 `landing/` 資料夾內，方便之後拆成獨立 repo。

## 指令

```bash
cd landing
pnpm install
pnpm dev        # 開發伺服器
pnpm build      # 打包
pnpm preview    # 預覽打包結果
```

## 設計 tokens

`src/styles/index.css` 的 `@theme` 區塊複製自主 App 的設計系統（`frontend/src/styles/index.css`），修改時兩邊要同步。

## 假資料

`src/config.ts` 內的註冊網址、LINE 官方帳號與 Email 目前皆為示範值，正式上線前要替換。
