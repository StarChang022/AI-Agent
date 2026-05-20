"""
business_1_crawler.py
═══════════════════════════════════════════════════════════════════
收集個股情報 Step 1：爬蟲收集資料（純 Python，不需搭配 AI Agent）

流程：
  1. 從關注名單 Google Sheet 讀取股票清單（1 次 API 呼叫）
     - 跳過 TAIEX、TPEx
     - 跳過 google_sheet_business == "xxx" 的股票
  2. 分批並行（aiohttp）爬取各網站情報
     - Google News RSS：台灣財經新聞（最可靠，按股票 ID + 名稱搜尋）
     - FinMind API：公司基本資料（純 JSON，無需 JS）
     - 財報狗：最新分析新聞
     - 自由財經：台灣財經新聞
     - 豐雲學堂 / 鉅亨網：補充分析文章
  2b.【升級】並行爬取每則新聞的內頁全文（通用型萃取器）
     - 所有文章 URL 同時非同步發送，以 ARTICLE_CONCURRENT_LIMIT 限速
     - 每篇最多保留 ARTICLE_MAX_CHARS 字元，避免 AI context 過長
  3. 結果暫存至 Trading/⌚️暫存/for_python/business_database.json
  4. 批次覆寫至各股票對應的 Google Sheet（business 分頁）
═══════════════════════════════════════════════════════════════════
"""

import asyncio
import aiohttp
import json
import os
import re
import sys
import time
import warnings
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import quote

import gspread
from bs4 import BeautifulSoup, XMLParsedAsHTMLWarning
from google.oauth2.service_account import Credentials

# 抑制 BeautifulSoup 解析 RSS XML 時的警告
warnings.filterwarnings("ignore", category=XMLParsedAsHTMLWarning)

# ──────────────────────────────────────────────────────────────
# 路徑設定（相對於本腳本位置）
# ──────────────────────────────────────────────────────────────
BASE_DIR  = Path(__file__).resolve().parents[2]         # Trading/
CACHE_DIR = BASE_DIR / "⌚️暫存" / "for_python"
GCP_JSON  = BASE_DIR / "⚙️參數設定" / "rosy-zoo-447904-j1-a600c9e990ca.json"
DB_PATH   = CACHE_DIR / "business_database.json"

WATCHLIST_URL = (
    "https://docs.google.com/spreadsheets/d/"
    "1MuJgPwiJpjyU8LXevCxUKsbsLPpMT7H9J2wnPcVqIpE"
    "/edit?gid=1951214900#gid=1951214900"
)

CACHE_DIR.mkdir(parents=True, exist_ok=True)

# ──────────────────────────────────────────────────────────────
# 爬蟲設定
# ──────────────────────────────────────────────────────────────
CONCURRENT_LIMIT       = 6     # 同時最多幾支股票並行
NEWS_PER_SOURCE        = 5     # 每個來源最多抓幾則新聞
REQUEST_TIMEOUT        = 20    # 單次請求逾時（秒）
RETRY_TIMES            = 2     # 失敗重試次數
BATCH_SIZE             = 5     # 每批寫入 Google Sheet 的股票數

# ── 內文抓取設定（升級功能）──
ARTICLE_CONCURRENT_LIMIT = 12   # 同時並行抓取內文的請求數
ARTICLE_MAX_CHARS        = 800  # 每篇新聞最多保留字元數（避免 AI token 超量）
ARTICLE_TIMEOUT          = 15   # 內文請求逾時（秒，比列表頁短以提升整體速度）

# 不值得爬取內文的域名（付費牆、redirect、搜尋引擎、SPA 需 JS 渲染等）
SKIP_CONTENT_DOMAINS = {
    "news.google.com",
    "google.com",
    "accounts.google.com",
    "youtube.com",
    "www.youtube.com",
    "twitter.com",
    "x.com",
    "facebook.com",
    "line.me",
    "ptt.cc",
    "news.cnyes.com",    # SPA（需 JS 渲染），純 HTTP GET 只拿到空框架
}

EXCLUDED_IDS = {"TAIEX", "TPEx"}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-TW,zh;q=0.9,en-US;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# ──────────────────────────────────────────────────────────────
# Google Sheets 授權
# ──────────────────────────────────────────────────────────────
SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

def get_gspread_client() -> gspread.Client:
    creds = Credentials.from_service_account_file(str(GCP_JSON), scopes=SCOPES)
    return gspread.authorize(creds)

