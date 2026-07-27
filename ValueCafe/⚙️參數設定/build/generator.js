'use strict';

const fs   = require('fs');
const path = require('path');
const { randomSample, sortByDateDesc } = require('./parser');
const { MORE_RESOURCES_LIMIT }         = require('./config');
const {
  buildHorizontalBarAds,
  buildBookmarksAds,
  buildCardsAds,
}                                      = require('./ads');

// ═══════════════════════════════════════════════════════════════════════════════
// 工具函式
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 讀取 template.html，執行指定替換後寫出到 dest。
 *
 * @param {string}   templatePath  - 來源 template.html 的絕對路徑
 * @param {string}   destPath      - 輸出 .html 的絕對路徑
 * @param {Function} transformer   - (htmlString) => htmlString，負責所有替換邏輯
 */
function renderTemplate(templatePath, destPath, transformer) {
  let html = fs.readFileSync(templatePath, 'utf8');
  html = transformer(html);
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.writeFileSync(destPath, html, 'utf8');
}

/**
 * 在 html 中，將 <!-- XYZ Editor --> 後面緊接的一整個「範本區塊」
 * 替換成 replacer(blockHtml) 的回傳值（可以是多個複製區塊）。
 *
 * 策略：
 *   找到 <!-- XYZ Editor --> 後，往後抓取下一個完整的「直接子元素」HTML 標籤
 *   作為「單筆範本」，再用 replacer 產生最終 HTML。
 *
 * @param {string}   html
 * @param {string}   commentLabel  - e.g. 'More Resources Editor'
 * @param {Function} replacer      - (templateBlock: string) => string
 * @returns {string}
 */
function replaceEditorBlock(html, commentLabel, replacer) {
  const commentStr = `<!-- ${commentLabel} -->`;
  const idx = html.indexOf(commentStr);
  if (idx === -1) return html;

  // 尋找 comment 之前的縮排字元
  let lineStart = html.lastIndexOf('\n', idx);
  if (lineStart === -1) lineStart = 0;
  else lineStart += 1;
  const baseIndent = html.slice(lineStart, idx).replace(/[^\s]/g, '');

  // 從 comment 結尾開始，找下一個非空白字元（應為 '<'）
  const afterComment = idx + commentStr.length;
  const nextTagStart = html.indexOf('<', afterComment);
  if (nextTagStart === -1) return html;

  // 取得此標籤的 tag 名稱
  const tagMatch = html.slice(nextTagStart).match(/^<([a-zA-Z][a-zA-Z0-9-]*)/);
  if (!tagMatch) return html;
  const tagName = tagMatch[1];

  // 找到對應的關閉標籤（支援巢狀，用計數器）
  let depth = 0;
  let pos   = nextTagStart;
  const openTag  = new RegExp(`<${tagName}[\\s>]`, 'g');
  const closeTag = new RegExp(`</${tagName}>`, 'g');

  // 重新從 nextTagStart 開始用字元掃描
  let blockEnd = nextTagStart;
  let i = nextTagStart;
  const len = html.length;

  while (i < len) {
    if (html[i] !== '<') { i++; continue; }

    // 嘗試匹配 open tag
    const openMatch = html.slice(i).match(new RegExp(`^<${tagName}(?=[\\s>/])`));
    if (openMatch) {
      depth++;
      // 跳過到 '>'
      const gt = html.indexOf('>', i);
      // 自閉合標籤 e.g. <br/>
      if (html.slice(i, gt + 1).trimEnd().endsWith('/>')) {
        depth--;
      }
      i = gt + 1;
      if (depth === 0) { blockEnd = i; break; }
      continue;
    }

    // 嘗試匹配 close tag
    const closeMatch = html.slice(i).match(new RegExp(`^</${tagName}>`));
    if (closeMatch) {
      depth--;
      i += closeMatch[0].length;
      if (depth === 0) { blockEnd = i; break; }
      continue;
    }

    i++;
  }

  const templateBlock = html.slice(nextTagStart, blockEnd);
  let replacement   = replacer(templateBlock);

  if (baseIndent && replacement) {
    replacement = replacement.split('\n<').join('\n' + baseIndent + '<');
  }

  return html.slice(0, idx) + replacement + html.slice(blockEnd);
}

