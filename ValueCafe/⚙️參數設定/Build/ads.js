'use strict';

/**
 * ads.js — 廣告邏輯模組
 *
 * 根據 Ads-Generation.md 的規則，從 database.json 抓取對應頁面的廣告，
 * 並套用 templates.html 中的指定樣式後回傳已渲染的廣告 HTML 字串。
 */

const fs   = require('fs');
const path = require('path');

// ─── 廣告資源路徑（相對於 Build/ 的上層 ⚙️參數設定/Ads/）────────────────────
const ADS_DIR      = path.resolve(__dirname, '../Ads');
const DB_PATH      = path.join(ADS_DIR, 'database.json');
const TMPL_PATH    = path.join(ADS_DIR, 'templates.html');

// ─── 快取（模組層級，只讀取一次）─────────────────────────────────────────────
let _db       = null;
let _tmplRaw  = null;

/**
 * 讀取並快取廣告資料庫。
 * @returns {Array}
 */
function loadDatabase() {
  if (_db) return _db;
  try {
    _db = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  } catch (e) {
    console.warn('[ads] 無法讀取 database.json：', e.message);
    _db = [];
  }
  return _db;
}

/**
 * 讀取並快取 templates.html 原始內容。
 * @returns {string}
 */
function loadTemplates() {
  if (_tmplRaw) return _tmplRaw;
  try {
    _tmplRaw = fs.readFileSync(TMPL_PATH, 'utf8');
  } catch (e) {
    console.warn('[ads] 無法讀取 templates.html：', e.message);
    _tmplRaw = '';
  }
  return _tmplRaw;
}

// ─── 樣板萃取 ────────────────────────────────────────────────────────────────

/**
 * 從 templates.html 中萃取指定 <!-- Label --> 後的第一個 <a> 完整區塊。
 *
 * @param {string} label - 'Horizontal Bar Ads' | 'Bookmarks Ads' | 'Cards Ads'
 * @returns {string}     - 萃取到的 <a>...</a> HTML 字串（含縮排）
 */
function extractAdTemplate(label) {
  const tmpl = loadTemplates();
  // 使用 regex 忽略注釋中多餘空白（例如 "Horizontal Bar Ads  " 有兩個空格）
  const escapedLabel = label.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const commentRe = new RegExp(`<!--\\s*${escapedLabel}\\s*-->`);
  const match = commentRe.exec(tmpl);
  if (!match) {
    console.warn(`[ads] 找不到樣板區塊：${label}`);
    return '';
  }

  // 從 comment 後找第一個 '<'
  const afterComment = match.index + match[0].length;
  const tagStart = tmpl.indexOf('<a ', afterComment);
  if (tagStart === -1) return '';

  // 找配對的 </a>
  let depth = 0;
  let i = tagStart;
  while (i < tmpl.length) {
    if (tmpl.slice(i).startsWith('<a ') || tmpl.slice(i).startsWith('<a\t') || tmpl.slice(i) === '<a>') {
      depth++;
      i = tmpl.indexOf('>', i) + 1;
      continue;
    }
    if (tmpl.slice(i).startsWith('</a>')) {
      depth--;
      i += 4;
      if (depth === 0) return tmpl.slice(tagStart, i);
      continue;
    }
    i++;
  }
  return tmpl.slice(tagStart);
}

// ─── 廣告過濾與取樣 ──────────────────────────────────────────────────────────

/**
 * 根據頁面路徑（相對於 output root，e.g. "financial-ratios/debt-ratio.html"）
 * 從 database.json 過濾出符合該頁面的廣告清單。
 *
 * @param {string} pageRelPath - e.g. "financial-ratios/debt-ratio.html"
 * @returns {Array}
 */
function getAdsForPage(pageRelPath) {
  const db = loadDatabase();
  return db.filter(ad => {
    if (!Array.isArray(ad.pages)) return false;
    // 1. 完全比對（適用於內頁或有明確指定的頁面）
    if (ad.pages.includes(pageRelPath)) return true;
    
    // 2. 列表頁比對：若為分類列表頁 (例如 "financial-ratios.html")，
    // 則抓取該廣告是否被分配到該分類下的任何內頁 (startsWith "financial-ratios/")
    if (pageRelPath.endsWith('.html') && !pageRelPath.includes('/')) {
      const category = pageRelPath.replace('.html', '');
      return ad.pages.some(p => p.startsWith(category + '/'));
    }
    
    return false;
  });
}

/**
 * 從陣列中隨機不重複地取最多 n 個元素。
 *
 * @param {Array}  arr
 * @param {number} n
 * @returns {Array}
 */
function randomSampleAds(arr, n) {
  const copy = [...arr];
  const result = [];
  while (result.length < n && copy.length > 0) {
    const idx = Math.floor(Math.random() * copy.length);
    result.push(copy.splice(idx, 1)[0]);
  }
  return result;
}

