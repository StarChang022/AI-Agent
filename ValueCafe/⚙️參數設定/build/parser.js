'use strict';

const fs   = require('fs');
const path = require('path');

/**
 * 解析單一 .md 檔案，回傳結構化資料。
 *
 * MD 格式：
 *   # Head Editor
 *   **key**: value
 *   ---
 *   # Hero Editor
 *   <html>...
 *   ---
 *   # Content Editor
 *   <html>...
 *
 * @param {string} filePath - 絕對路徑
 * @returns {{ head: Object, hero: string, content: string } | null}
 */
function parseMarkdown(filePath) {
  let raw;
  try {
    raw = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    console.warn(`[parser] 無法讀取檔案: ${filePath}`);
    return null;
  }

  // 正規化換行
  const text = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // ── 切分各個 Section ──────────────────────────────────────────────────────
  // 以 "# XYZ Editor" 為分隔點（不區分大小寫），取出每個 section 的內容
  const sectionRegex = /^#\s+(.+?)\n([\s\S]*?)(?=^#\s+|\Z)/gm;
  const sections = {};
  let match;
  while ((match = sectionRegex.exec(text + '\n# END\n')) !== null) {
    const name = match[1].trim();
    const body = match[2].trim();
    sections[name] = body;
  }

  // ── 解析 Head Editor ──────────────────────────────────────────────────────
  const headRaw = sections['Head Editor'] || '';
  const head = {};
  // 格式：**key**: value（可能跨行，但實務上都是單行）
  const headLineRegex = /^\*\*([^*]+)\*\*:[ \t]*(.*)$/gm;
  let hm;
  while ((hm = headLineRegex.exec(headRaw)) !== null) {
    const key   = hm[1].trim().toLowerCase();
    const value = hm[2].trim();
    head[key] = value;
  }

  // ── Hero / Content ────────────────────────────────────────────────────────
  // 去掉首尾的 "---" 分隔線
  const cleanSection = (str) =>
    str.replace(/^---\s*\n?/, '').replace(/\n?---\s*$/, '').trim();

  const hero    = cleanSection(sections['Hero Editor']    || '');
  const content = cleanSection(sections['Content Editor'] || '');

  return { head, hero, content };
}

/**
 * 讀取指定目錄下所有 .md 檔案（排除黑名單），解析後回傳陣列。
 *
 * @param {string} dirPath   - 目錄絕對路徑
 * @param {Set}    skipFiles - 不處理的檔名集合
 * @returns {Array<{ filename: string, id: string, head: Object, hero: string, content: string }>}
 */
function parseCategory(dirPath, skipFiles = new Set()) {
  let files;
  try {
    files = fs.readdirSync(dirPath);
  } catch (e) {
    console.warn(`[parser] 無法讀取目錄: ${dirPath}`);
    return [];
  }

  const results = [];
  for (const filename of files) {
    if (!filename.endsWith('.md'))      continue;
    if (skipFiles.has(filename))       continue;
    if (filename === 'empty.md')       continue;

    const filePath = path.join(dirPath, filename);
    const parsed   = parseMarkdown(filePath);
    if (!parsed) continue;

    // filename 當備用 id（去掉 .md）
    const fallbackId = path.basename(filename, '.md');
    const id = parsed.head['id'] || fallbackId;

    results.push({ filename, id, ...parsed });
  }
  return results;
}

/**
 * 讀取 order.json，回傳 id 陣列。
 *
 * @param {string} orderPath - order.json 的絕對路徑
 * @returns {string[]}
 */
function parseOrderJson(orderPath) {
  try {
    const raw = fs.readFileSync(orderPath, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    console.warn(`[parser] 無法讀取 order.json: ${orderPath}`);
    return [];
  }
}

/**
 * 依 order.json 的順序排列文章。
 * 不在 order 裡的文章會附加在最後。
 *
 * @param {Array}    articles  - parseCategory() 的回傳值
 * @param {string[]} orderIds  - parseOrderJson() 的回傳值
 * @returns {Array}
 */
function sortByOrder(articles, orderIds) {
  const map = new Map(articles.map(a => [a.id, a]));
  const sorted = [];
  for (const id of orderIds) {
    if (map.has(id)) {
      sorted.push(map.get(id));
      map.delete(id);
    }
  }
  // 剩餘未在 order.json 內的
  for (const a of map.values()) {
    sorted.push(a);
  }
  return sorted;
}

/**
 * 依日期（head.date 或 head['date']）新到舊排序。
 *
 * @param {Array} articles
 * @returns {Array}
 */
function sortByDateDesc(articles) {
  return [...articles].sort((a, b) => {
    const da = a.head['date'] || '';
    const db = b.head['date'] || '';
    return db.localeCompare(da);
  });
}

/**
 * 從陣列隨機取樣最多 n 個元素（不重複）。
 *
 * @param {Array}  arr
 * @param {number} n
 * @returns {Array}
 */
function randomSample(arr, n) {
  const copy = [...arr];
  const result = [];
  while (result.length < n && copy.length > 0) {
    const idx = Math.floor(Math.random() * copy.length);
    result.push(copy.splice(idx, 1)[0]);
  }
  return result;
}

module.exports = {
  parseMarkdown,
  parseCategory,
  parseOrderJson,
  sortByOrder,
  sortByDateDesc,
  randomSample,
};
