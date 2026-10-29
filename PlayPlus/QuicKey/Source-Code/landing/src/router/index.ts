import { createRouter, createWebHistory } from 'vue-router'
import Home from '../views/Home.vue'
import About from '../views/About.vue'
import Faq from '../views/Faq.vue'
import Blog from '../views/Blog.vue'
import BlogPost from '../views/BlogPost.vue'
import Pricing from '../views/Pricing.vue'
import Contact from '../views/Contact.vue'
import Privacy from '../views/Privacy.vue'
import Terms from '../views/Terms.vue'
import NotFound from '../views/NotFound.vue'
import { applySeo } from '../seo/seo'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: Home, meta: { title: '快記每一筆，帳務更省力' } },
    { path: '/about', name: 'about', component: About, meta: { title: '關於我們' } },
    { path: '/faq', name: 'faq', component: Faq, meta: { title: '常見問題' } },
    { path: '/blog', name: 'blog', component: Blog, meta: { title: '部落格' } },
    { path: '/blog/:slug', name: 'blog-post', component: BlogPost, meta: { title: '部落格' } },
    { path: '/pricing', name: 'pricing', component: Pricing, meta: { title: '方案價格' } },
    { path: '/contact', name: 'contact', component: Contact, meta: { title: '聯絡我們' } },
    { path: '/privacy', name: 'privacy', component: Privacy, meta: { title: '隱私權政策' } },
    { path: '/terms', name: 'terms', component: Terms, meta: { title: '服務條款' } },
    { path: '/:pathMatch(.*)*', name: 'not-found', component: NotFound, meta: { title: '找不到頁面' } },
  ],
  scrollBehavior(_to, _from, saved) {
    return saved ?? { top: 0 }
  },
})

router.afterEach((to) => {
  applySeo(to)
})

export default router