// ─── 廣告渲染 ────────────────────────────────────────────────────────────────

/**
 * 將廣告資料填入廣告樣板，並依 type 移除多餘的 tag 標籤、圖片，同時依頁面層級調整圖片路徑。
 *
 * @param {string} tmplBlock  - 從 templates.html 萄取的 <a>...</a> 字串
 * @param {object} ad         - database.json 中的單一廣告物件
 * @param {string} pageRelPath - e.g. "financial-ratios/debt-ratio.html"。
 *                              用於判斷是否為內頁（含 /），內頁圖片路徑需加 ../
 * @returns {string}
 */
function renderAdBlock(tmplBlock, ad, pageRelPath) {
  let html = tmplBlock
    .replace(/🟢AdsUrl/g,         ad.url         || '')
    .replace(/🟢AdsTitle/g,       ad.title       || '')
    .replace(/🟢AdsDescription/g, ad.description || '');

  // 依据 type 移除不需要的 tag 標籤
  if (ad.type === 'Books') {
    html = html.replace(/<li class="green">Courses<\/li>\s*/g, '');
  } else if (ad.type === 'Courses') {
    html = html.replace(/<li class="orange">Books<\/li>\s*/g, '');
  }

  // 依据 type 只保留對應圖片，移除另一張
  if (ad.type === 'Books') {
    // 移除 recomm-courses.webp
    html = html.replace(/<img\s[^>]*recomm-courses\.webp[^>]*>\s*/g, '');
  } else if (ad.type === 'Courses') {
    // 移除 recomm-books.webp
    html = html.replace(/<img\s[^>]*recomm-books\.webp[^>]*>\s*/g, '');
  }

  // 內頁路徑調整：若 pageRelPath 含 / 表示為内頁，圖片路徑加 ../
  if (pageRelPath && pageRelPath.includes('/')) {
    html = html.replace(/src="images\//g, 'src="../images/');
  }

  return html;
}

// ─── 公開介面 ────────────────────────────────────────────────────────────────

/**
 * 產生 Horizontal Bar 廣告 HTML（隨機取樣）。
 *
 * @param {string} pageRelPath - e.g. "financial-ratios.html"
 * @param {number} count       - 取樣數量（預設 1）
 * @param {string} outerWrap   - 若需額外包裹，傳入開/關標籤字串 e.g. '<div class="column column-content">'
 * @returns {string[]}         - 已渲染的廣告 HTML 陣列（每元素一則廣告）
 */
function buildHorizontalBarAds(pageRelPath, count = 1, outerWrap = null) {
  const pool     = getAdsForPage(pageRelPath);
  const selected = randomSampleAds(pool, count);
  const tmpl     = extractAdTemplate('Horizontal Bar Ads');

  return selected.map(ad => {
    const inner = renderAdBlock(tmpl, ad, pageRelPath);
    if (outerWrap) {
      const tagName = (outerWrap.match(/^<([a-zA-Z][a-zA-Z0-9-]*)/) || [])[1] || 'div';
      const closeTag = `</${tagName}>`;
      return `${outerWrap}\n${inner}\n${closeTag}`;
    }
    return inner;
  });
}

/**
 * 產生 Bookmarks 廣告 HTML（隨機取樣）。
 *
 * @param {string} pageRelPath
 * @param {number} maxCount    - 最多幾則（預設 5）
 * @returns {string[]}
 */
function buildBookmarksAds(pageRelPath, maxCount = 5) {
  const pool     = getAdsForPage(pageRelPath);
  const selected = randomSampleAds(pool, maxCount);
  const tmpl     = extractAdTemplate('Bookmarks Ads');

  return selected.map(ad => renderAdBlock(tmpl, ad, pageRelPath));
}

/**
 * 產生 Cards 廣告 HTML（隨機取樣）。
 *
 * @param {string} pageRelPath
 * @param {number} count       - 取樣數量（預設 1）
 * @param {string} outerWrap   - 外層包裹開標籤，e.g. '<div class="col-md-3">'
 * @returns {string[]}
 */
function buildCardsAds(pageRelPath, count = 1, outerWrap = null) {
  const pool     = getAdsForPage(pageRelPath);
  const selected = randomSampleAds(pool, count);
  const tmpl     = extractAdTemplate('Cards Ads');

  return selected.map(ad => {
    const inner = renderAdBlock(tmpl, ad, pageRelPath);
    if (outerWrap) {
      const tagName = (outerWrap.match(/^<([a-zA-Z][a-zA-Z0-9-]*)/) || [])[1] || 'div';
      const closeTag = `</${tagName}>`;
      return `${outerWrap}\n${inner}\n${closeTag}`;
    }
    return inner;
  });
}

module.exports = {
  loadDatabase,
  getAdsForPage,
  randomSampleAds,
  buildHorizontalBarAds,
  buildBookmarksAds,
  buildCardsAds,
};