/**
 * 找到 <!-- XYZ Editor --> 後，將緊接的單一 HTML 標籤區塊替換為 content，
 * 並將 content 的每一行（第一行除外）都縮排對齊到與 <!-- XYZ Editor --> 相同的層級。
 */
function replaceAndIndentEditorBlock(html, commentLabel, content) {
  const commentRegex = new RegExp(`<!--\\s*#?\\s*${commentLabel}\\s*-->`);
  const match = html.match(commentRegex);
  if (!match) return html;
  const idx = match.index;
  const commentStr = match[0];

  let lineStart = html.lastIndexOf('\n', idx);
  if (lineStart === -1) lineStart = 0;
  else lineStart += 1;
  const baseIndent = html.slice(lineStart, idx).replace(/[^\s]/g, '');

  const afterComment = idx + commentStr.length;
  const nextTagStart = html.indexOf('<', afterComment);
  if (nextTagStart === -1) return html;

  const tagMatch = html.slice(nextTagStart).match(/^<([a-zA-Z][a-zA-Z0-9-]*)/);
  if (!tagMatch) return html;
  const tagName = tagMatch[1];

  let depth = 0;
  let blockEnd = nextTagStart;
  let i = nextTagStart;
  const len = html.length;

  while (i < len) {
    if (html[i] !== '<') { i++; continue; }
    const openMatch = html.slice(i).match(new RegExp(`^<${tagName}(?=[\\s>/])`));
    if (openMatch) {
      depth++;
      const gt = html.indexOf('>', i);
      if (html.slice(i, gt + 1).trimEnd().endsWith('/>')) depth--;
      i = gt + 1;
      if (depth === 0) { blockEnd = i; break; }
      continue;
    }
    const closeMatch = html.slice(i).match(new RegExp(`^</${tagName}>`));
    if (closeMatch) {
      depth--;
      i += closeMatch[0].length;
      if (depth === 0) { blockEnd = i; break; }
      continue;
    }
    i++;
  }

  const lines = content.split('\n');
  const indentedContent = lines.map((line, index) => {
    if (index === 0) return line;
    return line ? baseIndent + line : line;
  }).join('\n');

  return html.slice(0, nextTagStart) + indentedContent + html.slice(blockEnd);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 各類型文章頁面的 More Resources 區塊生成
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 當 Bookmarks Ads 沒有廣告時，移除整個包含 <!-- Bookmarks Ads --> 的
 * div.column.column-content 容器（含 Recommendation 標題）。
 *
 * 策略：
 *   1. 找到 <!-- Bookmarks Ads --> 的位置
 *   2. 往前掃描，找到最近一個 <div class="column column-content"> 開頭
 *   3. 從該開頭往後以括號計數找到對應的 </div> 結尾
 *   4. 移除整段（含前後換行）
 *
 * @param {string} html
 * @returns {string}
 */
function removeBookmarksSection(html) {
  const commentStr = '<!-- Bookmarks Ads -->';
  const commentIdx = html.indexOf(commentStr);
  if (commentIdx === -1) return html;

  // 往前找最近的 <div class="column column-content">
  const openTag = '<div class="column column-content">';
  let divStart = html.lastIndexOf(openTag, commentIdx);
  if (divStart === -1) return html;

  // 從 divStart 往後用巢狀計數找對應的 </div>
  let depth = 0;
  let i = divStart;
  let divEnd = -1;
  const len = html.length;

  while (i < len) {
    if (html[i] !== '<') { i++; continue; }

    if (html.slice(i).startsWith('<div')) {
      depth++;
      i = html.indexOf('>', i) + 1;
      continue;
    }
    if (html.slice(i).startsWith('</div>')) {
      depth--;
      i += 6;
      if (depth === 0) { divEnd = i; break; }
      continue;
    }
    i++;
  }

  if (divEnd === -1) return html;

  // 移除該區塊（若前面有換行也一起清除，保持縮排整潔）
  let start = divStart;
  if (start > 0 && html[start - 1] === '\n') start--;

  return html.slice(0, start) + html.slice(divEnd);
}


/**
 * 產生 financial-ratios / intrinsic-value / philosophy 文章的 More Resources HTML。
 * 樣板：<!-- More Resources Editor --> 後接一個 <div class="oc-item"> 包含
 *       🟢UrlName 與 🟢PageTitle。
 *
 * @param {string}  templateBlock - 抓到的範本 div.oc-item
 * @param {Array}   pool          - 文章陣列（已排除當前文章）
 * @returns {string}
 */
function buildMoreResourcesStandard(templateBlock, pool) {
  const selected = randomSample(pool, MORE_RESOURCES_LIMIT);
  return selected.map(article => {
    return templateBlock
      .replace(/🟢UrlName/g,   article.id)
      .replace(/🟢PageTitle/g, article.head['title'] || '');
  }).join('\n');
}

/**
 * 產生 legendary 文章的 More Resources HTML（使用 🟢LegendaryName）。
 */
function buildMoreResourcesLegendary(templateBlock, pool) {
  const selected = randomSample(pool, MORE_RESOURCES_LIMIT);
  return selected.map(article => {
    return templateBlock
      .replace(/🟢UrlName/g,       article.id)
      .replace(/🟢LegendaryName/g, article.head['name'] || article.head['title'] || '');
  }).join('\n');
}

/**
 * 產生 news 文章的 More Resources HTML（依日期新到舊，使用 🟢Date 與 🟢TAGs）。
 */
function buildMoreResourcesNews(templateBlock, pool) {
  const sorted   = sortByDateDesc(pool);
  const selected = sorted.slice(0, MORE_RESOURCES_LIMIT);

  return selected.map(article => {
    let block = templateBlock
      .replace(/🟢UrlName/g,   article.id)
      .replace(/🟢PageTitle/g, article.head['title'] || '')
      .replace(/🟢Date/g,      article.head['date']  || '');

    // TAGs: 以逗號分隔，每個 🟢TAGs 換一個 tag
    const tags = (article.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
    // 找到所有 <li class="yolk">🟢TAGs</li> 並依序替換
    let tagIdx = 0;
    block = block.replace(/<li class="yolk">🟢TAGs<\/li>/g, () => {
      const tag = tags[tagIdx] || '';
      tagIdx++;
      return tag ? `<li class="yolk">${tag}</li>` : '';
    });
    return block;
  }).join('\n');
}

// ═══════════════════════════════════════════════════════════════════════════════
// 文章頁面生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 financial-ratios / intrinsic-value / philosophy 的文章 HTML。
 *
 * @param {object} article       - 單篇文章資料
 * @param {string} templatePath  - template.html 路徑
 * @param {string} destPath      - 輸出路徑
 * @param {Array}  allArticles   - 同分類所有文章（用於 more resources）
 */
function generateArticlePage(article, templatePath, destPath, allArticles, category) {
  const pool = allArticles.filter(a => a.id !== article.id);
  const pageRelPath = category ? `${category}/${article.id}.html` : `${article.id}.html`;

  renderTemplate(templatePath, destPath, (html) => {
    // Step 1: More Resources first (before global UrlName replacement)
    html = replaceEditorBlock(html, 'More Resources Editor', (tpl) =>
      buildMoreResourcesStandard(tpl, pool)
    );

    // Step 2: Bookmarks Ads（<!-- Bookmarks Ads --> 區塊，最多 5 則）
    const bookmarkAds = buildBookmarksAds(pageRelPath, 5);
    if (bookmarkAds.length > 0) {
      // 有廣告：填入廣告內容，清除佔位符
      html = replaceEditorBlock(html, 'Bookmarks Ads', () => bookmarkAds.join('\n'));
    } else {
      // 無廣告：移除整個包含 Recommendation 的 div.column.column-content 容器
      html = removeBookmarksSection(html);
    }

    // Head 替換
    html = html.replace(/🟢UrlName/g,          article.id)
               .replace(/🟢PageTitle/g,        article.head['title']       || '')
               .replace(/🟢PageDescription/g,  article.head['description'] || '')
               .replace(/🟢PageKeywords/g,      article.head['keywords']    || '');

    // Hero Editor
    html = replaceAndIndentEditorBlock(html, 'Hero Editor', article.hero);

    // Content Editor
    html = replaceAndIndentEditorBlock(html, 'Content Editor', article.content);



    return html;
  });
}

/**
 * 生成 legendary 的文章 HTML（Hero/Content 相同，More Resources 用 LegendaryName）。
 */
function generateLegendaryArticlePage(article, templatePath, destPath, allArticles) {
  const pool = allArticles.filter(a => a.id !== article.id);
  const pageRelPath = `legendary/${article.id}.html`;

  renderTemplate(templatePath, destPath, (html) => {
    // Step 1: More Resources first (before global UrlName replacement)
    html = replaceEditorBlock(html, 'More Resources Editor', (tpl) =>
      buildMoreResourcesLegendary(tpl, pool)
    );

    html = html.replace(/🟢UrlName/g,          article.id)
               .replace(/🟢PageTitle/g,        article.head['title']       || '')
               .replace(/🟢PageDescription/g,  article.head['description'] || '')
               .replace(/🟢PageKeywords/g,      article.head['keywords']    || '');

    // Hero Editor (legendary 的 Hero Editor 在 template 中沒有包裝，直接插入)
    html = replaceAndIndentEditorBlock(html, 'Hero Editor', article.hero);

    // Content Editor — 必須先填入內容，再搜尋最後一個 div.column.column-content
    html = replaceAndIndentEditorBlock(html, 'Content Editor', article.content);

    // Step 2: Legendary 廣告 — 在最後一個 div.column.column-content 前插入最多 1 則 Horizontal Bar Ads
    // 廣告外框：<div class="column column-content"></div>
    // 必須在 Content 填入後才搜尋，此時文章内容的 div 才實際存在
    const lgAds = buildHorizontalBarAds(pageRelPath, 1, '<div class="column column-content">');
    if (lgAds.length > 0) {
      const markerRe = /<div class="column column-content">/g;
      let lastIdx = -1;
      let m;
      while ((m = markerRe.exec(html)) !== null) {
        lastIdx = m.index;
      }
      if (lastIdx !== -1) {
        html = html.slice(0, lastIdx) + lgAds[0] + '\n' + html.slice(lastIdx);
      }
    }

    return html;
  });
}

/**
 * 生成 news 的文章 HTML。
 */
function generateNewsArticlePage(article, templatePath, destPath, allArticles) {
  const pool = allArticles.filter(a => a.id !== article.id);
  const pageRelPath = `news/${article.id}.html`;

  renderTemplate(templatePath, destPath, (html) => {
    // Step 1: More Resources（含廣告插入）— news 內頁每 3 篇插入 1 則 Cards Ads
    html = replaceEditorBlock(html, 'More Resources Editor', (tpl) => {
      const sorted   = sortByDateDesc(pool);
      const selected = sorted.slice(0, MORE_RESOURCES_LIMIT);

      const itemBlocks = [];
      selected.forEach((item, i) => {
        // 渲染文章區塊（直接用 tpl 作為 oc-item 外框內的內容）
        let block = tpl
          .replace(/🟢UrlName/g,   item.id)
          .replace(/🟢PageTitle/g, item.head['title'] || '')
          .replace(/🟢Date/g,      item.head['date']  || '');

        const tags = (item.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        let tagIdx = 0;
        block = block.replace(/<li class="yolk">🟢TAGs<\/li>/g, () => {
          const tag = tags[tagIdx] || '';
          tagIdx++;
          return tag ? `<li class="yolk">${tag}</li>` : '';
        });
        itemBlocks.push(block);

        // 每 3 篇後插入 1 則廣告（取代原有 <a> 容器，直接以 <div class="oc-item"> 包裹廣告）
        if ((i + 1) % 3 === 0) {
          const adBlocks = buildCardsAds(pageRelPath, 1, '<div class="oc-item">');
          itemBlocks.push(...adBlocks);
        }
      });

      return itemBlocks.join('\n');
    });

    html = html.replace(/🟢UrlName/g,          article.id)
               .replace(/🟢PageTitle/g,        article.head['title']       || '')
               .replace(/🟢PageDescription/g,  article.head['description'] || '')
               .replace(/🟢PageKeywords/g,      article.head['keywords']    || '');

    // Hero Editor
    html = replaceAndIndentEditorBlock(html, 'Hero Editor', article.hero);

    // Content Editor
    html = replaceAndIndentEditorBlock(html, 'Content Editor', article.content);



    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 列表頁生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 financial-ratios.html / intrinsic-value.html / philosophy.html 列表頁。
 * 使用 order.json 排序，每筆含 🟢UrlName, 🟢PageTitle, 🟢Name, 🟢ListSummary。
 */
function generateListPage(articles, listHtmlPath, outputPath, adsPageKey, adsStyle) {
  renderTemplate(listHtmlPath, outputPath, (html) => {
    html = replaceEditorBlock(html, 'List Editor', (tpl) => {
      const items = [];
      articles.forEach((a, i) => {
        const articleHtml = tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢PageTitle/g,   a.head['title']        || '')
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '');
        items.push(articleHtml);

        // 每 3 篇文章後插入 1 則廣告（第 3、6、9... 篇之後）
        if (adsPageKey && (i + 1) % 3 === 0) {
          if (adsStyle === 'horizontal-bar') {
            const adBlocks = buildHorizontalBarAds(adsPageKey, 1);
            items.push(...adBlocks);
          } else if (adsStyle === 'cards') {
            const adBlocks = buildCardsAds(adsPageKey, 1, '<div class="col-md-3">');
            items.push(...adBlocks);
          }
        }
      });
      return items.join('\n');
    });
    return html;
  });
}

/**
 * 生成 legendary.html 列表頁（使用 🟢LegendaryName）。
 */
function generateLegendaryListPage(articles, listHtmlPath, outputPath) {
  renderTemplate(listHtmlPath, outputPath, (html) => {
    html = replaceEditorBlock(html, 'List Editor', (tpl) => {
      return articles.map(a =>
        tpl
          .replace(/🟢UrlName/g,       a.id)
          .replace(/🟢LegendaryName/g, a.head['name'] || a.head['title'] || '')
      ).join('\n');
    });
    return html;
  });
}

/**
 * 生成 news.html 列表頁（依日期新到舊）。
 * 第 1 則用 col-md-6，其餘用 col-md-3。
 */
function generateNewsListPage(articles, listHtmlPath, outputPath) {
  // news.html 中有兩種範本 block（col-md-6 / col-md-3），
  // 透過 <!-- List Editor --> 後接的第一個 div 作為第一則的範本，
  // 第一個 div 後緊接的第二個 div 作為其餘的範本。
  renderTemplate(listHtmlPath, outputPath, (html) => {
    const commentStr = '<!-- List Editor -->';
    const idx = html.indexOf(commentStr);
    if (idx === -1) return html;

    const afterComment = idx + commentStr.length;

    // 尋找 comment 之前的縮排字元
    let lineStart = html.lastIndexOf('\n', idx);
    if (lineStart === -1) lineStart = 0;
    else lineStart += 1;
    const baseIndent = html.slice(lineStart, idx).replace(/[^\s]/g, '');

    // 取出第一個完整 div（col-md-6 範本）
    const firstDivStart = html.indexOf('<', afterComment);
    const firstBlock    = extractBlock(html, firstDivStart);
    const firstBlockEnd = firstDivStart + firstBlock.length;

    // 取出第二個完整 div（col-md-3 範本）
    const secondDivStart = html.indexOf('<', firstBlockEnd);
    const secondBlock    = extractBlock(html, secondDivStart);
    const secondBlockEnd = secondDivStart + secondBlock.length;

    // 依規則：第一則用 firstBlock，其餘用 secondBlock；每 4 篇插入 1 則 Cards 廣告
    const itemBlocks = [];
    articles.forEach((a, i) => {
      const tpl = i === 0 ? firstBlock : secondBlock;
      let block = tpl
        .replace(/🟢UrlName/g,   a.id)
        .replace(/🟢PageTitle/g, a.head['title'] || '')
        .replace(/🟢Date/g,      a.head['date']  || '');

      // TAGs
      const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
      let tagIdx = 0;
      block = block.replace(/<li class="yolk">🟢TAGs<\/li>/g, () => {
        const tag = tags[tagIdx] || '';
        tagIdx++;
        return tag ? `<li class="yolk">${tag}</li>` : '';
      });
      itemBlocks.push(block);

      // 每 4 篇後插入 1 則 Cards 廣告（第 4、8、12... 篇之後）
      if ((i + 1) % 4 === 0) {
        const adBlocks = buildCardsAds('news.html', 1, '<div class="col-md-3">');
        itemBlocks.push(...adBlocks);
      }
    });

    let newItems = itemBlocks.join('\n');

    if (baseIndent && newItems) {
      newItems = newItems.split('\n<').join('\n' + baseIndent + '<');
    }

    return html.slice(0, idx) + newItems + html.slice(secondBlockEnd);
  });
}

/**
 * 從 html[startIdx] 開始，取出一個完整的 HTML 標籤區塊（支援巢狀）。
 * @returns {string}
 */
function extractBlock(html, startIdx) {
  const tagMatch = html.slice(startIdx).match(/^<([a-zA-Z][a-zA-Z0-9-]*)/);
  if (!tagMatch) return '';
  const tagName = tagMatch[1];

  let depth = 0;
  let i     = startIdx;
  const len = html.length;

  while (i < len) {
    if (html[i] !== '<') { i++; continue; }

    const openMatch = html.slice(i).match(new RegExp(`^<${tagName}(?=[\\s>/])`));
    if (openMatch) {
      depth++;
      const gt = html.indexOf('>', i);
      if (html.slice(i, gt + 1).trimEnd().endsWith('/>')) depth--;
      i = gt + 1;
      if (depth === 0) return html.slice(startIdx, i);
      continue;
    }

    const closeMatch = html.slice(i).match(new RegExp(`^</${tagName}>`));
    if (closeMatch) {
      depth--;
      i += closeMatch[0].length;
      if (depth === 0) return html.slice(startIdx, i);
      continue;
    }

    i++;
  }
  return html.slice(startIdx, i);
}

// ═══════════════════════════════════════════════════════════════════════════════
// index.html 生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 index.html。
 *
 * @param {object} siteData - 包含各分類排序後文章的資料物件
 * @param {string} srcPath  - 來源 index.html
 * @param {string} destPath - 輸出路徑
 * @param {object} limits   - INDEX_LIMITS
 */
function generateIndexPage(siteData, srcPath, destPath, limits) {
  renderTemplate(srcPath, destPath, (html) => {
    // ── Financial Ratios List Editor ────────────────────────────────────────
    html = replaceEditorBlock(html, 'Financial Ratios List Editor', (tpl) => {
      return siteData.financialRatios.slice(0, limits['financial-ratios']).map(a =>
        tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '')
      ).join('\n');
    });

    // ── Intrinsic Value List Editor ─────────────────────────────────────────
    html = replaceEditorBlock(html, 'Intrinsic Value List Editor', (tpl) => {
      return siteData.intrinsicValue.slice(0, limits['intrinsic-value']).map(a =>
        tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '')
      ).join('\n');
    });

    // ── News List Editor ────────────────────────────────────────────────────
    html = replaceEditorBlock(html, 'News List Editor', (tpl) => {
      return siteData.news.slice(0, limits['news']).map(a => {
        let block = tpl
          .replace(/🟢UrlName/g,   a.id)
          .replace(/🟢PageTitle/g, a.head['title'] || '')
          .replace(/🟢Date/g,      a.head['date']  || '');
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        let tagIdx = 0;
        block = block.replace(/<li class="yolk">🟢TAGs<\/li>/g, () => {
          const tag = tags[tagIdx] || '';
          tagIdx++;
          return tag ? `<li class="yolk">${tag}</li>` : '';
        });
        return block;
      }).join('\n');
    });

    // ── Philosophy List Editor ──────────────────────────────────────────────
    html = replaceEditorBlock(html, 'Philosophy List Editor', (tpl) => {
      return siteData.philosophy.slice(0, limits['philosophy']).map(a =>
        tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '')
      ).join('\n');
    });

    // ── Legendary List Editor ───────────────────────────────────────────────
    html = replaceEditorBlock(html, 'Legendary List Editor', (tpl) => {
      return siteData.legendary.map(a =>
        tpl
          .replace(/🟢UrlName/g, a.id)
          .replace(/🟢Name/g,    a.head['name'] || a.head['title'] || '')
      ).join('\n');
    });

    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// worldview.html 生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 worldview.html。
 * 從所有分類中隨機抽最多 8 篇，帶入 🟢Url 和 🟢PageTitle。
 *
 * worldview.html 的 🟢Url 代表的是完整的相對路徑（含子目錄），例如 financial-ratios/debt-ratio
 *
 * @param {object} allArticlesMap - { category: Array }
 * @param {string} srcPath
 * @param {string} destPath
 */
function generateWorldviewPage(allArticlesMap, srcPath, destPath) {
  // 建立 { url: 'category/id', title: '...', ... } 的扁平陣列
  const pool = [];
  for (const [category, articles] of Object.entries(allArticlesMap)) {
    for (const a of articles) {
      pool.push({
        url:   `${category}/${a.id}`,
        title: a.head['title'] || '',
      });
    }
  }

  const selected = randomSample(pool, 8);

  renderTemplate(srcPath, destPath, (html) => {
    html = replaceEditorBlock(html, 'More Resources Editor', (tpl) => {
      return selected.map(item =>
        tpl
          .replace(/🟢Url/g,       item.url)
          .replace(/🟢PageTitle/g, item.title)
      ).join('\n');
    });
    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sitemap Generator
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 掃描 outputDir 下所有打包後的 .html 檔案，生成 sitemap.xml 並放在 root 下。
 *
 * Priority 規則：
 *   index.html       → 1.00
 *   worldview.html   → 0.80
 *   contact.html     → 0.80
 *   *\.html (列表頁)  → 0.80（直接在 root 下）
 *   category/*.html  → 0.70（分類內頁 / 層級內頁）
 *
 * @param {string} outputDir      - 打包輸出目錄 (OUTPUT_DIR)
 * @param {object} allArticlesMap - 不再使用，保留為相容性備用
 * @param {string} destPath       - sitemap.xml 輸出路徑（應為 root 下）
 */
function generateSitemap(outputDir, allArticlesMap, destPath) {
  const BASE_URL = 'https://valuecafe.cc';
  const now = new Date().toISOString().replace(/\.\d+Z$/, '+00:00');

  // 避免將 sitemap.xml 本身加入、也排除 template/components 備用頁
  const EXCLUDE_FILES = new Set([
    'sitemap.xml',
    'components-level1.html',
    'components-level2.html',
    '404.html',
  ]);

  /**
   * 遞迴收集 dir 下所有 .html 檔案的相對路徑（相對於 outputDir）。
   * @param {string} dir
   * @param {string} prefix - 相對路徑前綴，初始為 ''
   * @returns {string[]}
   */
  function collectHtmlFiles(dir, prefix) {
    const results = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const relPath = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        results.push(...collectHtmlFiles(path.join(dir, entry.name), relPath));
      } else if (entry.name.endsWith('.html') && !EXCLUDE_FILES.has(entry.name)) {
        results.push(relPath);
      }
    }
    return results;
  }

  // 決定每個 html 的 priority
  function getPriority(relPath) {
    if (relPath === 'index.html') return '1.00';
    if (relPath === 'worldview.html' || relPath === 'contact.html') return '0.80';
    if (!relPath.includes('/')) return '0.80'; // root 下列表頁
    return '0.70'; // 分類內頁
  }

  const htmlFiles = collectHtmlFiles(outputDir, '');

  // index.html 排在最前，其次為 root 層其他頁，再來是分類內頁
  htmlFiles.sort((a, b) => {
    const pa = getPriority(a);
    const pb = getPriority(b);
    if (pa !== pb) return pa > pb ? -1 : 1;
    return a.localeCompare(b);
  });

  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset
\t\txmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
\t\txmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
\t\txsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
\t\thttp://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">
\n`;

  for (const relPath of htmlFiles) {
    const urlPath = relPath === 'index.html' ? '/' : `/${relPath}`;
    const priority = getPriority(relPath);
    xml += `<url>
\t<loc>${BASE_URL}${urlPath}</loc>
\t<lastmod>${now}</lastmod>
\t<priority>${priority}</priority>
</url>
`;
  }

  xml += `\n</urlset>`;

  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.writeFileSync(destPath, xml, 'utf8');
}

// ═══════════════════════════════════════════════════════════════════════════════

module.exports = {
  renderTemplate,
  replaceEditorBlock,
  replaceAndIndentEditorBlock,
  generateArticlePage,
  generateLegendaryArticlePage,
  generateNewsArticlePage,
  generateListPage,
  generateLegendaryListPage,
  generateNewsListPage,
  generateIndexPage,
  generateWorldviewPage,
  extractBlock,
  generateSitemap,
};

