import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [
    vue(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png'],
      workbox: {
        // pdf-viewer chunk（vue-pdf-embed + pdfjs 共 ~2.5MB）只在開啟 PDF 預覽才會載入，
        // 不應該在 PWA 安裝時預先快取撐爆首次下載；瀏覽器 HTTP cache 已足夠。
        globIgnores: ['**/pdf-viewer-*.js'],
      },
      manifest: {
        name: 'Quickey — 中小企業收支帳簿',
        short_name: 'Quickey',
        description: '中小企業收支帳簿：支出管理、代墊款簽核、預算控管',
        lang: 'zh-TW',
        theme_color: '#00b39f',
        background_color: '#f4f5f8',
        display: 'standalone',
        start_url: '/app/home',
        scope: '/',
        icons: [
          { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
          {
            src: '/pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  build: {
    rolldownOptions: {
      output: {
        manualChunks: (id: string) => {
          // vue-pdf-embed + pdfjs 固定命名成 pdf-viewer，才能在 PWA globIgnores 用 glob 排除；
          // defineAsyncComponent 本來就會 code-split，這裡只是給 chunk 一個穩定前綴。
          if (/vue-pdf-embed|pdfjs-dist/.test(id)) return 'pdf-viewer'
        },
      },
    },
  },
  server: {
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
})
