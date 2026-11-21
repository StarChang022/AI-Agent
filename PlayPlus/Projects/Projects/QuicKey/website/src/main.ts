import { ViteSSG } from 'vite-ssg'
import './styles/index.css'
import './styles/layout.css'
import './styles/motion.css'
import App from './App.vue'
import { routes, scrollBehavior } from './router'
import { vReveal } from './motion/reveal'
import { posts } from './data/posts'

// 建置時由 vite-ssg 在 Node 端逐頁渲染成靜態 HTML（不需要瀏覽器）；瀏覽器端照常掛載成 SPA。
// 這裡的程式碼兩邊都會執行：只能在瀏覽器用的 API（window、document）要放在 onMounted 或事件處理函式裡。
export const createApp = ViteSSG(App, { routes, scrollBehavior }, ({ app }) => {
  app.directive('reveal', vReveal)
})

/**
 * 要輸出靜態 HTML 的頁面。vite-ssg 預設會略過動態路由，所以文章頁要自己列出。
 * /404 會對到 not-found 路由，輸出成 dist/404.html（見 vite.config.ts 的 dirStyle），給主機當錯誤頁。
 */
export function includedRoutes(paths: string[]): string[] {
  const staticPaths = paths.filter((p) => !p.includes(':'))
  return [...staticPaths, ...posts.map((p) => `/blog/${p.slug}`), '/404']
}