def parse_sheet_url(url: str) -> Tuple[str, str]:
    """從 Google Sheet URL 解析 (spreadsheet_id, gid)"""
    m_id  = re.search(r"/spreadsheets/d/([a-zA-Z0-9_-]+)", url)
    m_gid = re.search(r"gid=(\d+)", url)
    if not m_id or not m_gid:
        raise ValueError(f"無法解析 URL: {url}")
    return m_id.group(1), m_gid.group(1)

# ──────────────────────────────────────────────────────────────
# 讀取關注名單（僅 1 次 Google Sheets API 呼叫）
# ──────────────────────────────────────────────────────────────
def load_stocks(gc: gspread.Client) -> List[dict]:
    """
    從關注名單 Google Sheet 讀取股票清單，
    跳過 TAIEX、TPEx，以及 google_sheet_business == 'xxx' 的股票。
    """
    ss_id, gid = parse_sheet_url(WATCHLIST_URL)
    sh = gc.open_by_key(ss_id)
    ws = sh.get_worksheet_by_id(int(gid))
    vals = ws.get_all_values()

    if len(vals) < 2:
        print("✗ 關注名單無資料")
        return []

    headers = vals[0]
    required = {"stock_id", "stock_name", "google_sheet_business"}
    for col in required:
        if col not in headers:
            print(f"✗ 關注名單缺少欄位：{col}，目前欄位：{headers}")
            return []

    stocks = []
    for row in vals[1:]:
        d = dict(zip(headers, row))
        sid     = d.get("stock_id", "").strip()
        biz_url = d.get("google_sheet_business", "").strip()

        if not sid:
            continue
        if sid in EXCLUDED_IDS:
            print(f"  ⏭  跳過指數：{sid}")
            continue
        if biz_url.lower() == "xxx" or not biz_url.startswith("https://"):
            print(f"  ⏭  跳過（business=xxx 或無 URL）：{sid} {d.get('stock_name','')}")
            continue

        stocks.append({
            "stock_id":              sid,
            "stock_name":            d.get("stock_name", "").strip(),
            "google_sheet_business": biz_url,
        })

    return stocks

# ──────────────────────────────────────────────────────────────
# 通用 HTTP GET（含重試）
# ──────────────────────────────────────────────────────────────
async def fetch_html(
    session: aiohttp.ClientSession,
    url: str,
    params: Optional[dict] = None,
    retry: int = RETRY_TIMES,
    timeout_sec: int = REQUEST_TIMEOUT,
) -> Optional[str]:
    timeout = aiohttp.ClientTimeout(total=timeout_sec)
    for attempt in range(retry + 1):
        try:
            async with session.get(url, params=params, timeout=timeout, headers=HEADERS) as resp:
                if resp.status == 200:
                    return await resp.text(errors="replace")
                return None
        except (asyncio.TimeoutError, aiohttp.ClientError):
            if attempt < retry:
                await asyncio.sleep(1.5 * (attempt + 1))
            else:
                return None
        except Exception:
            return None

# ──────────────────────────────────────────────────────────────
# 【升級】通用內文萃取器
# ──────────────────────────────────────────────────────────────
def _extract_article_text(html: str, max_chars: int = ARTICLE_MAX_CHARS) -> str:
    """
    通用型新聞內文萃取器。
    策略：
      1. 移除干擾元素 (script, style, header, footer 等)
      2. 找出所有 <p> 或 <div> 內不含其他區塊元素且文字長度 > 20 的段落
      3. 若皆無，則直接取全部純文字並按換行分割
      4. 截取前 max_chars 字元
    """
    if not html:
        return ""
    try:
        soup = BeautifulSoup(html, "html.parser")

        # 移除干擾元素 (注意：不可移除 form，因為許多 ASP.NET 網站的全文都包在 form 裡)
        for tag in soup.find_all(["script", "style", "nav", "header",
                                   "footer", "aside", "figure", "figcaption",
                                   "button", "noscript", "iframe"]):
            tag.decompose()

        paragraphs = []
        # 找尋潛在的文字區塊
        for p in soup.find_all(['p', 'div', 'article', 'section']):
            # 確保該區塊不包含其他大型子區塊 (代表它是最末端的文字容器)
            if not p.find(['p', 'div', 'article', 'section']):
                text = p.get_text(" ", strip=True)
                if len(text) > 20:
                    paragraphs.append(text)

        # Fallback: 若找不到任何末端段落，直接將整頁文字取出
        if not paragraphs:
            raw_text = soup.get_text("\n", strip=True)
            paragraphs = [t.strip() for t in raw_text.split("\n") if len(t.strip()) > 20]

        text = "\n".join(paragraphs)
        return text[:max_chars] if len(text) > max_chars else text
    except Exception:
        return ""

