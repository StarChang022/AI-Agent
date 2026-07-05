'use strict';

/**
 * build.js — PlayPlus 靜態網站生成主程式
 *
 * 使用方式：
 *   node build.js
 *
 * 或（若有 package.json）：
 *   npm run build
 *
 * 執行流程：
 *   1. 刪除舊的 OUTPUT_DIR（保留 .git）
 *   2. 複製靜態資源（css / js / images / services / ... 及各 HTML 頁面）
 *   3. 解析 blog / portfolio 的 .md 檔案
 *   4. 生成各分類的文章 HTML
 *   5. 生成 blog.html 列表頁
 *   6. 生成 portfolio.html 列表頁
 *   7. 生成 index.html
 *   8. 生成 about-playplus.html（含作品集列表）
 */

const fs   = require('fs');
const path = require('path');

const config = require('./config');
const {
  parseCategory,
  parseOrderJson,
  sortByOrder,
  sortByDateDesc,
} = require('./parser');
const {
  generateBlogArticlePage,
  generatePortfolioArticlePage,
  generateBlogListPage,
  generatePortfolioListPage,
  generateIndexPage,
  generateAboutPage,
} = require('./generator');

// ─── 工具：遞迴複製目錄 ──────────────────────────────────────────────────────
function copyDirSync(src, dest) {
  if (!fs.existsSync(src)) {
    console.warn(`  [skip] 來源不存在：${src}`);
    return;
  }
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath  = path.join(src,  entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// ─── 主程式 ──────────────────────────────────────────────────────────────────
async function main() {
  const {
    INPUT_DIR,
    OUTPUT_DIR,
    SKIP_FILES,
    COPY_DIRS,
    COPY_FILES,
    COPY_SUBDIRS_AS_IS,
    INDEX_LIMITS,
    ABOUT_PORTFOLIO_LIMIT,
  } = config;

  console.log('========================================');
  console.log('  PlayPlus Static Site Generator');
  console.log('========================================');
  console.log(`  INPUT  : ${INPUT_DIR}`);
  console.log(`  OUTPUT : ${OUTPUT_DIR}`);
  console.log('');

  // ── Step 1: 清除舊輸出目錄 ────────────────────────────────────────────────
  console.log('[1/8] 清理舊輸出目錄內容 (保留 .git)...');
  if (fs.existsSync(OUTPUT_DIR)) {
    const files = fs.readdirSync(OUTPUT_DIR);
    for (const file of files) {
      if (file === '.git') continue; // 關鍵：跳過並保留 .git 目錄
      const filePath = path.join(OUTPUT_DIR, file);
      fs.rmSync(filePath, { recursive: true, force: true });
    }
    console.log(`  已清理：${OUTPUT_DIR} (已保留 .git)`);
  } else {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  // ── Step 2: 複製靜態資源 ──────────────────────────────────────────────────
  console.log('[2/8] 複製靜態資源...');

  // 複製資源目錄
  for (const dir of COPY_DIRS) {
    const src  = path.join(INPUT_DIR, dir);
    const dest = path.join(OUTPUT_DIR, dir);
    console.log(`  複製目錄：${dir}/`);
    copyDirSync(src, dest);
  }

  // 複製「以子目錄形式」的目錄（如 services/、.github/）
  for (const dir of COPY_SUBDIRS_AS_IS) {
    const src  = path.join(INPUT_DIR, dir);
    const dest = path.join(OUTPUT_DIR, dir);
    console.log(`  複製子目錄：${dir}/`);
    copyDirSync(src, dest);
  }

  // 複製靜態檔案
  for (const file of COPY_FILES) {
    const src  = path.join(INPUT_DIR, file);
    const dest = path.join(OUTPUT_DIR, file);
    if (fs.existsSync(src)) {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(src, dest);
      console.log(`  複製檔案：${file}`);
    } else {
      console.warn(`  [skip] 來源不存在：${file}`);
    }
  }

  // ── Step 3: 解析 .md 檔案 ─────────────────────────────────────────────────
  console.log('[3/8] 解析 Markdown 文章...');

  // blog（依日期新到舊排序）
  const blogRaw    = parseCategory(path.join(INPUT_DIR, 'blog'), SKIP_FILES);
  const blogSorted = sortByDateDesc(blogRaw);
  console.log(`  blog      : ${blogSorted.length} 篇`);

  // portfolio（依 order.json 排序）
  const portfolioRaw    = parseCategory(path.join(INPUT_DIR, 'portfolio'), SKIP_FILES);
  const portfolioOrder  = parseOrderJson(path.join(INPUT_DIR, 'portfolio', 'order.json'));
  const portfolioSorted = sortByOrder(portfolioRaw, portfolioOrder);
  console.log(`  portfolio : ${portfolioSorted.length} 篇`);

  // ── Step 4: 生成文章 HTML ─────────────────────────────────────────────────
  console.log('[4/8] 生成文章頁面...');

  // blog 文章
  const blogTemplatePath = path.join(INPUT_DIR, 'blog', 'template.html');
  for (const article of blogSorted) {
    const dest = path.join(OUTPUT_DIR, 'blog', `${article.id}.html`);
    generateBlogArticlePage(article, blogTemplatePath, dest);
    console.log(`  [Blog] ${article.id}.html`);
  }

  // portfolio 文章
  const portfolioTemplatePath = path.join(INPUT_DIR, 'portfolio', 'template.html');
  for (const article of portfolioSorted) {
    const dest = path.join(OUTPUT_DIR, 'portfolio', `${article.id}.html`);
    generatePortfolioArticlePage(article, portfolioTemplatePath, dest);
    console.log(`  [Portfolio] ${article.id}.html`);
  }

  // ── Step 5: 生成 blog.html 列表頁 ────────────────────────────────────────
  console.log('[5/8] 生成 blog.html 列表頁...');

  generateBlogListPage(
    blogSorted,
    path.join(INPUT_DIR,  'blog.html'),
    path.join(OUTPUT_DIR, 'blog.html')
  );
  console.log('  blog.html');

  // ── Step 6: 生成 portfolio.html 列表頁 ───────────────────────────────────
  console.log('[6/8] 生成 portfolio.html 列表頁...');

  generatePortfolioListPage(
    portfolioSorted,
    path.join(INPUT_DIR,  'portfolio.html'),
    path.join(OUTPUT_DIR, 'portfolio.html')
  );
  console.log('  portfolio.html');

  // ── Step 7: 生成 index.html ───────────────────────────────────────────────
  console.log('[7/8] 生成 index.html...');

  const siteData = {
    portfolio: portfolioSorted,
    blog     : blogSorted,
  };

  generateIndexPage(
    siteData,
    path.join(INPUT_DIR,  'index.html'),
    path.join(OUTPUT_DIR, 'index.html'),
    INDEX_LIMITS
  );
  console.log('  index.html');

  // ── Step 8: 生成 about-playplus.html ─────────────────────────────────────
  console.log('[8/8] 生成 about-playplus.html...');

  generateAboutPage(
    portfolioSorted,
    path.join(INPUT_DIR,  'about-playplus.html'),
    path.join(OUTPUT_DIR, 'about-playplus.html'),
    ABOUT_PORTFOLIO_LIMIT
  );
  console.log('  about-playplus.html');

  // ── 完成 ──────────────────────────────────────────────────────────────────
  console.log('');
  console.log('========================================');
  console.log('  打包完成！');
  console.log(`  輸出目錄：${OUTPUT_DIR}`);
  console.log('========================================');
}

main().catch((err) => {
  console.error('\n[ERROR] 打包失敗：', err);
  process.exit(1);
});
