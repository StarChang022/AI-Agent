'use strict';

/**
 * build.js — 靜態網站生成主程式
 *
 * 使用方式：
 *   node build.js
 *
 * 或（若有 package.json）：
 *   npm run build
 *
 * 執行流程：
 *   1. 刪除舊的 OUTPUT_DIR
 *   2. 複製靜態資源（css / js / images / statements / to-beginners / contact.html / style.css）
 *   3. 解析各分類的 .md 檔案
 *   4. 生成各分類的文章 HTML
 *   5. 生成各分類的列表 HTML
 *   6. 生成 index.html
 *   7. 生成 worldview.html
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
  generateArticlePage,
  generateLegendaryArticlePage,
  generateNewsArticlePage,
  generateListPage,
  generateLegendaryListPage,
  generateNewsListPage,
  generateIndexPage,
  generateWorldviewPage,
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
  const { INPUT_DIR, OUTPUT_DIR, SKIP_FILES, COPY_DIRS, COPY_FILES, INDEX_LIMITS } = config;

  console.log('========================================');
  console.log('  ValueCafe Static Site Generator');
  console.log('========================================');
  console.log(`  INPUT  : ${INPUT_DIR}`);
  console.log(`  OUTPUT : ${OUTPUT_DIR}`);
  console.log('');

  // ── Step 1: 清除舊輸出目錄 ────────────────────────────────────────────────
  console.log('[1/7] 清理舊輸出目錄內容 (保留 .git)...');
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
  console.log('[2/7] 複製靜態資源...');
  for (const dir of COPY_DIRS) {
    const src  = path.join(INPUT_DIR, dir);
    const dest = path.join(OUTPUT_DIR, dir);
    console.log(`  複製目錄：${dir}/`);
    copyDirSync(src, dest);
  }
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
  console.log('[3/7] 解析 Markdown 文章...');

  // financial-ratios
  const frRaw   = parseCategory(path.join(INPUT_DIR, 'financial-ratios'), SKIP_FILES);
  const frOrder = parseOrderJson(path.join(INPUT_DIR, 'financial-ratios', 'order.json'));
  const frSorted = sortByOrder(frRaw, frOrder);
  console.log(`  financial-ratios : ${frSorted.length} 篇`);

  // intrinsic-value
  const ivRaw    = parseCategory(path.join(INPUT_DIR, 'intrinsic-value'), SKIP_FILES);
  const ivOrder  = parseOrderJson(path.join(INPUT_DIR, 'intrinsic-value', 'order.json'));
  const ivSorted = sortByOrder(ivRaw, ivOrder);
  console.log(`  intrinsic-value  : ${ivSorted.length} 篇`);

  // legendary
  const lgRaw    = parseCategory(path.join(INPUT_DIR, 'legendary'), SKIP_FILES);
  const lgOrder  = parseOrderJson(path.join(INPUT_DIR, 'legendary', 'order.json'));
  const lgSorted = sortByOrder(lgRaw, lgOrder);
  console.log(`  legendary        : ${lgSorted.length} 篇`);

  // news（依日期新到舊）
  const nwRaw    = parseCategory(path.join(INPUT_DIR, 'news'), SKIP_FILES);
  const nwSorted = sortByDateDesc(nwRaw);
  console.log(`  news             : ${nwSorted.length} 篇`);

  // philosophy
  const phRaw    = parseCategory(path.join(INPUT_DIR, 'philosophy'), SKIP_FILES);
  const phOrder  = parseOrderJson(path.join(INPUT_DIR, 'philosophy', 'order.json'));
  const phSorted = sortByOrder(phRaw, phOrder);
  console.log(`  philosophy       : ${phSorted.length} 篇`);

  // ── Step 4: 生成文章 HTML ─────────────────────────────────────────────────
  console.log('[4/7] 生成文章頁面...');

  // financial-ratios 文章
  const frTemplatePath = path.join(INPUT_DIR, 'financial-ratios', 'template.html');
  for (const article of frSorted) {
    const dest = path.join(OUTPUT_DIR, 'financial-ratios', `${article.id}.html`);
    generateArticlePage(article, frTemplatePath, dest, frSorted);
    console.log(`  [FR] ${article.id}.html`);
  }

  // intrinsic-value 文章
  const ivTemplatePath = path.join(INPUT_DIR, 'intrinsic-value', 'template.html');
  for (const article of ivSorted) {
    const dest = path.join(OUTPUT_DIR, 'intrinsic-value', `${article.id}.html`);
    generateArticlePage(article, ivTemplatePath, dest, ivSorted);
    console.log(`  [IV] ${article.id}.html`);
  }

  // legendary 文章
  const lgTemplatePath = path.join(INPUT_DIR, 'legendary', 'template.html');
  for (const article of lgSorted) {
    const dest = path.join(OUTPUT_DIR, 'legendary', `${article.id}.html`);
    generateLegendaryArticlePage(article, lgTemplatePath, dest, lgSorted);
    console.log(`  [LG] ${article.id}.html`);
  }

  // news 文章
  const nwTemplatePath = path.join(INPUT_DIR, 'news', 'template.html');
  for (const article of nwSorted) {
    const dest = path.join(OUTPUT_DIR, 'news', `${article.id}.html`);
    generateNewsArticlePage(article, nwTemplatePath, dest, nwSorted);
    console.log(`  [NW] ${article.id}.html`);
  }

  // philosophy 文章
  const phTemplatePath = path.join(INPUT_DIR, 'philosophy', 'template.html');
  for (const article of phSorted) {
    const dest = path.join(OUTPUT_DIR, 'philosophy', `${article.id}.html`);
    generateArticlePage(article, phTemplatePath, dest, phSorted);
    console.log(`  [PH] ${article.id}.html`);
  }

  // ── Step 5: 生成列表頁 HTML ───────────────────────────────────────────────
  console.log('[5/7] 生成列表頁面...');

  generateListPage(
    frSorted,
    path.join(INPUT_DIR, 'financial-ratios.html'),
    path.join(OUTPUT_DIR, 'financial-ratios.html')
  );
  console.log('  financial-ratios.html');

  generateListPage(
    ivSorted,
    path.join(INPUT_DIR, 'intrinsic-value.html'),
    path.join(OUTPUT_DIR, 'intrinsic-value.html')
  );
  console.log('  intrinsic-value.html');

  generateLegendaryListPage(
    lgSorted,
    path.join(INPUT_DIR, 'legendary.html'),
    path.join(OUTPUT_DIR, 'legendary.html')
  );
  console.log('  legendary.html');

  generateNewsListPage(
    nwSorted,
    path.join(INPUT_DIR, 'news.html'),
    path.join(OUTPUT_DIR, 'news.html')
  );
  console.log('  news.html');

  generateListPage(
    phSorted,
    path.join(INPUT_DIR, 'philosophy.html'),
    path.join(OUTPUT_DIR, 'philosophy.html')
  );
  console.log('  philosophy.html');

  // ── Step 6: 生成 index.html ───────────────────────────────────────────────
  console.log('[6/7] 生成 index.html...');

  const siteData = {
    financialRatios: frSorted,
    intrinsicValue : ivSorted,
    legendary      : lgSorted,
    news           : nwSorted,
    philosophy     : phSorted,
  };

  generateIndexPage(
    siteData,
    path.join(INPUT_DIR,  'index.html'),
    path.join(OUTPUT_DIR, 'index.html'),
    INDEX_LIMITS
  );
  console.log('  index.html');

  // ── Step 7: 生成 worldview.html ───────────────────────────────────────────
  console.log('[7/7] 生成 worldview.html...');

  // 收集所有分類的文章（statements / to-beginners 無 md，直接複製，不參與 worldview）
  // 根據指令：financial-ratios, intrinsic-value, legendary, news, philosophy, statements, to-beginners
  // statements / to-beginners 已直接複製為靜態 html，
  // worldview 的 🟢Url 為 category/id 形式
  const allArticlesMap = {
    'financial-ratios': frSorted,
    'intrinsic-value' : ivSorted,
    'legendary'       : lgSorted,
    'news'            : nwSorted,
    'philosophy'      : phSorted,
  };

  generateWorldviewPage(
    allArticlesMap,
    path.join(INPUT_DIR,  'worldview.html'),
    path.join(OUTPUT_DIR, 'worldview.html')
  );
  console.log('  worldview.html');

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
