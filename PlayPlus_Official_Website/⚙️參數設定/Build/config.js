'use strict';

const path = require('path');

// ─── 路徑設定 ────────────────────────────────────────────────────────────────
const INPUT_DIR  = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Official_Website/資料庫';
const OUTPUT_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/playplus2025_transition_version';

// ─── 使用 order.json 排序的分類 ──────────────────────────────────────────────
const ORDERED_CATEGORIES = [
  'portfolio',
];

// ─── 依日期排序的分類 ────────────────────────────────────────────────────────
const DATE_SORTED_CATEGORIES = [
  'blog',
];

// ─── 直接複製（不需編譯）的資源 ─────────────────────────────────────────────
const COPY_DIRS = [
  'css',
  'js',
  'images',
  'public',
  'sass',
];

const COPY_FILES = [
  'style.css',
  'style.css.map',
  'contact.html',
  'contact-success.html',
  'about-playplus.html',
  'digital-transformation.html',
  'faq.html',
  'quickly-solution.html',
  'recommended-tools.html',
  'partners.html',
  'privacy.html',
  'terms.html',
  'process.html',
  '404.html',
  'CNAME',
  '_headers',
  'robots.txt',
  'llms.txt',
  'CLAUDE.md',
  'gulpfile.js',
  'generate_page.py',
  'package.json',
  'package-lock.json',
  'resize-services.mjs',
  'types.d.ts',
  '.gitignore',
];

// ─── 直接複製整個目錄（以子目錄形式）的資源 ─────────────────────────────────
const COPY_SUBDIRS_AS_IS = [
  'services',
  '.github',
];

// ─── 不需打包的黑名單 ────────────────────────────────────────────────────────
const SKIP_FILES = new Set([
  'empty.md',
  'template.html',
  'order.json',
]);

// ─── index.html 各分類顯示數量 ───────────────────────────────────────────────
const INDEX_LIMITS = {
  'portfolio': 6,  // 作品集卡片數量（首頁）
  'blog'     : 4,  // 知識筆記顯示數量（首頁）
};

// ─── about-playplus.html 作品集顯示數量 ─────────────────────────────────────
const ABOUT_PORTFOLIO_LIMIT = 6;

module.exports = {
  INPUT_DIR,
  OUTPUT_DIR,
  ORDERED_CATEGORIES,
  DATE_SORTED_CATEGORIES,
  COPY_DIRS,
  COPY_FILES,
  COPY_SUBDIRS_AS_IS,
  SKIP_FILES,
  INDEX_LIMITS,
  ABOUT_PORTFOLIO_LIMIT,
};
