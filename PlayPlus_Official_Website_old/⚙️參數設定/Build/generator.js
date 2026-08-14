'use strict';

const fs   = require('fs');
const path = require('path');
const { sortByDateDesc } = require('./parser');

// ═══════════════════════════════════════════════════════════════════════════════
// 工具函式
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 讀取 template/source HTML，執行指定替換後寫出到 dest。
 *
 * @param {string}   srcPath     - 來源 HTML 的絕對路徑
 * @param {string}   destPath    - 輸出 .html 的絕對路徑
 * @param {Function} transformer - (htmlString) => htmlString，負責所有替換邏輯
 */
function renderTemplate(srcPath, destPath, transformer) {
  let html = fs.readFileSync(srcPath, 'utf8');
  html = transformer(html);
  fs.mkdirSync(path.dirname(destPath), { recursive: true });
  fs.writeFileSync(destPath, html, 'utf8');
}

/**
 * 在 html 中，將 <!-- XYZ Editor --> 後面緊接的一整個「範本區塊」
 * 替換成 replacer(blockHtml) 的回傳值（可以是多個複製區塊）。
 *
 * @param {string}   html
 * @param {string}   commentLabel  - e.g. 'List Editor'
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
  let blockEnd = nextTagStart;
  let i = nextTagStart;
  const len = html.length;
  let depth = 0;

  while (i < len) {
    if (html[i] !== '<') { i++; continue; }

    // 嘗試匹配 open tag
    const openMatch = html.slice(i).match(new RegExp(`^<${tagName}(?=[\\s>/])`));
    if (openMatch) {
      depth++;
      const gt = html.indexOf('>', i);
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
  let replacement = replacer(templateBlock);

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
// TAGs 替換工具
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 替換 template block 中的 <div class="tag">🟢TAGs</div> 為實際 tag 清單。
 * 多餘的 🟢TAGs slot 會被移除。
 *
 * @param {string} block - HTML 區塊
 * @param {string} tagsStr - 逗號分隔的 tag 字串
 * @returns {string}
 */
