'use strict';

const path = require('path');

// ─── 路徑設定 ────────────────────────────────────────────────────────────────
const INPUT_DIR  = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/ValueCafe/en';
const OUTPUT_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/valuecafe';

// ─── 分類設定 ────────────────────────────────────────────────────────────────
// 使用 order.json 排序的分類
const ORDERED_CATEGORIES = [
  'financial-ratios',
  'intrinsic-value',
  'legendary',
  'philosophy',
];

// 依日期排序的分類
const DATE_SORTED_CATEGORIES = [
  'news',
];

// 所有文章分類（用於 worldview.html 隨機抽文）
const ALL_ARTICLE_CATEGORIES = [
  'financial-ratios',
  'intrinsic-value',
  'legendary',
  'news',
  'philosophy',
  'statements',
  'to-beginners',
];

// ─── 直接複製（不需編譯）的資源 ─────────────────────────────────────────────
const COPY_DIRS = [
  'statements',
  'to-beginners',
  'js',
  'images',
  'css',
  'public',
  '.well-known',
];

const COPY_FILES = [
  'style.css',
  'contact.html',
  'robots.txt',
  'llms.txt',
  '_headers',
];

// ─── 不需打包的黑名單 ────────────────────────────────────────────────────────
const SKIP_FILES = new Set([
  'empty.md',
  'components-level1.html',
  'components-level2.html',
]);

// ─── 各分類的 More Resources 最大顯示數量 ────────────────────────────────────
const MORE_RESOURCES_LIMIT = 6;

// ─── index.html 各分類顯示數量 ───────────────────────────────────────────────
const INDEX_LIMITS = {
  'financial-ratios': 6,
  'intrinsic-value' : 6,
  'news'            : 10,
  'philosophy'      : 6,
  'legendary'       : Infinity, // 全部顯示
};

module.exports = {
  INPUT_DIR,
  OUTPUT_DIR,
  ORDERED_CATEGORIES,
  DATE_SORTED_CATEGORIES,
  ALL_ARTICLE_CATEGORIES,
  COPY_DIRS,
  COPY_FILES,
  SKIP_FILES,
  MORE_RESOURCES_LIMIT,
  INDEX_LIMITS,
};
