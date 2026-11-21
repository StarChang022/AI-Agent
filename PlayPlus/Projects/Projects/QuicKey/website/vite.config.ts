import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  server: {
    // 聯絡表單 API 由 wrangler pages dev（Pages Functions）提供，見 README「本地測試聯絡表單」
    proxy: {
      '/api': 'http://localhost:8788',
    },
  },
  // 建置時預渲染（vite-ssg build）：在 Node 端把每一頁渲染成靜態 HTML，要輸出的頁面見 src/main.ts 的 includedRoutes
  ssgOptions: {
    // /about → dist/about.html。Cloudflare Pages 會直接在 /about 回應 200，不會 308 轉址到 /about/，
    // 和 canonical、sitemap 的網址（不帶結尾斜線）一致。/404 也因此輸出成 dist/404.html，給主機當錯誤頁。
    dirStyle: 'flat',
    // 不另外內嵌關鍵 CSS（需要額外套件 beasties）
    beastiesOptions: false,
  },
})