function replaceTags(block, tagsStr) {
  const tags = (tagsStr || '').split(',').map(t => t.trim()).filter(Boolean);
  let tagIdx = 0;
  return block.replace(/<div class="tag">🟢TAGs<\/div>/g, () => {
    const tag = tags[tagIdx] || '';
    tagIdx++;
    return tag ? `<div class="tag">${tag}</div>` : '';
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 文章頁面生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 blog 的文章 HTML。
 *
 * 替換清單：
 *   🟢UrlName       → article.id
 *   🟢PageTitle     → head.title
 *   🟢PageDescription → head.description
 *   🟢PageKeywords  → head.keywords
 *   🟢TAGs          → head.tags（逗號分隔，對應各 <div class="tag">）
 *   🟢Date          → head.date
 *   <!-- Content Editor --> 後的區塊 → article.content
 *
 * @param {object} article      - 單篇文章資料
 * @param {string} templatePath - template.html 路徑
 * @param {string} destPath     - 輸出路徑
 */
function generateBlogArticlePage(article, templatePath, destPath) {
  renderTemplate(templatePath, destPath, (html) => {
    // Head meta 替換
    html = html
      .replace(/🟢UrlName/g,         article.id)
      .replace(/🟢PageTitle/g,       article.head['title']       || '')
      .replace(/🟢PageDescription/g, article.head['description'] || '')
      .replace(/🟢PageKeywords/g,    article.head['keywords']    || '')
      .replace(/🟢Date/g,            article.head['date']        || '');

    // TAGs 替換（template 中有多個 <div class="tag">🟢TAGs</div>）
    html = replaceTags(html, article.head['tags'] || '');

    // Content Editor
    html = replaceAndIndentEditorBlock(html, 'Content Editor', article.content);

    return html;
  });
}

/**
 * 生成 portfolio 的文章 HTML。
 *
 * 替換清單：
 *   🟢UrlName          → article.id
 *   🟢PageTitle        → head.title
 *   🟢PageDescription  → head.description
 *   🟢PageKeywords     → head.keywords
 *   🟢PageSubTitle     → head.subtitle
 *   🟢TAGs             → head.tags（逗號分隔）
 *   🟢ArticleForeword  → head.foreword
 *   🟢UrlWebsite       → head.urlwebsite
 *   <!-- GEO Summary Box Editor --> 後的區塊 → 保留原始內容（此區塊由 .md 的 content 提供）
 *   <!-- Content Editor --> 後的區塊 → article.content
 *   confidential=Yes → 保留 <div class="tips"> 保密段落；confidential=No → 移除該段落
 *
 * @param {object} article      - 單篇文章資料
 * @param {string} templatePath - template.html 路徑
 * @param {string} destPath     - 輸出路徑
 */
function generatePortfolioArticlePage(article, templatePath, destPath) {
  renderTemplate(templatePath, destPath, (html) => {
    // Head meta 替換
    html = html
      .replace(/🟢UrlName/g,          article.id)
      .replace(/🟢PageTitle/g,        article.head['title']       || '')
      .replace(/🟢PageDescription/g,  article.head['description'] || '')
      .replace(/🟢PageKeywords/g,     article.head['keywords']    || '')
      .replace(/🟢PageSubTitle/g,     article.head['subtitle']    || '')
      .replace(/🟢ArticleForeword/g,  article.head['foreword']    || '')
      .replace(/🟢UrlWebsite/g,       article.head['urlwebsite']  || '#');

    // TAGs 替換
    html = replaceTags(html, article.head['tags'] || '');

    // Content Editor
    // 移除 markdown 檔內手寫殘留的 tips 區塊（避免與後續插入重複）
    let cleanContent = (article.content || '').replace(/[ \t]*<div class="tips">[\s\S]*?企業內部系統會關係到保密性[\s\S]*?<\/div>\s*<\/div>\s*/g, '');
    html = replaceAndIndentEditorBlock(html, 'Content Editor', cleanContent);

    // Confidential 段落處理（template 內有兩個 <div class="tips">）
    // confidential=No → 移除兩個 tips；confidential=Yes → 保留
    const isConfidential = (article.head['confidential'] || '').trim().toLowerCase() === 'yes';
    const tipsHtml = '<div class="tips">\n\t\t\t\t\t\t\t<div class="column">\n\t\t\t\t\t\t\t\t<p>企業內部系統會關係到保密性，畫面僅以黑白設計稿呈現。</p>\n\t\t\t\t\t\t\t</div>\n\t\t\t\t\t\t</div>';

    // ① 第一個 tips（在 Content Editor 之前的 Banner 區）：用 regex 直接移除或保留
    if (!isConfidential) {
      html = html.replace(/[ \t]*<div class="tips">[\s\S]*?<\/div>[ \t]*\n[ \t]*<\/div>[ \t]*\n?/g, '');
    }

    // ② 第二個 tips：直接在 <div id="oc-images" 前方插入（因原本的標記已被 Content Editor 覆蓋）
    if (isConfidential) {
      const cleanTips = '<div class="tips">\n\t<div class="column">\n\t\t<p>企業內部系統會關係到保密性，畫面僅以黑白設計稿呈現。</p>\n\t</div>\n</div>';
      html = html.replace(/([ \t]*)(<div id="oc-images")/g, (match, p1, p2) => {
        const indentedTips = cleanTips.replace(/\n/g, '\n' + p1);
        return p1 + indentedTips + '\n' + p1 + p2;
      });
    }

    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// 列表頁生成器
// ═══════════════════════════════════════════════════════════════════════════════

const BLOG_TAG_MAP = {
  '設計師邏輯': 'designer',
  '談談數位轉型': 'mindset',
  '釐清需求': 'needs',
  '決策與規劃': 'planning',
  '觀點分享': 'insights',
  '工具與資源應用': 'tools',
  '趨勢觀察': 'trend',
  '其他': 'miscellaneous'
};

const PORTFOLIO_TAG_MAP = {
  '企業內部系統': 'system',
  'SAAS': 'saas',
  '品牌官網': 'official',
  '電商平台': 'ecommerce',
  '內容平台': 'media',
  '餐飲業': 'catering',
  '科技與服務': 'tech',
  '金融服務': 'financial',
  '製造業': 'manufacturing',
  '零售電商': 'retail',
  '電子業': 'electronics',
  '藝術產業': 'art',
  '生技醫療': 'biotech',
  '不動產經營業': 'real-estate',
  '小型專案': 'small-project',
  '中型專案': 'medium-project',
  '大型專案': 'large-project'
};

/**
 * 生成 blog.html 列表頁。
 * 依日期新到舊排列，每筆含 🟢Filter, 🟢UrlName, 🟢TAGs, 🟢PageTitle, 🟢Date。
 *
 * 🟢Filter → 每個 tag 以空格連接（用於前端 isotope 篩選，需轉換成合法 CSS class）
 */
function generateBlogListPage(articles, listHtmlPath, outputPath) {
  renderTemplate(listHtmlPath, outputPath, (html) => {
    html = replaceEditorBlock(html, 'List Editor', (tpl) => {
      return articles.map(a => {
        // 將 tags 轉為 CSS class（使用字典對應，若無對應則去除空白轉小寫）
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        const filterClasses = tags.map(t => BLOG_TAG_MAP[t] || t.replace(/\s+/g, '-').toLowerCase()).join(' ');

        let block = tpl
          .replace(/🟢Filter/g,    filterClasses)
          .replace(/🟢UrlName/g,   a.id)
          .replace(/🟢PageTitle/g, a.head['title'] || '')
          .replace(/🟢Date/g,      a.head['date']  || '');

        // TAGs
        block = replaceTags(block, a.head['tags'] || '');
        return block;
      }).join('\n');
    });
    return html;
  });
}

/**
 * 生成 portfolio.html 列表頁。
 * 依 order.json 排序，每筆含 🟢Filter, 🟢UrlName, 🟢PageTitle, 🟢TAGs, 🟢ListSummary。
 */
function generatePortfolioListPage(articles, listHtmlPath, outputPath) {
  renderTemplate(listHtmlPath, outputPath, (html) => {
    html = replaceEditorBlock(html, 'List Editor', (tpl) => {
      return articles.map(a => {
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        const filterClasses = tags.map(t => PORTFOLIO_TAG_MAP[t] || t.replace(/\s+/g, '-').toLowerCase()).join(' ');

        let block = tpl
          .replace(/🟢Filter/g,       filterClasses)
          .replace(/🟢UrlName/g,      a.id)
          .replace(/🟢PageTitle/g,    a.head['title']        || '')
          .replace(/🟢ListSummary/g,  a.head['list-summary'] || '');

        // TAGs
        block = replaceTags(block, a.head['tags'] || '');
        return block;
      }).join('\n');
    });
    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// index.html 生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 index.html。
 *
 * Editor 標記：
 *   <!-- Portfolios List Editor --> → 作品集卡片列表（前 N 筆）
 *   <!-- Blogs List Editor -->      → 知識筆記卡片列表（前 N 筆）
 *
 * @param {object} siteData - { portfolio: Array, blog: Array }
 * @param {string} srcPath  - 來源 index.html
 * @param {string} destPath - 輸出路徑
 * @param {object} limits   - INDEX_LIMITS
 */
function generateIndexPage(siteData, srcPath, destPath, limits) {
  renderTemplate(srcPath, destPath, (html) => {
    // ── Portfolios List Editor ───────────────────────────────────────────────
    html = replaceEditorBlock(html, 'Portfolios List Editor', (tpl) => {
      return siteData.portfolio.slice(0, limits['portfolio']).map(a => {
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        let block = tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '');

        // TAGs（index.html 裡可能有多個 🟢TAGs slot）
        let tagIdx = 0;
        block = block.replace(/<div class="tag">🟢TAGs<\/div>/g, () => {
          const tag = tags[tagIdx] || '';
          tagIdx++;
          return tag ? `<div class="tag">${tag}</div>` : '';
        });
        return block;
      }).join('\n');
    });

    // ── Blogs List Editor ────────────────────────────────────────────────────
    html = replaceEditorBlock(html, 'Blogs List Editor', (tpl) => {
      return siteData.blog.slice(0, limits['blog']).map(a => {
        let block = tpl
          .replace(/🟢UrlName/g,   a.id)
          .replace(/🟢PageTitle/g, a.head['title'] || '')
          .replace(/🟢Date/g,      a.head['date']  || '');

        // TAGs（blog card 只顯示第一個 tag）
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        let tagIdx = 0;
        block = block.replace(/<div class="tag">🟢TAGs<\/div>/g, () => {
          const tag = tags[tagIdx] || '';
          tagIdx++;
          return tag ? `<div class="tag">${tag}</div>` : '';
        });
        return block;
      }).join('\n');
    });

    return html;
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// about-playplus.html 生成器
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * 生成 about-playplus.html。
 *
 * Editor 標記：
 *   <!-- Portfolios List Editor --> → 作品集卡片列表（前 N 筆）
 *
 * @param {Array}  portfolioArticles - 作品集文章陣列
 * @param {string} srcPath           - 來源 about-playplus.html
 * @param {string} destPath          - 輸出路徑
 * @param {number} limit             - 顯示數量
 */
function generateAboutPage(portfolioArticles, srcPath, destPath, limit) {
  renderTemplate(srcPath, destPath, (html) => {
    html = replaceEditorBlock(html, 'Portfolios List Editor', (tpl) => {
      return portfolioArticles.slice(0, limit).map(a => {
        const tags = (a.head['tags'] || '').split(',').map(t => t.trim()).filter(Boolean);
        let block = tpl
          .replace(/🟢UrlName/g,     a.id)
          .replace(/🟢Name/g,        a.head['name']         || a.head['title'] || '')
          .replace(/🟢ListSummary/g, a.head['list-summary'] || '');

        let tagIdx = 0;
        block = block.replace(/<div class="tag">🟢TAGs<\/div>/g, () => {
          const tag = tags[tagIdx] || '';
          tagIdx++;
          return tag ? `<div class="tag">${tag}</div>` : '';
        });
        return block;
      }).join('\n');
    });
    return html;
  });
}

/**
 * 更新 sitemap.xml 檔案的 Portfolio 與 Blog 區段。
 *
 * @param {string} sitemapPath - sitemap.xml 檔案的絕對路徑
 * @param {Array}  blogSorted  - 已排序的部落格文章列表
 * @param {Array}  portfolioSorted - 已排序的作品集列表
 * @param {string} inputDir    - 輸入目錄的絕對路徑
 */
function generateSitemap(sitemapPath, blogSorted, portfolioSorted, inputDir) {
  if (!fs.existsSync(sitemapPath)) {
    console.warn(`  [Sitemap] 找不到 sitemap.xml: ${sitemapPath}`);
    return;
  }

  const sitemapContent = fs.readFileSync(sitemapPath, 'utf8');
  const portfolioMarker = '<!-- Portfolio -->';
  const blogMarker = '<!-- Blog -->';
  const servicesMarker = '<!-- Services -->';

  const portfolioStart = sitemapContent.indexOf(portfolioMarker);
  const blogStart = sitemapContent.indexOf(blogMarker);
  const servicesStart = sitemapContent.indexOf(servicesMarker);

  if (portfolioStart === -1 || blogStart === -1 || servicesStart === -1) {
    console.warn('  [Sitemap] 找不到 sitemap.xml 中的標記注釋，取消更新');
    return;
  }

  // 1. 解析現有的 lastmod
  const urlRegex = /<url>([\s\S]*?)<\/url>/g;
  const locRegex = /<loc>(.*?)<\/loc>/;
  const lastmodRegex = /<lastmod>(.*?)<\/lastmod>/;

  const existingLastmod = {};
  let match;
  while ((match = urlRegex.exec(sitemapContent)) !== null) {
    const urlBlock = match[1];
    const locMatch = urlBlock.match(locRegex);
    const lastmodMatch = urlBlock.match(lastmodRegex);
    if (locMatch && lastmodMatch) {
      existingLastmod[locMatch[1].trim()] = lastmodMatch[1].trim();
    }
  }

  function formatISO(date) {
    return date.toISOString().replace(/\.\d+Z$/, '+00:00');
  }

  function getOrUpdateLastmod(url, filePath) {
    if (!fs.existsSync(filePath)) {
      return formatISO(new Date());
    }
    const mtime = fs.statSync(filePath).mtime;
    const existingStr = existingLastmod[url];
    if (existingStr) {
      const existingDate = new Date(existingStr);
      if (mtime.getTime() - existingDate.getTime() > 10000) {
        return formatISO(mtime);
      }
      return existingStr;
    }
    return formatISO(mtime);
  }

  // 2. 構建 Portfolio 區塊
  let portfolioBlockContent = `\n<url>\n\t<loc>https://playplus.com.tw/portfolio.html</loc>\n\t<lastmod>${existingLastmod['https://playplus.com.tw/portfolio.html'] || '2025-07-30T08:19:18+00:00'}</lastmod>\n\t<priority>0.70</priority>\n</url>\n`;

  for (const article of portfolioSorted) {
    const url = `https://playplus.com.tw/portfolio/${article.id}.html`;
    const filePath = path.join(inputDir, 'portfolio', article.filename);
    const lastmod = getOrUpdateLastmod(url, filePath);
    portfolioBlockContent += `<url>\n\t<loc>${url}</loc>\n\t<lastmod>${lastmod}</lastmod>\n\t<priority>0.70</priority>\n</url>\n`;
  }

  // 3. 構建 Blog 區塊
  let blogBlockContent = `\n<url>\n\t<loc>https://playplus.com.tw/blog.html</loc>\n\t<lastmod>${existingLastmod['https://playplus.com.tw/blog.html'] || '2025-07-30T08:19:18+00:00'}</lastmod>\n\t<priority>0.70</priority>\n</url>\n`;

  for (const article of blogSorted) {
    const url = `https://playplus.com.tw/blog/${article.id}.html`;
    const filePath = path.join(inputDir, 'blog', article.filename);
    const lastmod = getOrUpdateLastmod(url, filePath);
    blogBlockContent += `<url>\n\t<loc>${url}</loc>\n\t<lastmod>${lastmod}</lastmod>\n\t<priority>0.70</priority>\n</url>\n`;
  }

  // 4. 重組並寫回
  const newSitemapContent =
    sitemapContent.slice(0, portfolioStart + portfolioMarker.length) +
    '\n' + portfolioBlockContent + '\n' +
    sitemapContent.slice(blogStart, blogStart + blogMarker.length) +
    '\n' + blogBlockContent + '\n' +
    sitemapContent.slice(servicesStart);

  fs.writeFileSync(sitemapPath, newSitemapContent, 'utf8');
}

// ═══════════════════════════════════════════════════════════════════════════════

module.exports = {
  renderTemplate,
  replaceEditorBlock,
  replaceAndIndentEditorBlock,
  replaceTags,
  extractBlock,
  generateBlogArticlePage,
  generatePortfolioArticlePage,
  generateBlogListPage,
  generatePortfolioListPage,
  generateIndexPage,
  generateAboutPage,
  generateSitemap,
};
