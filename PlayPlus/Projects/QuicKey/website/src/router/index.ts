import type { RouteRecordRaw, RouterScrollBehavior } from 'vue-router'
// 首頁直接打包進主程式（最多人進站的頁面，不必多等一個檔案）；其他頁面切成獨立檔案，進到該頁才下載
import Home from '../views/Home.vue'

// router 由 vite-ssg 建立（建置時用 memory history，瀏覽器用 web history），這裡只提供路由設定
export const routes: RouteRecordRaw[] = [
  { path: '/', name: 'home', component: Home, meta: { title: 'QUICKEY 快記｜中小企業收支管理工具' } },
  { path: '/about', name: 'about', component: () => import('../views/About.vue'), meta: { title: '關於我們' } },
  { path: '/faq', name: 'faq', component: () => import('../views/Faq.vue'), meta: { title: '常見問題' } },
  { path: '/blog', name: 'blog', component: () => import('../views/Blog.vue'), meta: { title: '部落格' } },
  { path: '/blog/:slug', name: 'blog-post', component: () => import('../views/BlogPost.vue'), meta: { title: '部落格' } },
  { path: '/pricing', name: 'pricing', component: () => import('../views/Pricing.vue'), meta: { title: '方案價格' } },
  { path: '/contact', name: 'contact', component: () => import('../views/Contact.vue'), meta: { title: '聯絡我們' } },
  { path: '/privacy', name: 'privacy', component: () => import('../views/Privacy.vue'), meta: { title: '隱私權政策' } },
  { path: '/terms', name: 'terms', component: () => import('../views/Terms.vue'), meta: { title: '網站使用條款' } },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('../views/NotFound.vue'), meta: { title: '找不到頁面' } },
]

export const scrollBehavior: RouterScrollBehavior = (_to, _from, saved) => saved ?? { top: 0 }
