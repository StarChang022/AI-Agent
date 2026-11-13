// 建置後產生 sitemap.xml、robots.txt（頁面本身由 vite-ssg build 預渲染）。
//
// 用法：package.json 的 build 會在 `vite-ssg build` 之後執行本腳本。
import { existsSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadEnv } from 'vite'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const distDir = join(root, 'dist')

// 網域來源：.env.production 的 VITE_SITE_URL（與前端 src/seo/site.ts 相同）
const env = loadEnv('production', root, 'VITE_')
const SITE_URL = String(process.env.VITE_SITE_URL ?? env.VITE_SITE_URL ?? '').replace(/\/$/, '')
if (!SITE_URL) throw new Error('缺少 VITE_SITE_URL，請設定 .env.production')
if (!existsSync(join(distDir, 'index.html'))) throw new Error('找不到 dist/index.html，請先執行 vite-ssg build')

// 列入 sitemap 的頁面：上線前未開放的頁面（noindex）與文章頁不列入，須與 src/seo/pages.ts 的 inSitemap 設定一致
const SITEMAP_ROUTES = ['/', '/about', '/contact', '/privacy', '/terms']

const today = new Date().toISOString().slice(0, 10)
const urls = SITEMAP_ROUTES.map((route) => `  <url><loc>${SITE_URL}${route}</loc><lastmod>${today}</lastmod></url>`)
writeFileSync(
  join(distDir, 'sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`,
  'utf8',
)
writeFileSync(join(distDir, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${SITE_URL}/sitemap.xml\n`, 'utf8')

console.log(`完成：sitemap.xml（${urls.length} 個網址）、robots.txt`)