async def fetch_article_content(
    session: aiohttp.ClientSession,
    url: str,
    article_semaphore: asyncio.Semaphore,
    source_url: str = "",
) -> str:
    """
    抓取單篇新聞內頁全文。
    使用 article_semaphore 限制同時連線數，避免觸發反爬機制。

    特別處理 Google News redirect URL：
      - 使用 googlenewsdecoder 解密出原始發布媒體的真實 URL
    """
    from urllib.parse import urlparse
    from googlenewsdecoder import gnewsdecoder

    # 選定實際要爬取的 URL
    fetch_url = url

    try:
        domain = urlparse(url).netloc.lower().replace("www.", "")
    except Exception:
        return ""

    # 如果主 URL 是 Google News redirect，使用 googlenewsdecoder 解密
    if "news.google.com" in domain:
        try:
            decoded = await asyncio.to_thread(gnewsdecoder, url)
            if decoded.get("status") and decoded.get("decoded_url"):
                fetch_url = decoded["decoded_url"]
        except Exception:
            pass

    # 跳過不值得爬的域名
    try:
        final_domain = urlparse(fetch_url).netloc.lower().replace("www.", "")
    except Exception:
        return ""
    if any(skip in final_domain for skip in SKIP_CONTENT_DOMAINS):
        return ""

    async with article_semaphore:
        html = await fetch_html(session, fetch_url, retry=0, timeout_sec=ARTICLE_TIMEOUT)
        return _extract_article_text(html)

async def enrich_news_with_content(
    session: aiohttp.ClientSession,
    news_list: List[dict],
    article_semaphore: asyncio.Semaphore,
) -> List[dict]:
    """
    對 news_list 中每則新聞的 URL 並行發出請求，
    將抓到的內文填入 item["content"] 欄位。
    原 news_list 不改變，回傳填充後的新列表。
    """
    tasks = [
        fetch_article_content(
            session,
            item.get("url", ""),
            article_semaphore,
            source_url=item.get("source_url", ""),   # Google News 實際媒體網域
        )
        for item in news_list
    ]
    contents = await asyncio.gather(*tasks, return_exceptions=True)

    enriched = []
    for item, content in zip(news_list, contents):
        new_item = dict(item)
        if isinstance(content, str) and content.strip():
            new_item["content"] = content
        elif "content" not in new_item:
            new_item["content"] = ""
        enriched.append(new_item)

    return enriched

