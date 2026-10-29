// 建置後預渲染：用無頭瀏覽器逐一開啟公開頁面，把渲染完成的 HTML 寫入 dist/，
// 讓爬蟲（含不執行 JavaScript 的 AI 爬蟲與社群預覽）拿到完整內容與 meta。
// 同時產生 sitemap.xml、robots.txt，並輸出 404.html。
//
// 用法：先 `vite build`，再執行本腳本（package.json 的 build 已串接）。
// Chrome 路徑：環境變數 CHROME_PATH；未設定時 macOS 使用系統安裝的 Google Chrome。
// 在沙箱或 CI 無法使用 sandbox 時，設定 PRERENDER_NO_SANDBOX=1。
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadEnv, preview } from 'vite'
import { chromium } from 'playwright-core'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const distDir = join(root, 'dist')
const PORT = 4178

// 網域來源：.env.production 的 VITE_SITE_URL（與前端 src/seo/site.ts 相同）
const env = loadEnv('production', root, 'VITE_')
const SITE_URL = String(process.env.VITE_SITE_URL ?? env.VITE_SITE_URL ?? '').replace(/\/$/, '')
if (!SITE_URL) throw new Error('缺少 VITE_SITE_URL，請設定 .env.production')

const STATIC_ROUTES = ['/', '/about', '/pricing', '/faq', '/blog', '/contact', '/privacy', '/terms']

// 從 posts.ts 讀出文章 slug 與發布日（每筆一行，格式固定）
function readPosts() {
  const src = readFileSync(join(root, 'src/data/posts.ts'), 'utf8')
  const list = []
  for (const line of src.split('\n')) {
    const slug = line.match(/slug: '([^']+)'/)
    const date = line.match(/publishedAt: '(\d{4}-\d{2}-\d{2})'/)
    if (slug && date) list.push({ slug: slug[1], publishedAt: date[1] })
  }
  if (list.length === 0) throw new Error('無法從 src/data/posts.ts 讀取文章清單')
  return list
}

function chromePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH
  if (process.platform === 'darwin') return '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
  return undefined
}

function outFile(route) {
  // '/' → dist/index.html；'/blog/x' → dist/blog/x/index.html
  return route === '/' ? join(distDir, 'index.html') : join(distDir, route.replace(/^\//, ''), 'index.html')
}

async function renderRoute(browser, route) {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
    // 減少動態效果：內容直接顯示，不會留在 data-reveal 的隱藏狀態
    reducedMotion: 'reduce',
    locale: 'zh-TW',
  })
  const page = await context.newPage()
  const errors = []
  page.on('pageerror', (e) => errors.push(e.message))
  try {
    await page.goto(`http://127.0.0.1:${PORT}${route}`, { waitUntil: 'networkidle', timeout: 45000 })
    await page.waitForSelector('html[data-seo-ready]', { timeout: 15000 })
    const html = '<!doctype html>\n' + (await page.evaluate(() => document.documentElement.outerHTML))
    return { html, errors }
  } finally {
    await context.close()
  }
}

async function main() {
  if (!existsSync(join(distDir, 'index.html'))) throw new Error('找不到 dist/index.html，請先執行 vite build')

  const postList = readPosts()
  const postRoutes = postList.map((p) => `/blog/${p.slug}`)
  const routes = [...STATIC_ROUTES, ...postRoutes]

  const server = await preview({
    root,
    build: { outDir: 'dist' },
    preview: { host: '127.0.0.1', port: PORT, strictPort: true },
  })

  const launchOptions = { headless: true, args: process.env.PRERENDER_NO_SANDBOX ? ['--no-sandbox'] : [] }
  const exe = chromePath()
  if (exe) launchOptions.executablePath = exe
  const browser = await chromium.launch(launchOptions)

  const failures = []
  try {
    for (const route of routes) {
      const { html, errors } = await renderRoute(browser, route)
      if (errors.length) failures.push(`${route}: ${errors.join(' | ')}`)
      mkdirSync(dirname(outFile(route)), { recursive: true })
      writeFileSync(outFile(route), html, 'utf8')
      console.log(`prerendered ${route}`)
    }
    // 404：不建立索引，給主機當作錯誤頁
    const notFound = await renderRoute(browser, '/__prerender-404__')
    writeFileSync(join(distDir, '404.html'), notFound.html, 'utf8')
    console.log('prerendered 404.html')
  } finally {
    await browser.close()
    await new Promise((r) => server.httpServer.close(r))
  }

  // sitemap.xml：列出公開頁面（不含 noindex）；文章附上發布日
  const today = new Date().toISOString().slice(0, 10)
  const urls = [
    ...STATIC_ROUTES.map((route) => `  <url><loc>${SITE_URL}${route === '/' ? '/' : route}</loc><lastmod>${today}</lastmod></url>`),
    ...postList.map((p) => `  <url><loc>${SITE_URL}/blog/${p.slug}</loc><lastmod>${p.publishedAt}</lastmod></url>`),
  ]
  writeFileSync(
    join(distDir, 'sitemap.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`,
    'utf8',
  )
  writeFileSync(
    join(distDir, 'robots.txt'),
    `User-agent: *\nAllow: /\n\nSitemap: ${SITE_URL}/sitemap.xml\n`,
    'utf8',
  )

  console.log(`完成：${routes.length + 1} 個頁面、sitemap.xml、robots.txt`)
  if (failures.length) {
    console.warn('以下頁面渲染時有 JavaScript 錯誤，請檢查：')
    for (const f of failures) console.warn(`  - ${f}`)
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