# ──────────────────────────────────────────────────────────────
# ① Google News RSS：最可靠的新聞來源（返回真實 XML，無 JS）
# ──────────────────────────────────────────────────────────────
async def scrape_google_news_rss(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """
    Google News RSS 搜尋：
      https://news.google.com/rss/search?q={query}&hl=zh-TW&gl=TW&ceid=TW:zh-Hant
    以 stock_id + stock_name 組合查詢，回傳最新財經新聞。

    特別處理：
      - <link> 是 Google 的 redirect URL（無法直接抓內文）
      - <source url> 包含原始發布媒體的網域
      - 一並記錄 source_url，泟 feed_article_content 決定要爬取的實際 URL
    """
    news = []
    query = f"{stock_id} {stock_name}"
    url   = "https://news.google.com/rss/search"
    params = {
        "q":    query,
        "hl":   "zh-TW",
        "gl":   "TW",
        "ceid": "TW:zh-Hant",
    }
    html = await fetch_html(session, url, params=params)
    if not html:
        return news

    soup = BeautifulSoup(html, "html.parser")
    for item in soup.find_all("item")[:NEWS_PER_SOURCE * 2]:
        title_tag = item.find("title")
        link_tag  = item.find("link")
        pub_tag   = item.find("pubdate")
        src_tag   = item.find("source")

        if not title_tag:
            continue

        # Google News title 格式：「文章標題 - 來源媒體」
        raw_title = title_tag.get_text(strip=True)
        parts     = raw_title.rsplit(" - ", 1)
        title     = parts[0].strip()
        source    = parts[1].strip() if len(parts) > 1 else "Google News"

        # link 是 <link> 後面的文字（不是 <a> 標籤）
        link_text = ""
        if link_tag:
            link_text = link_tag.next_sibling
            if link_text:
                link_text = str(link_text).strip()
            else:
                link_text = link_tag.get_text(strip=True)

        pub_date = ""
        if pub_tag:
            pub_raw  = pub_tag.get_text(strip=True)
            pub_date = pub_raw[:16]  # e.g. "Wed, 20 May 2026"

        # 原始發布媒體的網域（用於內文爬取時的搜尋入口）
        source_domain = ""
        if src_tag:
            source_domain = src_tag.get("url", "").strip()

        if len(title) > 5:
            news.append({
                "title":        title,
                "url":          link_text or url,    # Google redirect URL（可點擊用）
                "source_url":   source_domain,        # 實際媒體網域（用於爬內文）
                "source":       source,
                "date":         pub_date,
            })

        if len(news) >= NEWS_PER_SOURCE:
            break

    return news

# ──────────────────────────────────────────────────────────────
# ② FinMind API：公司基本資料（台灣股票，純 JSON）
# ──────────────────────────────────────────────────────────────
FINMIND_BASE = "https://api.finmindtrade.com/api/v4/data"

async def scrape_finmind_company_info(
    session: aiohttp.ClientSession,
    stock_id: str,
) -> Dict:
    """
    從 FinMind 抓取公司基本資訊：
      - TaiwanStockInfo：公司名稱、產業類別、業務描述
    無需 API Token（公開資料集）。
    """
    result = {
        "company_intro":    "",
        "industry":         "",
        "products":         "",
        "market":           "",
    }
    timeout = aiohttp.ClientTimeout(total=REQUEST_TIMEOUT)

    try:
        params = {
            "dataset": "TaiwanStockInfo",
            "data_id": stock_id,
        }
        async with session.get(FINMIND_BASE, params=params, timeout=timeout, headers=HEADERS) as resp:
            if resp.status != 200:
                return result
            data = await resp.json()

        records = data.get("data", [])
        if not records:
            return result

        r = records[0]
        result["company_intro"] = r.get("description", "")
        result["industry"]      = r.get("industry_category", "")
        result["market"]        = r.get("type", "")
        # 產品相關：industry category 可作為業務概述
        if result["industry"]:
            result["products"] = f"產業類別：{result['industry']}"

    except Exception:
        pass

    return result

# ──────────────────────────────────────────────────────────────
# ③ 財報狗：最新分析新聞（/news/ URL 格式）
# ──────────────────────────────────────────────────────────────
async def scrape_statementdog(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """
    財報狗新聞列表：https://statementdog.com/news/latest
    透過搜尋 stock_id 取得相關新聞連結（含 /news/{id} 格式的 URL）。
    """
    news = []
    url  = "https://statementdog.com/news/latest"

    for query in [stock_id, stock_name]:
        html = await fetch_html(session, url, params={"filter_query": query})
        if not html:
            continue

        soup = BeautifulSoup(html, "html.parser")

        for a in soup.find_all("a", href=True):
            href  = a["href"]
            title = a.get_text(strip=True)

            # 財報狗新聞 URL：/news/{數字}
            if re.search(r"/news/\d+", href) and len(title) > 10:
                # 清理標題（財報狗常把日期黏在標題後面）
                clean_title = re.sub(r"\d{4}/\d{2}/\d{2}.*$", "", title).strip()
                date_match  = re.search(r"(\d{4}/\d{2}/\d{2})", title)
                date_str    = date_match.group(1) if date_match else ""

                full_url = href if href.startswith("http") else f"https://statementdog.com{href}"

                news.append({
                    "title":  clean_title or title[:80],
                    "url":    full_url,
                    "source": "財報狗",
                    "date":   date_str,
                })

            if len(news) >= NEWS_PER_SOURCE:
                break

        if news:
            break

    return news[:NEWS_PER_SOURCE]

# ──────────────────────────────────────────────────────────────
# ④ 鉅亨網：台灣財經新聞搜尋（JSON API，直接取摘要）
# ──────────────────────────────────────────────────────────────
async def scrape_cnyes(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """
    鉅亨網個股新聞 API（JSON 格式）：
      https://api.cnyes.com/media/api/v1/newslist/category/tw_stock_news?stk={stock_id}

    鉅亨前端為 SPA（React），內文頁面 news.cnyes.com 需 JS 渲染，
    純 aiohttp GET 只能拿到空 HTML 框架，因此改為直接從列表 API
    的 JSON 欄位（summary / content / description）取摘要，
    填入 content 欄位，省去無效的內頁爬取請求。
    """
    news = []
    # 鉅亨個股新聞列表 API
    api_url = (
        f"https://api.cnyes.com/media/api/v1/newslist/category/tw_stock_news"
        f"?limit=10&page=1&stk={stock_id}"
    )
    timeout = aiohttp.ClientTimeout(total=REQUEST_TIMEOUT)

    try:
        async with session.get(api_url, timeout=timeout, headers=HEADERS) as resp:
            if resp.status == 200:
                data  = await resp.json(content_type=None)
                items = data.get("items", {}).get("data", [])
                for item in items[:NEWS_PER_SOURCE]:
                    title    = item.get("title", "")
                    news_id  = item.get("newsId", "")
                    pub_time = item.get("publishAt", 0)
                    url_     = f"https://news.cnyes.com/news/id/{news_id}" if news_id else ""
                    date_str = ""
                    if pub_time:
                        date_str = datetime.fromtimestamp(pub_time).strftime("%Y/%m/%d")

                    # 直接從 API JSON 取摘要
                    # 優先用 summary（純文字）；若無則 fallback 到 content（HTML-encoded）
                    raw_content = (
                        item.get("summary") or
                        item.get("content") or
                        item.get("description") or
                        ""
                    )
                    # content 欄位為 HTML entity encoded（&lt;p&gt;），需先 unescape 再解析
                    if raw_content:
                        try:
                            import html as _html
                            from bs4 import BeautifulSoup as _BS
                            raw_content = _BS(_html.unescape(raw_content), "html.parser").get_text(" ", strip=True)
                        except Exception:
                            pass
                    content = raw_content[:ARTICLE_MAX_CHARS] if raw_content else ""

                    if title:
                        news.append({
                            "title":   title,
                            "url":     url_,
                            "source":  "鉅亨網",
                            "date":    date_str,
                            "content": content,   # 已在此填入，enrich 階段會跳過（domain 在 SKIP 清單）
                        })
    except Exception:
        pass

    return news

# ──────────────────────────────────────────────────────────────
# ⑤ 豐雲學堂（SinoTrade）：搜尋分析文章
# ──────────────────────────────────────────────────────────────
async def scrape_sinotrade(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """
    豐雲學堂搜尋：https://www.sinotrade.com.tw/richclub/news
    """
    news = []
    for query in [stock_name, stock_id]:
        url  = "https://www.sinotrade.com.tw/richclub/news"
        html = await fetch_html(session, url, params={"q": query})
        if not html:
            continue

        soup = BeautifulSoup(html, "html.parser")

        # 找含有 stock_id 或 stock_name 的文章連結
        for a in soup.find_all("a", href=True):
            title = a.get_text(strip=True)
            href  = a["href"]
            if not href.startswith("http"):
                href = "https://www.sinotrade.com.tw" + href

            if len(title) > 10 and any(
                kw in title for kw in [stock_id, stock_name[:2], "股市", "投資", "分析"]
            ):
                news.append({
                    "title":  title,
                    "url":    href,
                    "source": "豐雲學堂",
                    "date":   "",
                })
            if len(news) >= NEWS_PER_SOURCE:
                break

        if news:
            break

    return news[:NEWS_PER_SOURCE]

# ──────────────────────────────────────────────────────────────
# ⑥ 自由財經：新聞搜尋（補充）
# ──────────────────────────────────────────────────────────────
async def scrape_ltn(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """自由財經搜尋：https://search.ltn.com.tw/list?keyword={query}&type=EC"""
    news = []
    url  = "https://search.ltn.com.tw/list"
    html = await fetch_html(session, url, params={"keyword": stock_name, "type": "EC"})
    if not html:
        html = await fetch_html(session, url, params={"keyword": stock_id, "type": "EC"})
    if not html:
        return news

    soup = BeautifulSoup(html, "html.parser")
    # 自由財經搜尋結果 — 找 ul.list > li 或 class 含 tit/title 的 a
    for a in soup.find_all("a", href=True):
        href  = a["href"]
        title = a.get_text(strip=True)
        if "ltn.com.tw" in href and len(title) > 10 and (
            stock_id in title or stock_name[:2] in title
        ):
            news.append({
                "title":  title,
                "url":    href,
                "source": "自由財經",
                "date":   "",
            })
        if len(news) >= NEWS_PER_SOURCE:
            break
    return news[:NEWS_PER_SOURCE]

# ──────────────────────────────────────────────────────────────
# ⑦ MoneyDJ：個股新聞搜尋
# ──────────────────────────────────────────────────────────────
async def scrape_moneydj(
    session: aiohttp.ClientSession,
    stock_id: str,
    stock_name: str,
) -> List[dict]:
    """
    MoneyDJ 個股新聞：https://www.moneydj.com/KMDJ/News/NewsRealList.aspx?a=TWD:{stock_id}
    """
    news = []
    url = f"https://www.moneydj.com/KMDJ/News/NewsRealList.aspx?a=TWD:{stock_id}"
    html = await fetch_html(session, url)
    if not html:
        return news

    soup = BeautifulSoup(html, "html.parser")
    for a in soup.find_all("a", href=True):
        href = a["href"]
        title = a.get_text(strip=True)
        # 尋找新聞連結，例如 /kmdj/news/newsviewer.aspx?a=...
        if "newsviewer.aspx" in href.lower() and len(title) > 10:
            if not href.startswith("http"):
                full_url = "https://www.moneydj.com" + href
            else:
                full_url = href
                
            news.append({
                "title":  title,
                "url":    full_url,
                "source": "MoneyDJ",
                "date":   "",
            })
            if len(news) >= NEWS_PER_SOURCE:
                break

    return news

# ──────────────────────────────────────────────────────────────
# 彙整單支股票所有來源
# ──────────────────────────────────────────────────────────────
async def scrape_one_stock(
    session: aiohttp.ClientSession,
    stock: dict,
    semaphore: asyncio.Semaphore,
    article_semaphore: asyncio.Semaphore,
) -> Dict:
    """
    並行呼叫各來源爬蟲，取得新聞列表後再並行抓取內文，
    回傳整合後的情報 dict。
    """
    async with semaphore:
        sid  = stock["stock_id"]
        name = stock["stock_name"]
        print(f"  🔍 爬取中：{sid} {name}")

        (
            finmind_data,
            gnews,
            sd_news,
            cnyes_news,
            sinotrade_news,
            ltn_news,
            moneydj_news,
        ) = await asyncio.gather(
            scrape_finmind_company_info(session, sid),
            scrape_google_news_rss(session, sid, name),
            scrape_statementdog(session, sid, name),
            scrape_cnyes(session, sid, name),
            scrape_sinotrade(session, sid, name),
            scrape_ltn(session, sid, name),
            scrape_moneydj(session, sid, name),
            return_exceptions=True,
        )

        # 安全轉換（若爬蟲拋例外則給空值）
        if isinstance(finmind_data,     Exception): finmind_data     = {"company_intro": "", "products": "", "industry": "", "market": ""}
        if isinstance(gnews,            Exception): gnews            = []
        if isinstance(sd_news,          Exception): sd_news          = []
        if isinstance(cnyes_news,       Exception): cnyes_news       = []
        if isinstance(sinotrade_news,   Exception): sinotrade_news   = []
        if isinstance(ltn_news,         Exception): ltn_news         = []
        if isinstance(moneydj_news,     Exception): moneydj_news     = []

        # 彙整新聞（去重標題）
        all_news: List[dict] = []
        seen_titles: set = set()
        for item in (gnews + sd_news + cnyes_news + sinotrade_news + ltn_news + moneydj_news):
            t = item.get("title", "").strip()
            if t and t not in seen_titles and len(t) > 5:
                seen_titles.add(t)
                all_news.append(item)

        # ── Phase 2：並行抓取每則新聞的內頁全文（升級功能）──
        if all_news:
            all_news = await enrich_news_with_content(session, all_news, article_semaphore)
            fetched_count = sum(1 for n in all_news if n.get("content"))
            print(f"    📄 {sid} | 成功抓取內文：{fetched_count}/{len(all_news)} 則")

        company_intro = finmind_data.get("company_intro", "")
        products      = finmind_data.get("products", "")
        industry      = finmind_data.get("industry", "")

        print(f"    ✔ {sid} | 產業：{industry} | 新聞：{len(all_news)} 則")

        return {
            "stock_id":         sid,
            "stock_name":       name,
            "last_updated":     datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "產業類別":          industry,
            "企業營運概況":       company_intro,
            "主力產品與服務":     products,
            "產品營收佔比":       "",   # 需財報數據補充（可由 AI 分析後填入）
            "客戶區域營收佔比":   "",   # 需財報數據補充
            "未來展望":          "",   # 由新聞資訊彙整後人工或 AI 補充
            "潛在風險":          "",   # 由新聞資訊彙整後人工或 AI 補充
            "競爭對手":          "",   # 由新聞資訊彙整後人工或 AI 補充
            "其他":              "",
            "新聞列表":          all_news,   # 每則 item 多了 "content" 欄位
        }

# ──────────────────────────────────────────────────────────────
# 暫存至 business_database.json
# ──────────────────────────────────────────────────────────────
def load_database() -> Dict:
    if DB_PATH.exists():
        try:
            with open(DB_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_database(db: Dict):
    with open(DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)
    print(f"  💾 暫存更新：{DB_PATH.name}")

# ──────────────────────────────────────────────────────────────
# 格式化寫入 Google Sheet
# ──────────────────────────────────────────────────────────────
SHEET_SECTIONS = [
    ("產業類別",        "產業類別"),
    ("企業營運概況",    "企業概況與基本介紹"),
    ("主力產品與服務",  "主力產品與服務（如何賺錢）"),
    ("產品營收佔比",    "產品營收佔比"),
    ("客戶區域營收佔比", "客戶 / 區域營收佔比"),
    ("未來展望",        "未來展望"),
    ("潛在風險",        "潛在風險"),
    ("競爭對手",        "競爭對手"),
    ("其他",            "其他"),
]

def build_sheet_rows(data: dict) -> List[List]:
    """
    將情報 dict 轉為 Google Sheet 的列資料。

    格式：
      第 1 行：大標題（股票名稱 + 更新時間）
      第 2 行：（空行）
      各段落：["【類別】", "內容"]
              ["",         ""]（空行分隔）
      新聞彙整：標題行 + 逐則新聞
    """
    rows: List[List] = []

    header = (
        f"📊 {data['stock_id']} {data['stock_name']}"
        f"　情報更新：{data.get('last_updated', '')}"
    )
    rows.append([header, ""])
    rows.append(["", ""])

    # 各情報段落
    for key, label in SHEET_SECTIONS:
        content = (data.get(key) or "").strip()
        rows.append([f"【{label}】", content if content else "（尚無資料，可搭配 AI Agent 補充）"])
        rows.append(["", ""])

    # 新聞彙整
    news = data.get("新聞列表", [])
    if news:
        rows.append(["【最新情報彙整】", f"共 {len(news)} 則"])
        rows.append(["來源 / 日期", "新聞標題 / 內文摘要"])
        for item in news:
            source  = item.get("source",  "")
            title   = item.get("title",   "")
            url_    = item.get("url",     "")
            date_   = item.get("date",    "")
            content = item.get("content", "").strip()

            # 標題欄：HYPERLINK 公式讓標題可點擊
            safe_title = title.replace('"', "'")
            if url_ and url_.startswith("http") and title:
                link_cell = f'=HYPERLINK("{url_}","{safe_title}")'
            else:
                link_cell = title

            # 若有內文，在標題下方附加摘要（前 120 字）
            if content:
                snippet   = content[:120].replace('"', "'").replace("\n", " ")
                link_cell = link_cell + f"\n📝 {snippet}…"

            label_cell = f"{source}"
            if date_:
                label_cell += f"\n{date_}"

            rows.append([label_cell, link_cell])
        rows.append(["", ""])

    return rows

def write_to_sheet(ws: gspread.Worksheet, data: dict):
    rows     = build_sheet_rows(data)
    last_row = max(len(rows) + 10, 60)

    # 清除舊資料
    ws.batch_clear([f"A1:B{last_row}"])

    # 批次寫入（USER_ENTERED → 公式生效）
    if rows:
        ws.update(range_name="A1", values=rows, value_input_option="USER_ENTERED")

    # 欄寬調整
    try:
        ws.set_column_width(0, 180)   # A 欄：類別標籤
        ws.set_column_width(1, 600)   # B 欄：內容
    except Exception:
        pass

    # 標題列格式
    try:
        ws.format("A1:B1", {
            "textFormat":      {"bold": True, "fontSize": 11},
            "backgroundColor": {"red": 0.18, "green": 0.28, "blue": 0.44},
            "wrapStrategy":    "WRAP",
        })
        # 各段標題（A 欄含「【...】」的列）
        title_rows = [
            i + 1 for i, r in enumerate(rows)
            if r and isinstance(r[0], str) and r[0].startswith("【")
        ]
        if title_rows:
            requests_body = []
            for row_idx in title_rows:
                requests_body.append({
                    "repeatCell": {
                        "range": {
                            "sheetId":          ws.id,
                            "startRowIndex":    row_idx - 1,
                            "endRowIndex":      row_idx,
                            "startColumnIndex": 0,
                            "endColumnIndex":   1,
                        },
                        "cell": {
                            "userEnteredFormat": {
                                "textFormat":      {"bold": True},
                                "backgroundColor": {"red": 0.90, "green": 0.93, "blue": 0.98},
                            }
                        },
                        "fields": "userEnteredFormat(textFormat,backgroundColor)",
                    }
                })
            ws.spreadsheet.batch_update({"requests": requests_body})
    except Exception as e:
        print(f"    ⚠ 格式設定失敗（不影響資料）：{e}")

    print(f"    ✅ 寫入 {len(rows)} 列")

# ──────────────────────────────────────────────────────────────
# Step 1：並行爬取所有股票
# ──────────────────────────────────────────────────────────────
async def step1_fetch_all(stocks: List[dict]) -> Dict:
    """
    分批並行爬取，結果合併至 database dict 並即時存檔。
    - semaphore：限制同時處理的股票數（CONCURRENT_LIMIT）
    - article_semaphore：限制同時抓取內文的請求數（ARTICLE_CONCURRENT_LIMIT）
    回傳完整 db dict。
    """
    db = load_database()

    semaphore         = asyncio.Semaphore(CONCURRENT_LIMIT)
    article_semaphore = asyncio.Semaphore(ARTICLE_CONCURRENT_LIMIT)
    # 連線池略大，供內文抓取使用
    connector = aiohttp.TCPConnector(limit=CONCURRENT_LIMIT + ARTICLE_CONCURRENT_LIMIT, ssl=False)

    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [
            scrape_one_stock(session, stock, semaphore, article_semaphore)
            for stock in stocks
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

    for i, result in enumerate(results):
        sid = stocks[i]["stock_id"]
        if isinstance(result, Exception):
            print(f"  ✗ {sid} 爬取失敗：{result}")
        else:
            db[sid] = result

    save_database(db)
    return db

# ──────────────────────────────────────────────────────────────
# Step 2：批次寫入 Google Sheet
# ──────────────────────────────────────────────────────────────
def step2_write_sheets(stocks: List[dict], db: Dict, gc: gspread.Client):
    """
    每 BATCH_SIZE 支為一批，逐批寫入 Google Sheet。
    批次間停頓 3 秒，避免 Google Sheets API 速率限制。
    """
    total = len(stocks)
    num_batches = (total - 1) // BATCH_SIZE + 1

    for batch_idx, batch_start in enumerate(range(0, total, BATCH_SIZE)):
        batch = stocks[batch_start: batch_start + BATCH_SIZE]
        print(f"\n  📤 寫入批次 {batch_idx + 1}/{num_batches}")

        for stock in batch:
            sid  = stock["stock_id"]
            name = stock["stock_name"]
            url  = stock["google_sheet_business"]
            data = db.get(sid)

            if not data:
                print(f"    ⚠ {sid} {name} 無資料，略過")
                continue

            print(f"\n    [{sid}] {name}")
            try:
                ss_id, gid = parse_sheet_url(url)
                sh = gc.open_by_key(ss_id)
                ws = sh.get_worksheet_by_id(int(gid))
                write_to_sheet(ws, data)
            except Exception as e:
                print(f"    ✗ 寫入失敗：{e}")

        # 批次間等待
        if batch_start + BATCH_SIZE < total:
            print("    ⏸  等待 3 秒…")
            time.sleep(3)

# ──────────────────────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────────────────────
def main():
    start_time = time.time()
    now_str    = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print("=" * 60)
    print(f"🚀 business_1_crawler.py  開始執行  {now_str}")
    print("=" * 60)

    # ── Google Sheets 授權 ──
    print("\n🔐 Google Sheets 授權中…")
    try:
        gc = get_gspread_client()
    except Exception as e:
        print(f"✗ 授權失敗：{e}")
        sys.exit(1)

    # ── 讀取關注名單（僅 1 次 Google Sheets API 呼叫） ──
    print("\n📋 讀取關注名單…")
    stocks = load_stocks(gc)
    if not stocks:
        print("✗ 無有效股票，結束")
        sys.exit(0)

    print(f"  共 {len(stocks)} 支股票待處理：{[s['stock_id'] for s in stocks]}")

    # ── Step 1：並行爬取所有網站 ──
    print(f"\n{'─'*60}")
    print("📡 Step 1：並行爬取各網站情報 + 新聞內文")
    print(f"   股票並發：{CONCURRENT_LIMIT} 支  |  每來源新聞：{NEWS_PER_SOURCE} 則  |  內文並發：{ARTICLE_CONCURRENT_LIMIT} 篇  |  每篇上限：{ARTICLE_MAX_CHARS} 字")
    print(f"{'─'*60}")
    db = asyncio.run(step1_fetch_all(stocks))

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"✅ 全部完成  耗時：{elapsed:.1f} 秒")
    print(f"   執行時間：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   暫存路徑：{DB_PATH}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
