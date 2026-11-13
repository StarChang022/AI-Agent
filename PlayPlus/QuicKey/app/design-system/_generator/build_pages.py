import re, os, time

# 每次 build 都會變的版本號，加在 CSS / JS 的 <link>/<script src> 後面當
# cache-busting query string。file:// 直接開啟的靜態頁面，瀏覽器有時會把
# design-tokens.css / design-search-index.js 這種被所有頁面共用的檔案快取
# 住，改完之後單純重新整理看不到最新樣式；網址帶上版本號能強制瀏覽器當成
# 新資源重抓，不用再教使用者用強制重新整理。
BUILD_VER = str(int(time.time()))

MS_DEMO_HTML = r"""          <div class="field dd-wrap" id="ms-demo">
            <label id="ms-demo-label">費用類別（多選，點擊試試）</label>
            <div class="input-shell ms-box" tabindex="0" role="combobox" aria-haspopup="listbox" aria-expanded="false" aria-labelledby="ms-demo-label">
              <span class="ms-chips"></span>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="1.8" aria-hidden="true" style="flex-shrink:0;"><path d="M6 9l6 6 6-6"/></svg>
            </div>
            <div class="dd-panel" role="listbox" aria-multiselectable="true">
              <div class="dd-opt ms-opt hi" role="option" aria-selected="true" data-v="交通"><span class="ms-check"><svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg></span>交通</div>
              <div class="dd-opt ms-opt hi" role="option" aria-selected="true" data-v="材料"><span class="ms-check"><svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg></span>材料</div>
              <div class="dd-opt ms-opt" role="option" aria-selected="false" data-v="服務費"><span class="ms-check"><svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg></span>服務費</div>
              <div class="dd-opt ms-opt" role="option" aria-selected="false" data-v="其他"><span class="ms-check"><svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg></span>其他</div>
            </div>
            <script>
            (function(){
              var wrap=document.getElementById('ms-demo'), box=wrap.querySelector('.ms-box'), chips=wrap.querySelector('.ms-chips');
              var X='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>';
              function render(){
                var sel=[].slice.call(wrap.querySelectorAll('.ms-opt.hi')).map(function(o){return o.dataset.v;});
                chips.innerHTML=sel.length?sel.map(function(v){return '<span class="ms-chip" data-v="'+v+'">'+v+X+'</span>';}).join(''):'<span class="ms-placeholder">選擇類別</span>';
              }
              function setOpen(o){wrap.classList.toggle('open',o); box.setAttribute('aria-expanded',o?'true':'false');}
              box.addEventListener('focus',function(){setOpen(true);});
              box.addEventListener('blur',function(){setTimeout(function(){setOpen(false);},150);});
              box.addEventListener('mousedown',function(e){ if(document.activeElement===box && !e.target.closest('.ms-chip')){e.preventDefault(); setOpen(!wrap.classList.contains('open'));} });
              wrap.querySelectorAll('.ms-opt').forEach(function(o){
                o.addEventListener('mousedown',function(e){e.preventDefault(); var on=!o.classList.contains('hi'); o.classList.toggle('hi',on); o.setAttribute('aria-selected',on); render();});
              });
              chips.addEventListener('mousedown',function(e){
                var c=e.target.closest('svg'); if(!c) return; e.preventDefault(); e.stopPropagation();
                var v=c.parentNode.dataset.v, o=wrap.querySelector('.ms-opt[data-v="'+v+'"]'); o.classList.remove('hi'); o.setAttribute('aria-selected','false'); render();
              });
              render();
            })();
            </script>
          </div>
"""

STAT_CARD_CSS = r"""  .stat-card{width:220px; display:grid; grid-template-columns:auto 1fr; grid-template-rows:auto auto 1fr; column-gap:10px; background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-card-lg); padding:var(--space-md) 18px 0; box-shadow:var(--shadow-card); overflow:hidden;}
  .stat-card .stat-top{grid-row:1 / 3; padding-top:2px;}
  .stat-card .stat-icon{display:block; width:24px; height:24px; color:var(--stat-c);}
  .stat-card .stat-icon svg{width:24px; height:24px; stroke:currentColor; stroke-width:1.8;}
  .stat-card .stat-label{font-size:13px; font-weight:600; letter-spacing:.02em; color:var(--stat-label);}
  .stat-card .stat-value{font-size:24px; font-weight:700; line-height:1.2; margin-top:2px; white-space:nowrap; color:var(--stat-value); font-variant-numeric:tabular-nums;}
  .stat-card .stat-wave{grid-column:1 / -1; align-self:end; height:48px; margin:var(--space-md) -18px 0; background:linear-gradient(90deg, color-mix(in srgb, var(--stat-c) 12%, transparent), color-mix(in srgb, var(--stat-c) 85%, transparent)); -webkit-mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 56' preserveAspectRatio='none'%3E%3Cpath d='M0 48 C18 46 26 30 44 32 S66 46 82 42 104 30 118 36 136 46 150 36 184 12 200 20 L200 56 L0 56Z'/%3E%3C/svg%3E") 0 0 / 100% 100% no-repeat; mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 56' preserveAspectRatio='none'%3E%3Cpath d='M0 48 C18 46 26 30 44 32 S66 46 82 42 104 30 118 36 136 46 150 36 184 12 200 20 L200 56 L0 56Z'/%3E%3C/svg%3E") 0 0 / 100% 100% no-repeat;}
  .stat-card:nth-child(even) .stat-wave{-webkit-mask-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 56' preserveAspectRatio='none'%3E%3Cpath d='M0 44 C16 40 28 26 46 30 S70 48 90 42 110 26 128 30 146 44 162 38 180 18 200 26 L200 56 L0 56Z'/%3E%3C/svg%3E"); mask-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 56' preserveAspectRatio='none'%3E%3Cpath d='M0 44 C16 40 28 26 46 30 S70 48 90 42 110 26 128 30 146 44 162 38 180 18 200 26 L200 56 L0 56Z'/%3E%3C/svg%3E");}
  .stat-primary{--stat-c:var(--primary-500); --stat-value:var(--primary-600); --stat-label:var(--primary-700);}
  .stat-warning{--stat-c:var(--warning); --stat-value:var(--status-review); --stat-label:var(--warning-text);}
  .stat-info{--stat-c:var(--info); --stat-value:var(--info-strong); --stat-label:var(--info-text);}
  .stat-danger{--stat-c:var(--danger); --stat-value:var(--danger); --stat-label:var(--danger-text);}
"""

HERE = os.path.dirname(os.path.abspath(__file__))
# 預設直接讀本資料夾的 _source_design.html、輸出到上一層 design-system/；
# 需要改路徑時用環境變數 QDS_SRC / QDS_OUT 覆寫。
SRC = os.environ.get("QDS_SRC", os.path.join(HERE, "_source_design.html"))
OUT = os.environ.get("QDS_OUT", os.path.dirname(HERE))
os.makedirs(OUT, exist_ok=True)

s = open(SRC, encoding="utf-8").read()
style = re.search(r'<style>(.*?)</style>', s, re.S).group(1)
# 移除舊版獨立的 nav.toc / .brand 樣式 —— 分頁式文件的側邊欄現在直接用
# .side-nav-demo / .sn-item 元件本身，不再需要另一套只給文件用的側欄樣式。
style = re.sub(r'\n\s*nav\.toc\{.*?\n\s*nav\.toc a\.sub\{[^\n]*\n', '\n', style, flags=re.S)
style = style.replace('    nav.toc{display:none;}\n', '')

# 字級字重：每一列的標籤與範例字垂直置中（原本對齊 baseline，大小字級差太多時看起來歪）
style = style.replace('.type-row{display:flex; align-items:baseline;', '.type-row{display:flex; align-items:center;')

# KPI 卡：改成白底＋彩色圖示/數字＋底部橫向漸層波形（明亮版），四色沿用狀態語意
style = style.replace('    --stat-primary-bg:var(--primary-solid); --stat-neutral-bg:var(--slate);\n    --stat-dark-bg:var(--ink); --stat-warning-bg:var(--warning);\n',
    '    --stat-dark-bg:var(--ink);\n    --warning-text:#b45309; --info-strong:#0284c7; --info-text:#0369a1; --danger-text:#b91c1c;\n')
_a = style.index('  .stat-card{width:220px;')
_b = style.index('\n', style.index('  .stat-warning{background:var(--stat-warning-bg);}')) + 1
style = style[:_a] + STAT_CARD_CSS + style[_b:]

def get_section(sid):
    m = re.search(r'(<section id="%s">.*?</section>)' % sid, s, re.S)
    return m.group(1)

def strip_section(block):
    b = re.sub(r'^<section id="[a-z0-9]+">\s*', '', block)
    b = re.sub(r'</section>\s*$', '', b)
    return b

principles = get_section("principles")
principles = principles.replace('        <li><strong>不炫技</strong>：避免大範圍漸層、大 hero、插畫、pastel 卡片色。</li>\n', """        <li><strong>視覺清晰優先</strong>：資訊層級一眼可辨（標題 → 數字 → 說明），任何裝飾都不能干擾閱讀。</li>
        <li><strong>間距有邏輯</strong>：只用間距 tokens（4/8/12/16/20/24/32/40），關係越近間距越小；同層級元素間距一致，不為單一畫面微調。</li>
        <li><strong>對齊</strong>：同一區塊的文字、圖示、欄位共用對齊線；文字靠左、金額數字靠右。</li>
        <li><strong>一致</strong>：同一種元件在每一頁長得一樣，同一種狀態永遠用同一組顏色與圖示。</li>
        <li><strong>同列等高</strong>：並排在同一列的元件高度一致（按鈕與輸入框、KPI 卡、內容卡片），內容長短不同時由容器撐齊，不讓卡片高低不一。</li>
""")
density = get_section("density")
colors = get_section("colors")
typography = get_section("typography")
spacing = get_section("spacing")
radius = get_section("radius")
shadow = get_section("shadow")
components = re.search(r'<section id="components">(.*?)</section>', s, re.S).group(1)
dashboard_inner = re.search(r'<section id="dashboard">(.*?)</section>', s, re.S).group(1)

# Dashboard 拆頁：把「側邊導覽/頂欄/KPI 卡/圖表色票/待處理清單/圖例/清單列/
# 卡頭小篩選/強調卡片」這些各自獨立可重用的元件，從 Dashboard 頁面拆出去放進
# 「元件」分類各自成頁（比照 Button/Card 等其他元件），Dashboard 頁本身改成
# 「組裝範本」，用這些元件實際拼出一個畫面，用來確認元件組合起來的樣子。
_dash_parts = re.split(r'(<h3>.*?</h3>)', dashboard_inner, flags=re.S)
DASH_NAV_H3, DASH_NAV_BODY = _dash_parts[1], _dash_parts[2]
DASH_TOPBAR_H3, DASH_TOPBAR_BODY = _dash_parts[3], _dash_parts[4]
DASH_KPI_H3, DASH_KPI_BODY = _dash_parts[5], _dash_parts[6]
DASH_CHART_H3, DASH_CHART_BODY = _dash_parts[7], _dash_parts[8]
DASH_ACTIONLIST_H3, DASH_ACTIONLIST_BODY = _dash_parts[9], _dash_parts[10]
DASH_LEGEND_H3, DASH_LEGEND_BODY = _dash_parts[11], _dash_parts[12]
DASH_SKELETON_H3, DASH_SKELETON_BODY = _dash_parts[13], _dash_parts[14]
# 上方組裝範本已經是真的 banner-soft 了，這裡不用再放一次示意用的 .demo 區塊；
# 側邊導覽現在是 sn-item/side-nav-demo，跟已移除的舊版 nav.toc 斷點邏輯無關。
DASH_SKELETON_BODY = re.sub(r'\s*<div class="demo">\s*<div class="banner-soft">.*?</div>\s*</div>', '', DASH_SKELETON_BODY, flags=re.S)
def _kpi_markup(html):
    html = html.replace('stat-card stat-warning', 'stat-card stat-danger').replace('stat-card stat-neutral', 'stat-card stat-warning').replace('stat-card stat-dark', 'stat-card stat-info')
    html = re.sub(r'(<div class="stat-value">[^<]*</div>)(\n\s*</div>)', r'\1\n          <div class="stat-wave" aria-hidden="true"></div>\2', html)
    return html.replace('<span class="stat-icon"><svg', '<span class="stat-icon" aria-hidden="true"><svg')
DASH_KPI_H3 = DASH_KPI_H3.replace('KPI 卡（實色）', 'KPI 卡')
DASH_KPI_BODY = _kpi_markup(DASH_KPI_BODY)
DASH_KPI_BODY = re.sub(r'<p class="note">四色固定順序.*?</p>', '<p class="note">白底卡片＋彩色線條圖示、標籤與數字，底部用由淺到深的橫向漸層波形（<code>stat-wave</code>）帶出亮度；波形只是裝飾，不代表真實資料。四種顏色沿用狀態語意，不新增色相：<code>primary</code> 品牌綠（本月核心指標）、<code>warning</code> 琥珀（待處理，同「簽核中」）、<code>info</code> 藍（比率/彙總）、<code>danger</code> 紅（逾期等需要留意）。數字用 24px 粗體（同 <code>currency</code> 字級）中間色、標籤用同色系較深一階，確保白底上的對比；同一列的 KPI 卡等高。</p>', DASH_KPI_BODY, flags=re.S)
DASH_SKELETON_BODY = DASH_SKELETON_BODY.replace('（沿用 <code>nav.toc</code> 同一斷點邏輯）', '（比照側邊導覽既有的收合斷點邏輯）')

architecture = get_section("architecture")
# 補上「新增 UI 前」最優先要問的一題：PrimeVue 有沒有對應元件。原本只在部分
# 元件頁最上方用 pv_note 提過一句，這裡把它正式列進檢查清單第一條，全站統一。
architecture = architecture.replace(
    '<h3>新增 UI 前檢查清單</h3>\n      <ul class="rules">\n        <li>需要的顏色',
    '<h3>新增 UI 前檢查清單</h3>\n      <ul class="rules">\n        <li>PrimeVue 有沒有對應元件？有 → 以 PrimeVue 元件為基礎調整（顏色/間距已由 <code>presets/quickey.ts</code> 對齊主色），不重新造一個；PrimeVue 沒有對應元件，才自製共用元件——本文件「元件」分類下大多數頁面，就是 PrimeVue 沒有對應項目、或需要自製共用元件時的參考</li>\n        <li>需要的顏色'
)
architecture += """
      <h3>站內關聯連結</h3>
      <ul class="rules">
        <li>抽屜裡的關聯紀錄（例如「對應支出」「對應請款單」）用真正的站內連結，不做成純按鈕；一般點擊在同分頁跳轉，Cmd/Ctrl/中鍵可另開分頁。</li>
        <li>關聯連結要和網址狀態同步（例如 <code>?open=...</code>）：從一個抽屜跳到另一頁抽屜後，瀏覽器上一頁要能回到原本開著的抽屜。</li>
        <li>檔案、PDF、外部網站才另開新分頁；站內資料關聯預設同分頁，避免堆出多個工作分頁。</li>
      </ul>
"""
a11y = get_section("a11y")
notes = get_section("notes")

parts = re.split(r'(<h3>.*?</h3>)', components, flags=re.S)
buttons_block = parts[1] + parts[2]
basic_input_block = parts[3] + parts[4]
advanced_input_block = parts[5] + parts[6]
# 費用類別（多選）原本是靜態畫面點不開，換成可互動的 MultiSelect 示範
_ms_a = advanced_input_block.index('          <div class="field">\n            <label>費用類別（多選）</label>')
_ms_b = advanced_input_block.index('          <div class="field dd-wrap" id="ac-demo">')
advanced_input_block = advanced_input_block[:_ms_a] + MS_DEMO_HTML + advanced_input_block[_ms_b:]
# Select 與 DatePicker 已獨立成「Select & DatePicker」頁，Input 頁移除舊的靜態示範
_sd_a = advanced_input_block.index('          <div class="field dd-wrap" id="select-demo">')
_sd_b = advanced_input_block.index('          <div class="field">\n            <label>搜尋</label>')
advanced_input_block = advanced_input_block[:_sd_a] + advanced_input_block[_sd_b:]
advanced_input_block = advanced_input_block.replace('<code>select / date-picker / icon-field / multi-select / autocomplete</code>', '<code>icon-field / multi-select / autocomplete</code>')
advanced_input_block = advanced_input_block.replace('Select / Date-picker 點擊會展開選單/小月曆，AutoComplete', 'Select 與 DatePicker 見 <a href="design-select-date.html">Select &amp; DatePicker</a> 頁。AutoComplete')
upload_block = parts[7] + parts[8]
card_block = parts[9] + parts[10]
# 簽核進度已獨立成 Timeline 元件頁，Card 頁不再示範
card_block = card_block.replace('\n        <div class="card-nested"><div class="card-title">簽核進度</div><div class="card-body">送出 → 主管審核 → 財務發放</div></div>', '')
badge_status_block = """<h3>Status Badge — <code>status-badge</code></h3>
      <div class="demo">
        <div class="demo-row">
          <span class="status-badge" style="color:var(--status-draft);background:var(--status-draft-bg)">草稿</span>
          <span class="status-badge" style="color:var(--status-review);background:var(--status-review-bg)">簽核中</span>
          <span class="status-badge" style="color:var(--status-rejected);background:var(--status-rejected-bg)">駁回</span>
          <span class="status-badge" style="color:var(--status-approved);background:var(--status-approved-bg)">已核銷</span>
          <span class="status-badge" style="color:var(--status-paid);background:var(--status-paid-bg)">已發放</span>
          <span class="status-badge" style="color:#ffffff;background:var(--status-voided)">已作廢</span>
        </div>
      </div>
      <p class="note">對應報帳單的 6 種核銷狀態，每種顏色固定專屬，不可挪用做其他語意或狀態以外的標記。</p>"""

badge_tag_block = """<h3>Tag — <code>tag</code></h3>
      <div class="demo">
        <div class="demo-row">
          <span class="tag tag-default">一般標記</span>
          <span class="tag tag-danger">超支警示</span>
        </div>
      </div>
      <p class="note"><code>Tag</code>（對應 PrimeVue <code>&lt;Tag&gt;</code>）是附加在資料上的一般語意標記，例如 BudgetsView 的超支警示用 <code>severity="danger"</code>。</p>"""

badge_chip_block = """<h3>Category Chip — <code>category-chip</code></h3>
      <div class="demo">
        <div class="demo-row">
          <span class="chip">材料</span><span class="chip">交通</span><span class="chip">服務費</span>
        </div>
      </div>
      <p class="note"><code>category-chip</code> 是分類本身，統一灰底、不做強調變體，用途與 <code>Tag</code> 不同：chip 代表分類，Tag 是附加的語意標記。</p>"""
tab_block = parts[13] + parts[14]
alert_block = parts[15] + parts[16]
table_block = parts[17] + parts[18]
dialog_block = parts[19] + parts[20]
empty_block_full = parts[21] + parts[22]
m = re.search(r'(<table style="margin-top:var\(--space-xl\);">.*)', empty_block_full, re.S)
spec_table = m.group(1)
empty_block = empty_block_full[:m.start()]

##############################################################################
# EXTRA CSS
##############################################################################
EXTRA_CSS = r"""
  /* ==== checkbox / radio / toggle switch ==== */
  .checkbox-row, .radio-row{display:flex; align-items:center; gap:8px; font-size:14px; color:var(--ink); margin-bottom:10px;}
  .checkbox-row input[type=checkbox]{appearance:none; -webkit-appearance:none; width:18px; height:18px; box-sizing:border-box; border:1.5px solid var(--hairline-strong); border-radius:6px; background:var(--canvas); cursor:pointer; flex-shrink:0; transition:background-color .15s ease, border-color .15s ease, box-shadow .15s ease;}
  .checkbox-row input[type=checkbox]:hover{border-color:var(--slate);}
  .checkbox-row input[type=checkbox]:checked{border-color:var(--primary-solid); background-color:var(--primary-solid); background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 12 10' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1.5 5.2 4.4 8 10.5 1.5' fill='none' stroke='white' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E"); background-position:center; background-repeat:no-repeat; background-size:12px 10px;}
  .checkbox-row input[type=checkbox]:indeterminate{border-color:var(--primary-solid); background-color:var(--primary-solid); background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 12 10' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M2 5h8' fill='none' stroke='white' stroke-width='2.2' stroke-linecap='round'/%3E%3C/svg%3E"); background-position:center; background-repeat:no-repeat; background-size:12px 10px;}
  .checkbox-row input[type=checkbox]:focus-visible{outline:2px solid var(--primary-solid); outline-offset:2px;}
  .checkbox-row input[type=checkbox]:disabled{border-color:var(--hairline); background-color:var(--surface-soft); cursor:not-allowed;}
  .radio-row input[type=radio]{width:18px; height:18px; accent-color:var(--primary-solid); cursor:pointer; flex-shrink:0;}
  .toggle{position:relative; display:inline-block; width:40px; height:24px; flex-shrink:0;}
  .toggle input{opacity:0; width:0; height:0; position:absolute;}
  .toggle .slider{position:absolute; inset:0; background:var(--hairline-strong); border-radius:var(--radius-full); transition:background-color .15s ease; cursor:pointer;}
  .toggle .slider::before{content:""; position:absolute; width:18px; height:18px; left:3px; top:3px; background:#fff; border-radius:50%; transition:transform .15s ease; box-shadow:var(--shadow-sm);}
  .toggle input:checked + .slider{background:var(--primary-solid);}
  .toggle input:checked + .slider::before{transform:translateX(16px);}
  .toggle-row{display:flex; align-items:center; gap:10px; font-size:14px; color:var(--slate);}

  /* ==== input 狀態：disabled / invalid / help ==== */
  .field input:disabled, .field .input-shell.is-disabled{background:var(--surface-soft); color:var(--muted-soft); cursor:not-allowed; border-color:var(--hairline);}
  .field input:disabled::placeholder{color:var(--muted-soft);}
  .field input.is-invalid, .field .input-shell.is-invalid{border-color:var(--danger);}
  .field input.is-invalid:focus, .field .input-shell.is-invalid:focus-within{box-shadow:0 0 0 3px rgba(220,38,38,.12);}
  .field .help-msg{font-size:12px; color:var(--muted); margin-top:-2px;}
  .field .error-msg{font-size:12px; color:var(--danger); margin-top:-2px; display:flex; align-items:center; gap:4px;}
  .field .error-msg svg{width:13px; height:13px; stroke:var(--danger); flex-shrink:0;}

  /* ==== textarea ==== */
  .field textarea{font-family:var(--font-sans); font-size:14px; color:var(--ink); background:var(--canvas); border:1.5px solid var(--hairline); border-radius:var(--radius-control); padding:12px 14px; resize:vertical; min-height:88px; transition:border-color .15s ease, box-shadow .15s ease;}
  .field textarea:hover{border-color:var(--hairline-strong);}
  .field textarea:focus{outline:none; border-color:var(--primary-solid); box-shadow:0 0 0 3px var(--primary-100);}
  .field textarea::placeholder{color:var(--muted-soft);}

  /* ==== input group（前綴/後綴，如金額的 NT$） ==== */
  .input-group{display:flex; align-items:stretch; width:240px; background:var(--canvas); border:1.5px solid var(--hairline); border-radius:var(--radius-control); overflow:hidden; transition:border-color .15s ease, box-shadow .15s ease;}
  .input-group:focus-within{border-color:var(--primary-solid); box-shadow:0 0 0 3px var(--primary-100);}
  .input-group .addon{display:flex; align-items:center; padding:0 14px; background:var(--surface); color:var(--muted); font-size:14px; font-weight:600; flex-shrink:0;}
  .input-group .addon:first-child{border-right:1.5px solid var(--hairline);}
  .input-group .addon:last-child{border-left:1.5px solid var(--hairline);}
  .field .input-group input, .input-group input{flex:1; min-width:0; border:none; border-radius:0; box-shadow:none; background:transparent;}
  .field .input-group input:focus{outline:none; box-shadow:none;}

  /* ==== MultiSelect 下拉選項（勾選框） ==== */
  .ms-chips{display:flex; flex-wrap:wrap; gap:6px; flex:1; min-width:0;}
  .ms-placeholder{color:var(--muted-soft);}
  .ms-opt{display:flex; align-items:center; gap:10px;}
  .ms-check{width:16px; height:16px; border-radius:var(--radius-xs); border:1.5px solid var(--hairline-strong); background:var(--canvas); display:flex; align-items:center; justify-content:center; flex-shrink:0; box-sizing:border-box;}
  .ms-check svg{width:12px; height:12px; stroke:var(--on-primary); visibility:hidden;}
  .ms-opt.hi .ms-check{background:var(--primary-solid); border-color:var(--primary-solid);}
  .ms-opt.hi .ms-check svg{visibility:visible;}

  /* ==== 表單版型（vertical / horizontal / inline） ==== */
  .form-pattern{background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-card-lg); padding:var(--space-lg); width:320px;}
  .form-pattern .fp-title{font-size:14px; font-weight:600; color:var(--ink); margin-bottom:var(--space-md);}
  .form-pattern.vertical .field{width:100%; margin-bottom:var(--space-md);}
  .form-pattern.horizontal .h-row{display:flex; align-items:center; gap:var(--space-md); margin-bottom:var(--space-md);}
  .form-pattern.horizontal .h-row label{width:56px; flex-shrink:0; font-size:14px; font-weight:600; color:var(--ink);}
  .form-pattern.horizontal .h-row input{flex:1; min-width:0; font-family:var(--font-sans); font-size:14px; color:var(--ink); background:var(--canvas); border:1.5px solid var(--hairline); border-radius:var(--radius-control); padding:12px 14px; transition:border-color .15s ease, box-shadow .15s ease;}
  .form-pattern.horizontal .h-row input:hover{border-color:var(--hairline-strong);}
  .form-pattern.horizontal .h-row input:focus{outline:none; border-color:var(--primary-solid); box-shadow:0 0 0 3px var(--primary-100);}
  .form-pattern.horizontal .h-row input::placeholder{color:var(--muted-soft); opacity:1;}
  .form-pattern.inline{display:flex; align-items:flex-end; gap:var(--space-sm); width:auto;}
  .form-pattern.inline .field{width:160px;}
  .form-pattern.horizontal, .form-pattern.vertical{width:320px;}

  /* ==== button 補充：severity / outlined / rounded / group / split / loading ==== */
  .btn-success{background:var(--success); color:#fff; box-shadow:none;}
  .btn-success:hover{filter:brightness(.94);}
  .btn-info{background:var(--info); color:#fff; box-shadow:none;}
  .btn-info:hover{filter:brightness(.94);}
  .btn-outlined{background:transparent; border:1.5px solid currentColor;}
  .btn-outlined.btn-success{color:var(--success); background:transparent;}
  .btn-outlined.btn-info{color:var(--info); background:transparent;}
  .btn-group{display:inline-flex; border-radius:var(--radius-full); overflow:hidden; box-shadow:var(--shadow-primary);}
  .btn-group .btn{border-radius:0; box-shadow:none;}
  .btn-group .btn + .btn{border-left:1px solid rgba(255,255,255,.25);}
  .btn-split{display:inline-flex; border-radius:var(--radius-full); overflow:hidden; box-shadow:var(--shadow-primary);}
  .btn-split .btn{border-radius:0; box-shadow:none;}
  .btn-split .btn-caret{background:var(--primary-solid); color:#fff; border:none; padding:12px 14px; cursor:pointer; border-left:1px solid rgba(255,255,255,.3); display:flex; align-items:center;}
  .btn-split .btn-caret:hover{background:var(--primary-600);}
  .btn.is-loading{opacity:.7; cursor:progress;}
  .btn.is-loading svg{animation:spin 0.8s linear infinite;}
  @keyframes spin{to{transform:rotate(360deg);}}

  /* ==== pagination ==== */
  .pagination{display:flex; align-items:center; gap:2px;}
  .pagination button{width:30px; height:30px; border:none; background:none; border-radius:var(--radius-sm); font-size:13px; color:var(--slate); cursor:pointer; display:flex; align-items:center; justify-content:center; font-family:var(--font-sans); transition:background-color .15s ease, color .15s ease;}
  .pagination button:hover:not(.active):not([disabled]){background:var(--surface-soft);}
  .pagination button.active{background:var(--primary-solid); color:#fff; font-weight:600;}
  .pagination button[disabled]{color:var(--muted-soft); cursor:not-allowed;}
  .pagination svg{width:14px; height:14px; stroke:currentColor;}

  /* ==== table 補充：排序 / 篩選 / 凍結欄 / 展開 / 分組 / 頭像 / 進度 / 驗證圖示 ==== */
  .table-toolbar{display:flex; justify-content:space-between; align-items:center; margin-bottom:var(--space-sm); gap:var(--space-md);}
  table.interactive th{cursor:pointer; user-select:none; white-space:nowrap;}
  table.interactive th .sort-icon{display:inline-flex; margin-left:4px; vertical-align:middle; opacity:.45; width:12px; height:12px;}
  table.interactive th:hover .sort-icon{opacity:1;}
  table.interactive td.expand-cell{width:28px; text-align:center; cursor:pointer; color:var(--muted);}
  table.interactive td.expand-cell svg{width:14px; height:14px; transition:transform .15s ease;}
  table.interactive tr.expanded td.expand-cell svg{transform:rotate(90deg);}
  table.interactive td.frozen, table.interactive th.frozen{position:sticky; left:0; background:var(--canvas); box-shadow:2px 0 4px rgba(15,23,42,.04);}
  table.interactive tr{transition:background-color .12s ease;}
  table.interactive tr:hover td{background:var(--surface-soft);}
  .avatar-sm{width:26px; height:26px; border-radius:50%; background:var(--primary-100); color:var(--primary-700); display:inline-flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; flex-shrink:0;}
  .group-header{display:flex; align-items:center; gap:8px; padding:10px 14px; background:var(--surface); font-size:13px; font-weight:600; color:var(--ink);}
  .progress-bar{width:100px; height:6px; background:var(--surface-soft); border-radius:var(--radius-full); overflow:hidden; display:inline-block; vertical-align:middle;}
  .progress-bar .fill{height:100%; background:var(--success); border-radius:var(--radius-full);}
  .verified-icon{width:16px; height:16px; stroke-width:2; vertical-align:middle;}
  .verified-icon.yes{stroke:var(--success);}
  .verified-icon.no{stroke:var(--danger);}

  /* ==== 卡頭小篩選下拉（例如「本日/本週」） ==== */
  .filter-select{display:inline-flex; align-items:center; gap:6px; padding:7px 12px; border:1px solid var(--hairline); border-radius:var(--radius-sm); font-size:13px; color:var(--slate); cursor:pointer; background:var(--canvas); transition:border-color .15s ease;}
  .filter-select:hover{border-color:var(--hairline-strong);}
  .filter-select svg{width:14px; height:14px; stroke:var(--muted); flex-shrink:0;}

  /* ==== 清單列（含頭像/金額，如交易紀錄） ==== */
  .tx-row{display:flex; align-items:center; gap:10px; padding:10px 0; border-bottom:1px solid var(--hairline); font-size:14px; cursor:pointer; transition:background-color .12s ease; margin:0 -10px; padding-left:10px; padding-right:10px; border-radius:var(--radius-sm);}
  .tx-row:hover{background:var(--surface-soft);}
  .tx-row:last-child{border-bottom:none;}
  .tx-row > div{flex:1; min-width:0;}
  .tx-row .tx-name{flex:1; color:var(--ink); font-weight:500;}
  .tx-row .tx-sub{font-size:12px; color:var(--muted);}
  .tx-row .tx-amount{font-variant-numeric:tabular-nums; font-weight:600;}
  .tx-row .tx-amount.neg{color:var(--danger);}
  .tx-row .tx-amount.pos{color:var(--success);}

  /* ==== Timeline（簽核進度）：狀態圖示＋細連線＋右側文字，狀態色表達結果；寬度跟隨容器、不包卡片 ==== */
  .timeline{list-style:none; margin:0; padding:0;}
  .tl-demo-grid{display:grid; grid-template-columns:repeat(auto-fit, minmax(260px, 1fr)); gap:var(--space-xl) var(--space-xxl); align-items:start;}
  .tl-demo-grid .demo-label{font-size:12px; font-weight:600; color:var(--muted); margin-bottom:var(--space-sm);}
  .timeline .tl-item{position:relative; display:flex; gap:12px; padding-bottom:var(--space-md);}
  .timeline .tl-item:last-child{padding-bottom:0;}
  .timeline .tl-item::before{content:""; position:absolute; left:11px; top:24px; bottom:0; width:2px; background:var(--hairline);}
  .timeline .tl-item:last-child::before{display:none;}
  /* 實心圓圖示：完成綠、進行中橘、駁回紅、未開始空心灰框；完成的路段連線為綠 */
  .timeline .tl-icon{flex-shrink:0; display:inline-flex; align-items:center; justify-content:center; width:24px; height:24px; box-sizing:border-box; border-radius:50%; background:var(--canvas); border:1.5px solid var(--hairline-strong); color:#fff;}
  .timeline .tl-icon svg{width:12px; height:12px; display:block; stroke-width:3;}
  .timeline .pending .tl-icon svg{display:none;}
  .timeline .approved .tl-icon{background:var(--status-paid); border-color:var(--status-paid);}
  .timeline .current .tl-icon{background:var(--status-review); border-color:var(--status-review);}
  .timeline .rejected .tl-icon{background:var(--status-rejected); border-color:var(--status-rejected);}
  .timeline .approved::before{background:var(--status-paid);}
  .timeline .tl-content{flex:1; min-width:0;}
  .timeline .tl-head{display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:2px;}
  .timeline .tl-title{font-size:14px; font-weight:500; color:var(--ink);}
  .timeline .pending .tl-title{color:var(--muted);}
  .timeline .tl-status{font-size:12px; color:var(--muted); flex-shrink:0;}
  .timeline .tl-meta{font-size:12px; color:var(--muted); font-variant-numeric:tabular-nums;}
  .timeline .tl-comment{margin-top:6px; padding:8px; border-radius:var(--radius-xs); font-size:12px; line-height:1.45; background:var(--surface); color:var(--ink);}
  .timeline .approved .tl-status{color:var(--status-paid);}
  .timeline .rejected .tl-status{color:var(--status-rejected);}
  .timeline .current .tl-status{color:var(--status-review);}
  .timeline .rejected .tl-comment{background:var(--status-rejected-bg); color:var(--status-rejected);}

  /* ==== Dashboard 元件互動效果補充：KPI 卡、待處理清單列、頂欄搜尋/大頭貼
     這幾個原本是純展示，沒有 hover/focus 回饋，在真實頁面上都是可點擊的
     元件（KPI 卡可鑽取明細、清單列可點開內容、大頭貼是個人選單入口），
     補上跟其他元件一致的互動回饋。 ==== */
  .stat-card{cursor:pointer; transition:transform .12s ease, box-shadow .12s ease;}
  .stat-card:hover{transform:translateY(-2px); box-shadow:0 10px 24px rgba(15,23,42,.16);}
  .action-list .ar-row{cursor:pointer; margin:0 -10px; padding-left:10px; padding-right:10px; border-radius:var(--radius-sm); transition:background-color .12s ease;}
  .action-list .ar-row:hover{background:var(--surface-soft);}
  .avatar{cursor:pointer; transition:box-shadow .12s ease;}
  .avatar:hover{box-shadow:0 0 0 3px var(--primary-100);}
  .tb-search{transition:box-shadow .15s ease;}
  .tb-search:focus-within{box-shadow:0 0 0 3px var(--primary-100);}

  /* ==== 強調用卡片（CTA/提醒） ==== */
  .highlight-card{background:var(--stat-dark-bg); color:#fff; border-radius:var(--radius-card-lg); padding:var(--space-lg);}
  .highlight-card h4{font-size:16px; font-weight:600; margin:0 0 6px;}
  .highlight-card p{font-size:13px; opacity:.85; margin:0 0 var(--space-md); line-height:1.5;}
  .highlight-card .btn-primary{background:#fff; color:var(--ink); box-shadow:none;}
  .highlight-card .btn-primary:hover{background:var(--surface);}

  /* ==== 頁面間導覽（分頁式文件用；側邊欄/按鈕直接沿用文件自己定義的元件） ==== */
  nav.doc-sidenav{position:sticky; top:0; height:100vh; overflow-y:auto; flex-shrink:0;}
  .sn-brand-sub{display:block; font-size:12px; font-weight:400; color:var(--muted-soft); margin-top:2px;}
  .doc-pager{display:flex; justify-content:space-between; margin-top:var(--space-xxl); padding-top:var(--space-lg); border-top:1px solid var(--hairline);}
  .doc-pager .btn{text-decoration:none;}
  .index-grid{display:grid; grid-template-columns:repeat(auto-fill, minmax(220px,1fr)); gap:var(--space-md); margin-top:var(--space-lg);}
  .index-card{display:block; background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-card); padding:var(--space-lg); text-decoration:none; transition:border-color .15s ease, box-shadow .15s ease;}
  .index-card:hover{border-color:var(--primary-solid); box-shadow:var(--shadow-card);}
  .index-card .ic-title{font-size:16px; font-weight:600; color:var(--ink); margin-bottom:4px;}
  .index-card .ic-desc{font-size:13px; color:var(--muted); line-height:1.5;}
  @media (max-width:800px){
    nav.doc-sidenav{display:none;}
  }

  /* ==== 關鍵字搜尋（跟收合按鈕同一行，放在頂欄） ==== */
  .sn-search{position:relative; width:280px; max-width:100%;}
  .sn-search-input{width:100%; box-sizing:border-box; padding:8px 12px; font-size:13px; font-family:inherit; color:var(--ink); background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-sm); outline:none; transition:border-color .15s ease;}
  .sn-search-input::placeholder{color:var(--muted-soft);}
  .sn-search-input:focus{border-color:var(--primary-solid);}
  .sn-search-results{position:absolute; top:calc(100% + 6px); left:0; right:0; max-height:360px; overflow-y:auto; background:var(--canvas); border:1px solid var(--hairline-strong); border-radius:var(--radius-sm); box-shadow:0 8px 24px rgba(0,0,0,.14); z-index:50;}
  .sn-search-item{display:block; padding:8px 12px; text-decoration:none; border-bottom:1px solid var(--hairline);}
  .sn-search-item:last-child{border-bottom:none;}
  .sn-search-item:hover, .sn-search-item.active{background:var(--surface-soft);}
  .sn-search-item .ssi-title{font-size:13px; font-weight:600; color:var(--ink);}
  .sn-search-item .ssi-page{font-size:11px; font-weight:400; color:var(--muted-soft); margin-left:6px;}
  .sn-search-item .ssi-snippet{font-size:12px; color:var(--muted); margin-top:2px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;}
  .sn-search-empty{padding:10px 12px; font-size:12px; color:var(--muted-soft);}
  .sn-search-results mark.sn-hl{background:rgba(0,179,159,.22); color:inherit; border-radius:2px; padding:0 1px;}

  /* ==== 頂欄：收合按鈕 + 關鍵字搜尋放同一行 ==== */
  .doc-topbar{display:flex; align-items:center; gap:var(--space-md); margin-bottom:var(--space-lg);}

  /* ==== 側邊欄收合按鈕（參考 Freya 左上角漢堡選單） ==== */
  .nav-toggle{width:36px; height:36px; flex-shrink:0; display:inline-flex; align-items:center; justify-content:center; border:1px solid var(--hairline); border-radius:var(--radius-sm); background:var(--canvas); color:var(--slate); cursor:pointer; padding:0; transition:background-color .15s ease, border-color .15s ease, color .15s ease;}
  .nav-toggle:hover{background:var(--surface-soft); border-color:var(--hairline-strong); color:var(--ink);}
  .nav-toggle svg{display:block;}
  /* 側邊欄收合改用寬度收合（而非 display:none），搭配 overflow-x:hidden
     裁切內層固定寬度的 .sn-inner，做出滑入滑出的效果；.sn-inner 寬度不變，
     所以收合過程中文字不會被擠壓換行，只是被裁切掉。 */
  nav.doc-sidenav{overflow-x:hidden; transition:width .22s ease, border-color .22s ease; view-transition-name:sidenav;}
  nav.doc-sidenav .sn-inner{width:var(--sidenav-w); flex-shrink:0;}
  html.nav-collapsed nav.doc-sidenav{width:0; border-right-color:transparent;}

  /* ==== 換頁過場（View Transitions API）：讓分頁式文件切換頁面時不要有
     整頁瞬間跳動的感覺，改成淡入淡出。尚未支援此 API 的瀏覽器會自動退回
     原本的直接切換，不影響任何功能。 ==== */
  @media (prefers-reduced-motion: no-preference){
    @view-transition{
      navigation: auto;
    }
  }

  /* ==== 兩欄排列（元件較多的頁面用，參考 Freya UI Kit 頁面的左右分欄） ==== */
  .col-layout{display:grid; grid-template-columns:1fr 1fr; align-items:start; gap:var(--space-xl);}
  .col-layout .col{min-width:0;}
  .col-layout .col > h3:first-child{margin-top:0;}
  @media (max-width:1000px){
    .col-layout{grid-template-columns:1fr;}
  }
  /* ==== Dashboard 組裝範本（版型示意用） ==== */
  .dash-template .dash-body{flex:1; min-width:0; display:flex; flex-direction:column;}
  .dash-template .topbar-demo{flex-shrink:0;}
  .dash-page{padding:var(--space-xl); display:flex; flex-direction:column; gap:var(--space-md);}
  .dash-page-head{display:flex; align-items:center; justify-content:space-between; gap:var(--space-md); flex-wrap:wrap; margin-bottom:var(--space-xs);}
  .dash-page-title{font-size:20px; font-weight:600; color:var(--ink); line-height:1.3;}
  .dash-page-actions{display:flex; align-items:center; gap:var(--space-sm);}
  .dash-page-actions .btn{padding:9px 16px;}
  .dash-template .kpi-grid{grid-template-columns:repeat(4, minmax(0, 1fr));}
  .dash-template .kpi-grid .stat-card{width:auto;}
  .dash-page{container-type:inline-size;}
  /* KPI 永遠整列等分：寬度不夠放 4 張時改 2×2，不出現 3＋1 的破列 */
  @container (max-width:860px){.dash-template .kpi-grid{grid-template-columns:repeat(2, minmax(0, 1fr));}}
  .dash-row{display:grid; grid-template-columns:2fr 1fr; gap:var(--space-md); align-items:stretch;}
  .dash-panel{background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-card-lg); padding:var(--space-lg); min-width:0; display:flex; flex-direction:column;}
  .dash-panel-head{display:flex; align-items:center; justify-content:space-between; gap:var(--space-sm); min-height:32px; margin-bottom:var(--space-sm);}
  .dash-panel-title{font-size:16px; font-weight:600; color:var(--ink); display:flex; align-items:center; gap:8px;}
  .dash-panel-link{font-size:13px; font-weight:600; color:var(--primary-text); text-decoration:none;}
  .dash-panel-link:hover{text-decoration:underline;}
  .dash-panel table{margin-top:0;}
  .dash-panel td.num, .dash-panel th.num{text-align:right; font-variant-numeric:tabular-nums;}
  .bar-chart{flex:1; min-height:180px; display:flex; align-items:flex-end; gap:var(--space-sm); border-bottom:1px solid var(--chart-grid); margin-top:var(--space-sm);}
  .bar-group{flex:1; height:100%; display:flex; align-items:flex-end; justify-content:center; gap:4px;}
  .bar-group .bar{width:16px; border-radius:4px 4px 0 0;}
  .bar-labels{display:flex; gap:var(--space-sm); margin-top:6px;}
  .bar-labels span{flex:1; text-align:center; font-size:12px; color:var(--muted);}
  .legend.legend-row{flex-direction:row; flex-wrap:wrap; gap:var(--space-md);}
  @media (max-width:1100px){.dash-template > .side-nav-demo{display:none;}}
  @media (max-width:900px){.dash-row{grid-template-columns:1fr;}}

  /* ==== Dashboard 組裝範本：互動層 ==== */
  .dash-template{position:relative;}
  .dash-pop{position:relative;}
  .dash-menu{display:none; position:absolute; right:0; top:calc(100% + 8px); min-width:200px; background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-control); box-shadow:var(--shadow-float); padding:6px; z-index:15;}
  .dash-menu-wide{width:300px;}
  .dash-pop.open .dash-menu{display:block;}
  .dash-menu > button{display:block; width:100%; text-align:left; padding:9px 12px; border:none; background:none; border-radius:var(--radius-sm); font-family:inherit; font-size:14px; color:var(--ink); cursor:pointer; transition:background-color .12s ease;}
  .dash-menu > button:hover, .dash-menu > button:focus-visible{background:var(--surface-soft); outline:none;}
  .dash-menu > button.sel{background:var(--primary-50); color:var(--primary-text); font-weight:600;}
  .dash-menu-head{display:flex; align-items:center; justify-content:space-between; padding:6px 12px 8px; font-size:12px; font-weight:600; color:var(--muted);}
  .dash-link-btn{border:none; background:none; padding:0; font-family:inherit; font-size:12px; font-weight:600; color:var(--primary-text); cursor:pointer;}
  .dash-link-btn:hover{text-decoration:underline;}
  .notif-item{position:relative; line-height:1.45;}
  .notif-item small{display:block; font-size:12px; color:var(--muted-soft); margin-top:2px;}
  .dash-menu > button.notif-item.unread{padding-left:24px;}
  .notif-item.unread::before{content:""; position:absolute; left:10px; top:16px; width:6px; height:6px; border-radius:50%; background:var(--primary-solid);}
  .dash-template .btn-icon-only{position:relative;}
  .dash-dot{position:absolute; top:7px; right:8px; width:8px; height:8px; border-radius:50%; background:var(--danger); border:2px solid var(--canvas);}
  .dash-dot[hidden]{display:none;}
  button.avatar{border:none; padding:0; font-family:inherit;}
  button.filter-select{font-family:inherit;}
  .dash-page-actions .filter-select, .dash-page-actions > .btn{height:40px; box-sizing:border-box;}
  .dash-page-actions .dash-menu{min-width:140px;}
  .dash-template .stat-card:focus-visible{outline:2px solid var(--primary-solid); outline-offset:2px;}
  .dash-panel.flash{animation:dashFlash 1.4s ease;}
  @keyframes dashFlash{0%{box-shadow:0 0 0 0 var(--primary-200);}15%{box-shadow:0 0 0 4px var(--primary-200);}100%{box-shadow:0 0 0 0 transparent;}}
  .bar-chart{position:relative;}
  .bar-group .bar{cursor:pointer; transition:height .3s ease, opacity .12s ease;}
  .bar-group .bar:hover, .bar-group .bar:focus-visible{opacity:.75; outline:none;}
  .dash-tip{position:absolute; transform:translate(-50%, calc(-100% - 8px)); background:var(--ink); color:#fff; font-size:12px; padding:6px 8px; border-radius:var(--radius-sm); white-space:nowrap; pointer-events:none; z-index:2;}
  .dash-tip[hidden]{display:none;}
  button.legend-item{border:none; background:none; font-family:inherit; cursor:pointer; padding:4px 6px; border-radius:var(--radius-sm); transition:background-color .12s ease, opacity .12s ease;}
  button.legend-item:hover{background:var(--surface-soft);}
  button.legend-item[aria-pressed="false"]{opacity:.45; text-decoration:line-through;}
  .action-list button.ar-row{display:block; width:calc(100% + 20px); text-align:left; background:none; border:none; border-bottom:1px solid var(--hairline); font-family:inherit; color:inherit;}
  .action-list button.ar-row:last-child{border-bottom:none;}
  .action-list button.ar-row:focus-visible, .dash-table tr[data-open]:focus-visible, .tx-row:focus-visible{outline:2px solid var(--primary-solid); outline-offset:-2px;}
  .dash-empty{padding:var(--space-lg) 0; font-size:13px; color:var(--muted); text-align:center;}
  .dash-table tr[data-open]{cursor:pointer;}
  .dash-table tbody tr:hover td{background:var(--surface-soft);}
  .sort-btn{display:inline-flex; align-items:center; gap:4px; border:none; background:none; padding:0; font:inherit; color:inherit; cursor:pointer;}
  .sort-btn svg{width:12px; height:12px; opacity:.5;}
  th[aria-sort="ascending"] .sort-btn svg, th[aria-sort="descending"] .sort-btn svg{opacity:1; color:var(--primary-text);}
  .dash-overlay{position:absolute; inset:0; z-index:20; display:none; background:rgba(26,31,41,.38);}
  .dash-overlay.open{display:flex;}
  .dash-overlay-center{align-items:center; justify-content:center; padding:var(--space-lg);}
  .dash-overlay-center .dialog-preview{width:min(420px, 100%);}
  .dash-overlay-right{justify-content:flex-end;}
  .dash-overlay-right .drawer-preview{width:min(380px, 100%); height:100%; border-radius:0; display:flex; flex-direction:column;}
  .dash-overlay-right .drawer-preview .db{flex:1; overflow-y:auto;}
  .dash-overlay .df{padding:14px 20px; border-top:1px solid var(--hairline); display:flex; justify-content:flex-end; gap:8px;}
  .dash-overlay .dialog-preview .db{display:flex; flex-direction:column; gap:var(--space-md);}
  .dash-overlay .field{width:100%;}
  .dash-overlay .field select{font-family:var(--font-sans); font-size:14px; color:var(--ink); background:var(--canvas); border:1.5px solid var(--hairline); border-radius:var(--radius-control); padding:12px 14px;}
  .dash-overlay .field select:focus{outline:none; border-color:var(--primary-solid); box-shadow:0 0 0 3px var(--primary-100);}
  .field .input-group.is-invalid, .field .input-group.is-invalid:focus-within, .field textarea.is-invalid, .field textarea.is-invalid:focus{border-color:var(--danger); box-shadow:0 0 0 3px rgba(220,38,38,.12);}
  .error-msg[hidden]{display:none !important;}
  .dash-kv{display:flex; justify-content:space-between; gap:var(--space-md); font-size:14px;}
  .dash-kv span{color:var(--muted);}
  .dash-kv b{color:var(--ink); font-weight:600; font-variant-numeric:tabular-nums;}
  .dash-sub-title{font-size:13px; font-weight:600; color:var(--ink); margin-top:var(--space-xs);}
  .dash-toast{position:absolute; right:var(--space-md); bottom:var(--space-md); z-index:30; background:var(--ink); color:#fff; font-size:13px; padding:10px 14px; border-radius:var(--radius-sm); box-shadow:var(--shadow-float); opacity:0; transform:translateY(8px); transition:opacity .2s ease, transform .2s ease; pointer-events:none;}
  .dash-toast.show{opacity:1; transform:none;}

  /* 版型規格線框圖 */
  .dash-wire{display:flex; gap:8px; padding:8px; background:var(--canvas); border:1px solid var(--hairline); border-radius:var(--radius-card); font-size:12px; color:var(--slate);}
  .dash-wire .wb{background:var(--surface); border:1px dashed var(--hairline-strong); border-radius:var(--radius-sm); padding:10px; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; gap:2px; min-width:0;}
  .dash-wire .wb code{background:none; padding:0; font-size:12px; color:var(--ink);}
  .dash-wire .wb small{font-size:11px; color:var(--muted);}
  .dash-wire .w-nav{width:110px; flex-shrink:0;}
  .dash-wire .w-col{flex:1; min-width:0; display:flex; flex-direction:column; gap:8px;}
  .dash-wire .w-page{display:flex; flex-direction:column; gap:8px; padding:8px; border:1px dashed var(--hairline); border-radius:var(--radius-sm);}
  .dash-wire .w-grid4{display:grid; grid-template-columns:repeat(4, 1fr); gap:8px;}
  .dash-wire .w-grid21{display:grid; grid-template-columns:2fr 1fr; gap:8px;}
  .dash-wire .w-tall{min-height:72px;}
"""

##############################################################################
# 新增元件 HTML
##############################################################################

NEW_CHECKBOX_RADIO_TOGGLE = """
      <h3>核取方塊 / 單選 / 開關 — <code>checkbox / radio / toggle</code></h3>
      <div class="demo">
        <div class="demo-row" style="align-items:flex-start; gap:var(--space-xxl);">
          <div>
            <label class="checkbox-row"><input type="checkbox" checked>包含已作廢項目</label>
            <label class="checkbox-row"><input type="checkbox">僅顯示我送出的</label>
            <label class="checkbox-row"><input type="checkbox" disabled>批次核准（尚未開放）</label>
          </div>
          <div>
            <label class="radio-row"><input type="radio" name="demo-r" checked>依日期排序</label>
            <label class="radio-row"><input type="radio" name="demo-r">依金額排序</label>
          </div>
          <div class="toggle-row"><label class="toggle"><input type="checkbox" checked><span class="slider"></span></label>自動通知簽核人</div>
        </div>
      </div>
      <p class="note">Checkbox 全站使用自訂方形樣式：未勾選為白底灰框，勾選與半選為 <code>primary-solid</code> 實心底＋白色符號；照片或深色背景上需加半透明深底承載。Radio 保持圓形，避免和 checkbox 混淆；Toggle 用在「開/關」這種立即生效的設定，不需要送出按鈕確認。</p>
"""

NEW_INPUT_STATES = """
      <h3>Input 狀態：disabled / invalid</h3>
      <div class="demo"><div class="demo-row">
        <div class="field"><label>備註</label><input placeholder="不可編輯" disabled></div>
        <div class="field">
          <label>金額 *</label>
          <input class="is-invalid" value="-100">
          <span class="error-msg"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/></svg>金額不可為負數</span>
        </div>
        <div class="field">
          <label>電子發票號碼</label>
          <input placeholder="AB-12345678">
          <span class="help-msg">格式：2 碼英文 + 8 碼數字</span>
        </div>
      </div></div>
      <p class="note">Disabled 用 <code>surface-soft</code> 底 + <code>muted-soft</code> 字，不用降低透明度（避免跟 loading 混淆）。Invalid 邊框改 <code>danger</code>，錯誤訊息固定圖示＋文字，不能只靠邊框變色（無障礙要求）。一般說明文字用 <code>help-msg</code>，跟錯誤訊息要能一眼分辨。</p>

      <h3>Textarea</h3>
      <div class="demo"><div class="demo-row">
        <div class="field" style="width:320px;"><label>駁回原因</label><textarea placeholder="請說明駁回原因，將會通知申請人"></textarea></div>
      </div></div>
      <p class="note">Textarea 一律開啟自動長高（PrimeVue <code>auto-resize</code>）：最少 2 行，隨內容長高，超過約 8 行（220px）改為內部捲動。Placeholder 與輸入文字同字級，只用 <code>muted-soft</code> 顏色區分。</p>

      <h3>Input Group（前綴/後綴） — <code>input-group</code>（金額欄位建議用這個）</h3>
      <div class="demo"><div class="demo-row">
        <div class="field"><label>請款金額 *</label><div class="input-group"><span class="addon">NT$</span><input placeholder="0" style="text-align:right;"></div></div>
        <div class="field"><label>網址</label><div class="input-group"><span class="addon">https://</span><input placeholder="example.com"></div></div>
      </div></div>
      <p class="note">金額類欄位一律加 <code>NT$</code> 前綴，避免使用者忘記輸入單位；前綴用 <code>surface</code> 底、<code>muted</code> 文字，明確是「不可編輯的標示」而非輸入內容的一部分。</p>
"""

NEW_FORM_VERTICAL = """
      <h3>Vertical — <code>form-pattern.vertical</code></h3>
      <div class="demo">
        <div class="form-pattern vertical">
          <div class="field"><label>姓名</label><input placeholder="王小明"></div>
          <div class="field"><label>Email</label><input placeholder="name@example.com"></div>
        </div>
      </div>
      <p class="note">預設版型，單欄表單一律用這個；「新增/編輯」這類正式表單、Dialog、Drawer 裡的表單都走 Vertical。</p>
"""

NEW_FORM_HORIZONTAL = """
      <h3>Horizontal — <code>form-pattern.horizontal</code></h3>
      <div class="demo">
        <div class="form-pattern horizontal">
          <div class="h-row"><label>日期</label><input placeholder="選擇日期"></div>
          <div class="h-row"><label>狀態</label><input placeholder="全部"></div>
        </div>
      </div>
      <p class="note">label 在左，只用在篩選列、設定頁這種輕量、非提交型的表單，不用在「新增/編輯」這類正式表單。</p>
"""

NEW_FORM_INLINE = """
      <h3>Inline — <code>form-pattern.inline</code></h3>
      <div class="demo">
        <div class="form-pattern inline">
          <div class="field"><input placeholder="搜尋或新增類別" aria-label="搜尋或新增類別"></div>
          <button class="btn btn-primary">新增</button>
        </div>
      </div>
      <p class="note">用在一行內完成的極簡操作，例如搜尋列旁的小型新增，不需要完整的表單版面。三種版型不可混用在同一個表單裡。</p>
"""

NEW_BUTTON_EXTRAS = """
      <h3>Button 補充：語意色 / 外框 / 群組 / 分裂按鈕 / Loading</h3>
      <div class="demo">
        <div class="demo-row">
          <button class="btn btn-success">核准</button>
          <button class="btn btn-info">標記為已讀</button>
          <button class="btn btn-outlined btn-success">核准</button>
          <button class="btn btn-outlined btn-info">標記為已讀</button>
        </div>
        <div class="demo-row">
          <div class="btn-group">
            <button class="btn btn-primary">日</button>
            <button class="btn btn-primary" style="background:var(--primary-600);">週</button>
            <button class="btn btn-primary">月</button>
          </div>
          <div class="btn-split">
            <button class="btn btn-primary">儲存</button>
            <button class="btn-caret" aria-label="更多選項"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M6 9l6 6 6-6"/></svg></button>
          </div>
          <button class="btn btn-primary is-loading" disabled><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 3a9 9 0 019 9"/></svg>處理中…</button>
        </div>
      </div>
      <p class="note"><code>success / info</code> 是新增的按鈕語意色（沿用既有 <code>--success --info</code> token），用於「核准」「標記已讀」這類正向動作，跟 <code>primary</code>（品牌主動作）區分開——<strong>primary 只保留給「送出/儲存」這類單一主要動作</strong>。外框版是同色但降低視覺重量的替代寫法。Button Group 用於切換態（如日/週/月），Split Button 用於「主要動作 + 次要選項」（如儲存/另存新檔）。Loading 狀態按鈕要 <code>disabled</code>，避免重複送出。</p>
"""

NEW_PAGINATION = """
      <h3>分頁 — <code>pagination</code></h3>
      <div class="demo"><div class="pagination">
        <button aria-label="第一頁"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M18 17l-5-5 5-5M11 17l-5-5 5-5"/></svg></button>
        <button aria-label="上一頁"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M14 17l-5-5 5-5"/></svg></button>
        <button class="active">1</button>
        <button>2</button>
        <button>3</button>
        <button>4</button>
        <button>5</button>
        <button aria-label="下一頁"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M10 17l5-5-5-5"/></svg></button>
        <button aria-label="最後一頁"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M6 17l5-5-5-5M13 17l5-5-5-5"/></svg></button>
      </div></div>
      <p class="note">所有列表頁（Expenses / Payout / Records / History）超過一頁時使用，選中頁碼走 <code>primary-solid</code> 實心圓，跟其他選中態（Tab、Select 選項）一致。</p>
"""

NEW_TABLE_EXTRAS = """
      <h3>Table 互動補充：排序 / 篩選 / 展開 / 分組 / 頭像 / 進度 / 驗證</h3>
      <div class="demo">
        <div class="table-toolbar">
          <button class="btn btn-secondary" style="padding:7px 14px; font-size:13px;">清除篩選</button>
          <div class="field" style="width:220px;"><div class="input-shell"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="1.8"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input placeholder="關鍵字搜尋"></div></div>
        </div>
        <table class="interactive">
          <tr><th></th><th>申請人</th><th>金額<span class="sort-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 15l5 5 5-5M7 9l5-5 5 5"/></svg></span></th><th>狀態</th><th>簽核進度</th><th>憑證</th></tr>
          <tr class="expanded">
            <td class="expand-cell"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M9 6l6 6-6 6"/></svg></td>
            <td><span class="avatar-sm">王</span> 王小明</td>
            <td style="font-variant-numeric:tabular-nums;">NT$ 3,200</td>
            <td><span class="status-badge" style="color:var(--status-review);background:var(--status-review-bg)">簽核中</span></td>
            <td><span class="progress-bar"><span class="fill" style="width:60%"></span></span></td>
            <td><svg class="verified-icon yes" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></td>
          </tr>
          <tr>
            <td class="expand-cell"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M9 6l6 6-6 6"/></svg></td>
            <td><span class="avatar-sm">林</span> 林美惠</td>
            <td style="font-variant-numeric:tabular-nums;">NT$ 850</td>
            <td><span class="status-badge" style="color:var(--status-paid);background:var(--status-paid-bg)">已發放</span></td>
            <td><span class="progress-bar"><span class="fill" style="width:100%"></span></span></td>
            <td><svg class="verified-icon no" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg></td>
          </tr>
        </table>
        <div class="group-header" style="margin-top:var(--space-md); border-radius:var(--radius-card) var(--radius-card) 0 0;"><span class="avatar-sm">財</span> 財務部門（4 筆）</div>
      </div>
      <p class="note">可排序欄位表頭加 <code>sort-icon</code>，預設淺灰、hover 才加深，避免整個表頭看起來都能點。展開列用於「一筆請款有多個項目」時免跳頁看明細；分組表頭（<code>group-header</code>）用 <code>surface</code> 底跟一般列區分。進度條固定綠色（<code>success</code>），跟狀態色脫鉤，純粹代表完成度。驗證圖示（憑證是否已核對）用 <code>success/danger</code> 描邊圓圈，不用實心色塊。凍結欄（<code>frozen</code>）留給欄位多、需要橫向捲動的表格，Quickey 目前先不用。</p>
"""

NEW_TX_LIST_FILTER_HIGHLIGHT = """
      <h3>清單列（頭像＋金額） — <code>tx-row</code></h3>
      <div class="demo" style="max-width:360px;">
        <div class="tx-row"><span class="avatar-sm">陳</span><div><div class="tx-name">陳大文</div><div class="tx-sub">轉帳核銷</div></div><span class="tx-amount pos">+NT$ 3,200</span></div>
        <div class="tx-row"><span class="avatar-sm">林</span><div><div class="tx-name">林美惠</div><div class="tx-sub">駁回退回</div></div><span class="tx-amount neg">−NT$ 850</span></div>
      </div>
      <p class="note">跟同頁的 <code>action-list</code> 不同：<code>tx-row</code> 帶頭像＋金額正負色，用在發放、轉帳這類跟錢有關的清單；<code>action-list</code> 純文字，用在待辦/通知。金額顏色只在「入帳/扣款」語境用 <code>success/danger</code>，其餘地方一律用 <code>ink</code> 中性色，避免整頁紅綠色氾濫。</p>

      <h3>卡頭小篩選 — <code>filter-select</code></h3>
      <div class="demo"><div class="filter-select">本月<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg></div></div>
      <p class="note">卡片標題列右上角的輕量篩選（例如切換「本日/本週/本月」），比照 Freya 的做法用外框小按鈕＋文字，不搶卡片標題的注意力；點擊行為等同一個迷你 Select。</p>

      <h3>強調卡片（提醒/CTA） — <code>highlight-card</code></h3>
      <div class="demo"><div class="highlight-card" style="max-width:280px;"><h4>還有 3 筆待簽核</h4><p>已超過 48 小時未處理，逾期可能影響本月請款進度。</p><button class="btn btn-primary">立即前往</button></div></div>
      <p class="note">提醒/CTA 用實色 <code>ink</code> 底，是整頁唯一的深色區塊，沿用系統「深色＝需要注意」的語意，跟白底 KPI 卡做出主從區分。</p>
"""

_tx_parts = re.split(r'(<h3>.*?</h3>)', NEW_TX_LIST_FILTER_HIGHLIGHT, flags=re.S)
TX_ROW_H3, TX_ROW_BODY = _tx_parts[1], _tx_parts[2]
FILTER_SELECT_H3, FILTER_SELECT_BODY = _tx_parts[3], _tx_parts[4]
HIGHLIGHT_CARD_H3, HIGHLIGHT_CARD_BODY = _tx_parts[5], _tx_parts[6]

##############################################################################
# Timeline（簽核進度） —— 新元件，取代原本只用百分比進度條表示簽核進度的做法
##############################################################################

##############################################################################
# 共用互動元件（Select/DatePicker）— 原始碼在 partials/components.js / .css
##############################################################################
PARTIALS = os.path.join(HERE, "partials")
def read_partial(name):
    return open(os.path.join(PARTIALS, name), encoding="utf-8").read()

QDS_CHEV = '<svg class="qds-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>'
QDS_CAL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 10h18"/></svg>'

def qds_select(options, value=None, size="", placeholder="請選擇", label_id=None, extra_cls="", disabled=False, invalid=False, el_id=None):
    opts = [(o, o) if isinstance(o, str) else o for o in options]
    cur = [l for v, l in opts if v == value]
    lab = ' aria-labelledby="%s"' % label_id if label_id else ''
    cls = "qds-select" + (" qds-select-sm" if size == "sm" else "") + (" is-invalid" if invalid else "") + (" " + extra_cls if extra_cls else "")
    li = "".join('<li role="option" data-value="%s"%s>%s</li>' % (v, ' class="sel" aria-selected="true"' if v == value else ' aria-selected="false"', l) for v, l in opts)
    return ('<div class="%s" data-qds-select%s><button type="button" class="qds-select-trigger" aria-haspopup="listbox" aria-expanded="false"%s%s>'
            '<span class="qds-select-value%s">%s</span>%s</button><ul class="qds-select-panel" role="listbox"%s>%s</ul></div>') % (
        cls, ' id="%s"' % el_id if el_id else '', lab, ' disabled' if disabled else '',
        '' if cur else ' is-placeholder', cur[0] if cur else placeholder, QDS_CHEV, lab, li)

def qds_datepicker(mode="single", value=None, start=None, end=None, size="", placeholder="選擇日期", label_id=None, extra_cls="", el_id=None, disabled=False):
    cls = "qds-datepicker" + (" qds-select-sm" if size == "sm" else "") + (" " + extra_cls if extra_cls else "")
    data = ' data-mode="%s"' % mode
    if value: data += ' data-value="%s"' % value
    if start: data += ' data-start="%s"' % start
    if end: data += ' data-end="%s"' % end
    lab = ' aria-labelledby="%s"' % label_id if label_id else ''
    return ('<div class="%s" data-qds-datepicker%s%s><button type="button" class="qds-select-trigger qds-dp-trigger"%s%s>'
            '<span class="qds-select-value">%s</span>%s</button></div>') % (
        cls, data, ' id="%s"' % el_id if el_id else '', lab, ' disabled' if disabled else '', placeholder, QDS_CAL)

def qds_period(presets, value, label="期間", start=None, end=None, custom_label="自訂日期區間", el=None, align_right=True):
    """期間選擇：預設期間＋自訂日期區間合成一個控制項（小尺寸，卡片標題列用）。"""
    li = "".join('<li role="option" data-value="%s" aria-selected="false">%s</li>' % (v, l) for v, l in presets)
    li += '<li role="option" data-value="custom" data-label="自訂日期區間" class="qds-period-custom" aria-selected="false"><span>%s</span><span class="qds-period-go">›</span></li>' % custom_label
    li += '<li class="qds-period-current" role="presentation"><span class="qds-period-current-head"><span>目前區間</span><button type="button" data-period-reset hidden>重設</button></span><b></b></li>'
    data = ' data-value="%s" data-label="%s"' % (value, label) + (' data-start="%s"' % start if start else '') + (' data-end="%s"' % end if end else '') + (' data-el="%s"' % el if el else '')
    ar = " qds-align-right" if align_right else ""
    return ('<div class="qds-select qds-select-sm qds-period%s" data-qds-period%s><button type="button" class="qds-select-trigger" aria-haspopup="listbox" aria-expanded="false">%s<span class="qds-select-value"></span>%s</button>'
            '<ul class="qds-select-panel" role="listbox" aria-label="%s">%s</ul>'
            '<div class="qds-datepicker qds-period-dp%s" data-qds-datepicker data-mode="range"><button type="button" class="qds-select-trigger qds-dp-trigger" tabindex="-1" aria-hidden="true"><span class="qds-select-value"></span></button></div></div>') % (
        ar, data, QDS_CAL.replace('<svg ', '<svg class="qds-period-ico" '), QDS_CHEV, label, li, ar)

def _qfield(fid, label, inner, extra=""):
    return '<div class="field qds-field"><label id="%s">%s</label>%s%s</div>' % (fid, label, inner, extra)

_ERR_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/></svg>'
_CATS = ["交通費", "餐費", "辦公用品", "軟體訂閱", "其他"]

SELECT_DATE_CONTENT = """
      <h3>Select（下拉選單） — <code>select</code></h3>
      <div class="demo">
        <div class="demo-row" style="align-items:flex-start;">
          %s
          %s
          %s
          %s
        </div>
        <div class="demo-row" style="align-items:center;">
          <span style="font-size:13px; color:var(--muted);">小尺寸 <code>qds-select-sm</code>（卡片標題列篩選）</span>
          %s
        </div>
      </div>
      <p class="note">對應 PrimeVue <code>&lt;Select&gt;</code>，實作一律用 PrimeVue，不用原生 <code>&lt;select&gt;</code>（原生選單的展開樣式由作業系統決定，無法套用 tokens）。觸發框同一般 Input：高 44px、<code>hairline</code> 1.5px 外框、圓角 16px，展開或 focus 時主色外框＋光暈；右側箭頭展開時轉 180°。選單面板白底、圓角 16px、<code>shadow-float</code>，選項 hover 用 <code>surface-soft</code>，已選項目用 <code>primary-50</code> 底＋<code>primary-text</code> 粗體（跟 MultiSelect、AutoComplete 一致）。鍵盤：↑↓ 移動、Enter 選取、Esc 關閉。選項超過 8 個時開啟 PrimeVue 的 <code>filter</code> 搜尋。</p>
      <p class="note">尺寸分兩級：一般 Select / DatePicker 高 44px，用在表單與篩選列；卡片標題列右上角的 compact 篩選高 36px、15px 字、左右內距 12px，用在儀表板圖卡這類要和 18px 標題同列對齊的地方。需要自訂區間時改用下方的「期間選擇」。</p>

      <h3>SelectButton（分段切換） — <code>segmented</code></h3>
      <div class="demo">
        <div class="demo-row" style="align-items:center; gap:var(--space-xl);">
          <div><div class="demo-label">兩個選項</div><div class="qds-segmented" role="group" aria-label="預算週期" data-qds-segmented><button type="button" class="on" aria-pressed="true">月預算</button><button type="button" aria-pressed="false">年預算</button></div></div>
          <div><div class="demo-label">三個選項</div><div class="qds-segmented" role="group" aria-label="檢視方式" data-qds-segmented><button type="button" class="on" aria-pressed="true">依類別</button><button type="button" aria-pressed="false">依人員</button><button type="button" aria-pressed="false">依來源</button></div></div>
        </div>
      </div>
      <p class="note">對應 PrimeVue <code>&lt;SelectButton&gt;</code>（加 <code>:allow-empty="false"</code>，永遠有一個被選中）。用在 2～4 個互斥選項、而且切換的是「整個檢視」的地方，例如預算管理的月預算／年預算：選項全部攤開，點一下就切換。選項超過 4 個，或只是篩選條件時，改用 Select。</p>
      <p class="note">外觀：不包灰底軌道，選項各自是全圓角膠囊（高 40px、16px 字，與按鈕同字級，置於 44px 列高中）。選中那顆 <code>primary-50</code> 淡綠底＋<code>primary-text</code> 600；未選中只有文字 <code>muted</code>，hover 才出現 <code>surface-soft</code> 淺灰底。不用主色實心，避免跟主要按鈕搶視覺。列表頁的狀態分頁也用同一個樣式（TabBar <code>variant="segmented"</code>），選項多時也不會顯得被框住。</p>
      <p class="note">切換時淡綠底會從原本的選項滑到新選項（0.25s，系統設定「減少動態效果」時直接跳）。前端用 <code>SlideSelectButton</code>（包 PrimeVue SelectButton）與膠囊式 TabBar，共用 <code>useSlideIndicator</code>。</p>

      <h3>DatePicker（日期選擇） — <code>date-picker</code></h3>
      <div class="demo">
        <div class="demo-row" style="align-items:flex-start;">
          %s
          %s
          %s
        </div>
      </div>
      <p class="note">對應 PrimeVue <code>&lt;DatePicker&gt;</code>：日期區間用 <code>selection-mode="range"</code>，月份區間加 <code>view="month"</code>。不要用原生 <code>&lt;input type="date"&gt;</code>（各瀏覽器外觀不同，也無法套用 tokens）。顯示格式 <code>yyyy/mm/dd</code>，區間用「–」連接。月曆面板：今天用 <code>primary-text</code> 粗體加淺框；已選日期 <code>primary-solid</code> 實心圓；區間起訖實心、中間 <code>primary-50</code> 底；選區間時第一次點起日、第二次點迄日，未完成前底部提示「請選擇結束日期」；底部固定「清除/今天」。鍵盤：方向鍵移動日期、PageUp/PageDown 切換月份、Enter 選取、Esc 關閉。</p>
      <p class="note">只需要選到月份或年份時（例如預算管理的期間），用 <code>view="month"</code>（格式 <code>yy 年 m 月</code>）或 <code>view="year"</code>（格式 <code>yy 年</code>），面板直接列出 12 個月或 10 個年份，點一下就跳到該期間；兩側可保留上一期/下一期按鈕做相鄰切換。這種放在工具列、當「目前期間」標示用的選擇器採簡約樣式：不顯示日曆 icon，平常看起來是置中的粗體文字，hover 才出現淡框、開啟時主色框。</p>

      <h3>期間選擇（預設期間＋自訂區間） — <code>period-picker</code></h3>
      <div class="demo">
        <div class="demo-row" style="align-items:flex-start; gap:var(--space-xl);">
          <div><div class="demo-label">預設期間</div>%s</div>
          <div><div class="demo-label">自訂日期區間</div>%s</div>
        </div>
      </div>
      <p class="note">圖表卡片標題列右上角的期間篩選，把「預設期間 Select」和「自訂區間 DatePicker」合成一個控制項，不另外多一個輸入框，並和圖卡標題同一行。<code>period-picker</code> 有 <code>md</code>（40px）與 <code>sm</code>（36px）兩種尺寸；儀表板圖卡用 <code>sm</code> 對齊 18px 標題。展開後列出預設期間（本日、本週、本月、近三個月、近六個月、近一年），選項本身保持單純，不在每個選項右側顯示起訖日；最後一項是「自訂日期區間」（右側 › 表示會進入月曆，不用「…」），且上方不加分隔線。選它會在同一位置打開區間月曆（可選到日），選完後按鈕仍顯示「自訂日期區間」。實際起訖日固定顯示在展開選單底部的「目前區間」資訊列，不顯示在圖卡外；選到非預設期間時，「目前區間」資訊列右側提供小型「重設」操作。</p>
      <p class="note">實作：PrimeVue <code>&lt;Select&gt;</code> 的 <code>value</code> 插槽顯示期間文字，選到自訂時用 <code>&lt;DatePicker selection-mode="range" inline&gt;</code> 放在 <code>&lt;Popover&gt;</code> 裡並對齊同一個按鈕；按 Esc 或選完都把焦點還給按鈕。</p>


""" % (
    _qfield("sd-cat", "類別", qds_select(_CATS, "交通費", label_id="sd-cat")),
    _qfield("sd-cat2", "類別（未選）", qds_select(_CATS, None, placeholder="請選擇類別", label_id="sd-cat2")),
    _qfield("sd-cat3", "類別（停用）", qds_select(_CATS, "餐費", label_id="sd-cat3", disabled=True)),
    _qfield("sd-cat4", "類別 *", qds_select(_CATS, None, placeholder="請選擇類別", label_id="sd-cat4", invalid=True), '<span class="error-msg">%s請選擇類別</span>' % _ERR_ICON),
    qds_select([("month", "本月"), ("3m", "近三個月"), ("6m", "近六個月"), ("1y", "近一年")], "month", size="sm", label_id=None),
    _qfield("sd-date", "請款日期", qds_datepicker("single", value="2026-09-23", label_id="sd-date")),
    _qfield("sd-range", "日期區間", qds_datepicker("range", start="2026-09-01", end="2026-09-23", placeholder="選擇起訖日期", label_id="sd-range")),
    _qfield("sd-range2", "自訂區間（小尺寸）", qds_datepicker("range", size="sm", placeholder="選擇起訖日期", label_id="sd-range2")),
    qds_period([("today", "本日"), ("week", "本週"), ("month", "本月"), ("3m", "近三個月"), ("6m", "近六個月"), ("1y", "近一年")], "month", label="類別分佈期間", align_right=False),
    qds_period([("today", "本日"), ("week", "本週"), ("month", "本月"), ("3m", "近三個月"), ("6m", "近六個月"), ("1y", "近一年")], "custom", label="趨勢圖期間", start="2026-09-01", end="2026-09-24", align_right=False),
)


NEW_TIMELINE = r"""
      <h3>簽核進度 — <code>timeline</code></h3>
      <div class="demo"><div class="tl-demo-grid">
        <div class="tl-demo-col">
          <div class="demo-label">簽核中</div>
          <ol class="timeline" aria-label="簽核進度">
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">送出請款</span><span class="tl-status">已送出</span></div><div class="tl-meta">王小明<span class="sep" aria-hidden="true"></span>2026/09/18 10:24</div></div></li>
            <li class="tl-item current" aria-current="step"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">管理員簽核</span><span class="tl-status">等待中</span></div></div></li>
            <li class="tl-item pending"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">發放</span><span class="tl-status">尚未開始</span></div></div></li>
          </ol>
        </div>
        <div class="tl-demo-col">
          <div class="demo-label">已發放</div>
          <ol class="timeline" aria-label="簽核進度">
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">送出請款</span><span class="tl-status">已送出</span></div><div class="tl-meta">王小明<span class="sep" aria-hidden="true"></span>2026/09/18 10:24</div></div></li>
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">管理員簽核</span><span class="tl-status">已簽核</span></div><div class="tl-meta">陳怡君<span class="sep" aria-hidden="true"></span>2026/09/18 14:30</div></div></li>
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">發放</span><span class="tl-status">已發放</span></div><div class="tl-meta">陳怡君<span class="sep" aria-hidden="true"></span>2026/09/20 09:15</div></div></li>
          </ol>
        </div>
        <div class="tl-demo-col">
          <div class="demo-label">駁回後重新送出</div>
          <ol class="timeline" aria-label="簽核進度">
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">送出請款</span><span class="tl-status">已送出</span></div><div class="tl-meta">王小明<span class="sep" aria-hidden="true"></span>2026/09/18 10:24</div></div></li>
            <li class="tl-item rejected"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">管理員簽核</span><span class="tl-status">已駁回</span></div><div class="tl-meta">陳怡君<span class="sep" aria-hidden="true"></span>2026/09/18 14:30</div><div class="tl-comment">發票抬頭不是公司名稱，請重新上傳</div></div></li>
            <li class="tl-item approved"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">重新送出</span><span class="tl-status">已送出</span></div><div class="tl-meta">王小明<span class="sep" aria-hidden="true"></span>2026/09/19 09:02</div></div></li>
            <li class="tl-item current" aria-current="step"><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">管理員簽核</span><span class="tl-status">等待中</span></div></div></li>
          </ol>
        </div>
      </div></div>
      <p class="note">每一筆是一個已發生或待發生的事件：送出請款 → 管理員簽核 → 發放。PRD 為一層簽核，所以「管理員簽核」只有一關；被駁回後重新送出會在下方接續新的事件，不覆蓋舊紀錄，讓員工和管理員都看得到駁回原因與歷程。</p>
      <p class="note">左側狀態圖示＋細連線（<code>hairline</code>），右側為事件名稱、狀態文字、操作人與時間，有意見時加意見框。狀態色：完成 <code>status-paid</code>、駁回 <code>status-rejected</code>（意見框同色淺底）、進行中 <code>status-review</code>（加 <code>aria-current="step"</code>）、尚未開始 <code>muted</code> 空心圓。Timeline 直接放在頁面區塊內，寬度跟隨容器，不另外包一層卡片。</p>
      <p class="note">目前前台/後台明細只列出簽核關卡（管理員簽核），「送出請款」「重新送出」「發放」三種事件尚未呈現，需要前端依請款的送出、重送、發放時間補上。</p>
"""

##############################################################################
# 導覽 / 模板
##############################################################################

ICON_HOME = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 12l9-9 9 9M5 10v10h14V10"/></svg>'
ICON_PALETTE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><circle cx="9" cy="10" r="1.2" fill="currentColor" stroke="none"/><circle cx="14" cy="9" r="1.2" fill="currentColor" stroke="none"/><circle cx="15" cy="14" r="1.2" fill="currentColor" stroke="none"/><path d="M12 21a2 2 0 01-2-2c0-1 1-1 1-2a1.5 1.5 0 00-1.5-1.5H9a4 4 0 01-4-4"/></svg>'
ICON_TYPE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M5 6h14M12 6v14M8 20h8"/></svg>'
ICON_ALERT = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/></svg>'
ICON_DASH = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="12" width="4" height="8" rx="1"/><rect x="10" y="7" width="4" height="13" rx="1"/><rect x="17" y="3" width="4" height="17" rx="1"/></svg>'
ICON_LAYERS = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3l9 5-9 5-9-5 9-5z"/><path d="M3 13l9 5 9-5"/></svg>'
ICON_BUTTON = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="8" width="18" height="8" rx="4"/></svg>'
ICON_FORM_LAYOUT = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 10h16M10 10v10"/></svg>'
ICON_INPUT = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="8" width="18" height="8" rx="2"/><path d="M8 8v8"/></svg>'
ICON_CARD = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="5" width="16" height="14" rx="2"/><path d="M4 10h16"/></svg>'
ICON_TAG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20.6 12.6L12 21.2 2.8 12 2.8 3.4h8.6z"/><circle cx="7.6" cy="8.2" r="1.2" fill="currentColor" stroke="none"/></svg>'
ICON_TAB = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 8a2 2 0 012-2h4l2 2h8a2 2 0 012 2v7a2 2 0 01-2 2H5a2 2 0 01-2-2z"/></svg>'
ICON_TABLE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 10v10"/></svg>'
ICON_DIALOG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 9l6 6M15 9l-6 6"/></svg>'
ICON_EMPTY = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M4 10h16M9 6V4h6v2"/></svg>'
ICON_UPLOAD = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 3v12M7 8l5-5 5 5"/><path d="M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2"/></svg>'
ICON_NAVTOP = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 9v12"/></svg>'
ICON_STATCHART = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 3v18h18"/><path d="M7 15l4-6 4 3 4-8"/></svg>'
ICON_LIST = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M8 6h13M8 12h13M8 18h13"/><circle cx="3.5" cy="6" r="1.2" fill="currentColor" stroke="none"/><circle cx="3.5" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="3.5" cy="18" r="1.2" fill="currentColor" stroke="none"/></svg>'
ICON_SELECT = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="7" width="18" height="10" rx="3"/><path d="M14 11l2 2 2-2"/></svg>'
ICON_PAGINATOR = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 12h.01M20 12h.01"/><rect x="8" y="8" width="8" height="8" rx="2"/></svg>'
ICON_TIMELINE = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="4" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="20" cy="12" r="2"/><path d="M6 12h4M14 12h4"/></svg>'

# Quickey 官方 favicon（frontend/public/favicon.svg），直接內嵌當側邊欄 logo。
FAVICON_SVG = """<svg width="32" height="32" viewBox="0 0 1000 1000" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M671.06 770.833C622.695 813.962 563.449 839.355 499.365 839.355C376.64 839.355 271.447 746.044 227.112 613.433C197.892 585.419 167.463 556.398 133.607 531.609L122.927 523.749H122.725L116.881 519.718C106.402 512.664 95.7216 506.215 85.041 500.572C99.3489 716.619 279.507 887.321 499.365 887.321C568.285 887.321 633.376 870.593 690.809 840.766C694.84 811.745 680.33 784.739 671.06 770.833Z" fill="#2B2B2B"/>
<path d="M205.751 442.733C218.044 254.297 344.8 106.167 499.567 106.167C662.395 106.167 794.188 270.42 794.188 472.762C794.188 571.918 762.55 662.005 710.961 728.109L712.17 729.52V729.721C712.573 730.124 712.976 730.729 713.379 731.132C713.984 731.938 714.588 732.744 715.193 733.55C715.596 734.155 715.999 734.76 716.402 735.163C716.603 735.566 717.006 735.969 717.208 736.17C719.626 739.395 721.843 742.217 724.06 745.038L724.866 746.247C725.47 747.053 726.075 748.061 726.881 748.867C727.284 749.27 727.687 749.875 727.888 750.278C728.694 751.286 729.299 752.092 729.904 753.1C730.508 753.906 730.911 754.51 731.516 755.316L732.523 756.526C737.158 762.975 741.793 769.424 746.227 776.075L748.846 779.904C749.854 781.315 750.66 782.725 751.668 784.136L752.071 784.741L752.675 785.547C753.078 785.95 753.28 786.555 753.683 786.958L759.729 796.027C854.443 720.048 915.1 603.358 915.1 472.561C914.899 243.615 728.896 58 499.365 58C284.142 58 107.007 221.648 86.25 431.246C126.151 432.253 166.253 436.083 205.751 442.733Z" fill="#2B2B2B"/>
<path d="M785.322 876.641L776.254 858.301L772.626 851.65L771.82 850.038C771.82 850.038 771.619 850.038 771.619 850.24C767.185 852.456 761.946 850.643 759.729 846.209C757.714 841.977 759.326 836.938 763.356 834.52L761.543 831.295C754.49 818.8 747.033 806.708 738.973 794.615C738.57 793.809 737.965 793.205 737.562 792.399C736.554 790.786 735.547 789.376 734.539 787.763C733.733 786.554 732.725 785.143 731.919 783.934C727.687 777.485 723.254 771.237 718.619 764.99C717.813 763.78 717.007 762.773 715.999 761.563C715.395 760.757 714.79 759.75 713.984 758.943C712.977 757.533 711.969 756.122 710.961 754.913C710.76 754.51 710.357 754.107 710.155 753.704C707.939 750.882 705.722 747.859 703.505 745.037C702.901 744.231 702.094 743.224 701.49 742.417C700.079 740.805 698.669 738.991 697.46 737.178C691.414 729.519 685.167 722.062 678.718 714.605C561.837 578.971 406.868 495.334 243.234 465.909C163.432 447.973 81.4139 442.33 0 449.383C43.9313 460.266 81.0109 477.195 113.859 497.752C145.9 506.015 179.352 508.434 210.588 498.76C187.01 506.821 162.022 511.457 136.832 513.27L142.877 517.503C176.128 541.889 205.55 569.701 234.569 597.311C275.88 606.783 319.61 607.59 360.317 595.296C326.26 605.373 291.599 614.643 256.131 617.868L256.333 618.069L269.633 630.565C279.306 639.432 288.979 648.3 298.854 656.764L319.812 673.895C365.758 679.135 410.294 663.214 446.971 636.409C421.781 663.415 391.553 685.383 358.503 701.304C425.408 743.224 509.039 767.206 635.593 747.859C637.407 747.657 639.422 747.859 641.437 747.657C602.141 690.824 552.567 633.185 473.974 575.948C542.491 615.651 605.768 667.244 660.38 730.728C664.813 735.767 669.045 741.007 673.277 746.247C674.889 748.262 676.502 750.277 678.114 752.091C678.315 752.293 678.517 752.494 678.517 752.696C689.6 767.005 714.186 805.498 705.52 847.821C721.239 849.433 739.577 860.316 756.505 873.416C760.737 876.641 764.767 880.067 768.596 883.292C768.999 883.695 769.604 884.098 770.007 884.702C770.41 885.105 770.813 885.307 771.216 885.71C792.375 904.453 808.295 922.994 808.295 922.994L785.322 876.641Z" fill="#00B39F"/>
</svg>"""

# (id, fname, label, icon, group) — group 相同的項目在側邊欄會被歸在同一個群組標題下，
# 每個元件各自一個獨立頁面，比照 Freya「UI KIT」底下每個元件都自己一頁的做法。
PAGES_NAV = [
    ("index", "design.html", "總覽", ICON_HOME, "總覽"),
    ("colors", "design-colors.html", "色彩", ICON_PALETTE, "基礎"),
    ("type-space", "design-type-space.html", "字級/間距/圓角/陰影", ICON_TYPE, "基礎"),
    ("button", "design-button.html", "Button", ICON_BUTTON, "元件"),
    ("form-layout", "design-form-layout.html", "Form Layout", ICON_FORM_LAYOUT, "元件"),
    ("input", "design-input.html", "Input", ICON_INPUT, "元件"),
    ("select-date", "design-select-date.html", "Select & DatePicker", ICON_SELECT, "元件"),
    ("card", "design-card.html", "Card", ICON_CARD, "元件"),
    ("badge-tag", "design-badge-tag.html", "Badge & Tag", ICON_TAG, "元件"),
    ("tab", "design-tab.html", "Tab", ICON_TAB, "元件"),
    ("table", "design-table.html", "Table", ICON_TABLE, "元件"),
    ("paginator", "design-paginator.html", "Paginator", ICON_PAGINATOR, "元件"),
    ("alert", "design-alert.html", "Alert", ICON_ALERT, "元件"),
    ("toast", "design-toast.html", "Toast", ICON_ALERT, "元件"),
    ("dialog", "design-dialog.html", "Dialog & Drawer", ICON_DIALOG, "元件"),
    ("empty-state", "design-empty-state.html", "Empty State", ICON_EMPTY, "元件"),
    ("upload", "design-upload.html", "Upload", ICON_UPLOAD, "元件"),
    ("nav-topbar", "design-navigation.html", "Navigation", ICON_NAVTOP, "元件"),
    ("stat-chart", "design-stat-chart.html", "Stat & Chart", ICON_STATCHART, "元件"),
    ("list", "design-list.html", "List", ICON_LIST, "元件"),
    ("timeline", "design-timeline.html", "Timeline", ICON_TIMELINE, "元件"),
    ("prototype", "design-prototype.html", "後台原型", ICON_DASH, "版型"),
    ("layout-shell", "design-layout-shell.html", "頁面骨架", ICON_NAVTOP, "版型"),
    ("layout-home", "design-layout-home.html", "首頁（儀表板）", ICON_STATCHART, "版型"),
    ("layout-list", "design-layout-list.html", "列表頁（CRUD）", ICON_TABLE, "版型"),
    ("architecture", "design-architecture.html", "架構規則/無障礙", ICON_LAYERS, "指南"),
]
FNAME = dict((p[0], p[1]) for p in PAGES_NAV)
GROUP_OF = dict((p[0], p[4]) for p in PAGES_NAV)

def render_nav(active):
    # 直接採用文件本身定義的 side-nav 元件（.side-nav-demo / .sn-item），
    # 讓這份文件的側邊欄本身就是設計系統的真實用例，不是另一套獨立樣式。
    lines = []
    last_group = None
    for pid, fname, label, icon, group in PAGES_NAV:
        if group != last_group:
            lines.append('      <div class="sn-group">%s</div>' % group)
            last_group = group
        cls = "sn-item active" if pid == active else "sn-item"
        lines.append('      <a class="%s" href="%s">%s%s</a>' % (cls, fname, icon, label))
    return "\n".join(lines)

NAV_TOGGLE_ICON = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 6h18M3 12h18M3 18h18"/></svg>'

HEAD_TMPL = """<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>%(title)s — Quickey Design System</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="design-tokens.css?v=%(ver)s">
<script>
(function(){
  var KEY = "qds-nav-collapsed";
  var collapsed = false;
  try { collapsed = localStorage.getItem(KEY) === "1"; } catch (e) {}
  if (collapsed) { document.documentElement.classList.add("nav-collapsed"); }
})();
</script>
<script src="design-search-index.js?v=%(ver)s"></script>
<script src="design-components.js?v=%(ver)s"></script>
</head>
<body>
<div class="shell">
  <nav class="side-nav-demo doc-sidenav">
   <div class="sn-inner">
    <div class="sn-brand"><span class="sn-logo-icon">""" + FAVICON_SVG + """</span>Quickey Design System</div>
%(nav)s
   </div>
  </nav>
  <main>
    <div class="doc-topbar">
      <button type="button" id="nav-toggle-btn" class="nav-toggle" aria-label="收合/展開側邊選單" title="收合/展開側邊選單">""" + NAV_TOGGLE_ICON + """</button>
      <div class="sn-search">
        <input type="text" id="qds-search-input" class="sn-search-input" placeholder="搜尋元件、頁面…（按 / 快速定位）" autocomplete="off" />
        <div id="qds-search-results" class="sn-search-results" hidden></div>
      </div>
    </div>
%(content)s
  </main>
</div>
<script>
(function(){
  var KEY = "qds-nav-collapsed";
  var btn = document.getElementById("nav-toggle-btn");
  if (!btn) return;
  btn.addEventListener("click", function(){
    var collapsed = !document.documentElement.classList.contains("nav-collapsed");
    document.documentElement.classList.toggle("nav-collapsed", collapsed);
    try { localStorage.setItem(KEY, collapsed ? "1" : "0"); } catch (e) {}
  });
})();
</script>
<script>
(function(){
  // 關鍵字搜尋：索引資料由建置腳本產生在 design-search-index.js 的
  // QDS_SEARCH_INDEX（純 <script src> 載入，避開 file:// 開啟時 fetch()
  // 會被瀏覽器擋下 CORS 的問題）。比對頁面標題/小節標題/摘要文字，
  // 點擊結果會直接連到該頁面（小節有對應 id 的話會直接跳到該卡片）。
  var input = document.getElementById("qds-search-input");
  var results = document.getElementById("qds-search-results");
  if (!input || !results || typeof QDS_SEARCH_INDEX === "undefined") return;

  var activeIndex = -1;

  function escapeHtml(s){
    return String(s).replace(/[&<>"]/g, function(c){
      return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c];
    });
  }
  function highlight(text, q){
    if (!q) return escapeHtml(text);
    var idx = text.toLowerCase().indexOf(q.toLowerCase());
    if (idx === -1) return escapeHtml(text);
    return escapeHtml(text.slice(0, idx)) + '<mark class="sn-hl">' +
      escapeHtml(text.slice(idx, idx + q.length)) + "</mark>" +
      escapeHtml(text.slice(idx + q.length));
  }
  function render(items, q){
    activeIndex = -1;
    if (!items.length){
      results.innerHTML = '<div class="sn-search-empty">沒有符合「' + escapeHtml(q) + '」的結果</div>';
      results.hidden = false;
      return;
    }
    results.innerHTML = items.map(function(it){
      var href = it.anchor ? (it.file + "#" + it.anchor) : it.file;
      return '<a class="sn-search-item" href="' + href + '">' +
        '<div class="ssi-title">' + highlight(it.title, q) +
        '<span class="ssi-page">' + escapeHtml(it.page) + "</span></div>" +
        (it.snippet ? '<div class="ssi-snippet">' + highlight(it.snippet, q) + "</div>" : "") +
        "</a>";
    }).join("");
    results.hidden = false;
  }
  function search(q){
    q = q.trim();
    if (!q){ results.hidden = true; results.innerHTML = ""; return; }
    var ql = q.toLowerCase();
    var scored = [];
    for (var i = 0; i < QDS_SEARCH_INDEX.length; i++){
      var it = QDS_SEARCH_INDEX[i];
      var t = it.title.toLowerCase();
      var s = (it.snippet || "").toLowerCase();
      var score = -1;
      if (t.indexOf(ql) === 0) score = 0;
      else if (t.indexOf(ql) !== -1) score = 1;
      else if (s.indexOf(ql) !== -1) score = 2;
      if (score !== -1) scored.push({ it: it, score: score });
    }
    scored.sort(function(a, b){ return a.score - b.score; });
    render(scored.slice(0, 20).map(function(x){ return x.it; }), q);
  }
  input.addEventListener("input", function(){ search(input.value); });
  input.addEventListener("focus", function(){ if (input.value.trim()) results.hidden = false; });
  input.addEventListener("keydown", function(e){
    var items = results.querySelectorAll(".sn-search-item");
    if (e.key === "Escape"){ results.hidden = true; input.blur(); return; }
    if (!items.length) return;
    if (e.key === "ArrowDown"){ e.preventDefault(); activeIndex = Math.min(activeIndex + 1, items.length - 1); }
    else if (e.key === "ArrowUp"){ e.preventDefault(); activeIndex = Math.max(activeIndex - 1, 0); }
    else if (e.key === "Enter"){ if (activeIndex >= 0) items[activeIndex].click(); return; }
    else return;
    items.forEach(function(el, i){ el.classList.toggle("active", i === activeIndex); });
    if (items[activeIndex]) items[activeIndex].scrollIntoView({ block: "nearest" });
  });
  document.addEventListener("click", function(e){
    if (!results.contains(e.target) && e.target !== input) results.hidden = true;
  });
  document.addEventListener("keydown", function(e){
    if (e.key !== "/" || e.target === input) return;
    var tag = document.activeElement && document.activeElement.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA") return;
    e.preventDefault();
    input.focus();
  });
})();
</script>
</body>
</html>
"""

def render_pager(active):
    # Prev/Next 也直接用本文件定義的 button 元件（secondary/primary），
    # 而不是另外寫一套純文字連結樣式。
    ids = [p[0] for p in PAGES_NAV]
    i = ids.index(active)
    prev_html = ""
    next_html = ""
    arrow_l = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M14 17l-5-5 5-5"/></svg>'
    arrow_r = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M10 17l5-5-5-5"/></svg>'
    if i > 0:
        pid, fname, label, icon, group = PAGES_NAV[i-1]
        prev_html = '<a class="btn btn-secondary" href="%s">%s%s</a>' % (fname, arrow_l, label)
    if i < len(PAGES_NAV)-1:
        pid, fname, label, icon, group = PAGES_NAV[i+1]
        next_html = '<a class="btn btn-primary" href="%s">%s%s</a>' % (fname, label, arrow_r)
    return '    <div class="doc-pager"><span>%s</span><span>%s</span></div>' % (prev_html, next_html)

##############################################################################
# 關鍵字搜尋索引：build 時掃過每一頁的內容，收集「頁面本身」跟每個
# <h3> 小節各自一筆索引，輸出成 design-search-index.js（用 <script src>
# 載入而不是 fetch，這樣文件用 file:// 直接開啟也能用，不會被 CORS 擋掉）。
##############################################################################
SEARCH_ENTRIES = []
_heading_counter = [0]

def strip_tags(html_str):
    t = re.sub(r'<script.*?</script>', ' ', html_str, flags=re.S)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = t.replace('&nbsp;', ' ')
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def process_content_for_search(active, page_title, content):
    fname = FNAME[active]
    group = GROUP_OF.get(active, "")

    SEARCH_ENTRIES.append({
        "file": fname, "anchor": "", "title": page_title,
        "page": group, "snippet": strip_tags(content)[:160],
    })

    heading_iter = list(re.finditer(r'<h3>(.*?)</h3>', content, flags=re.S))
    # active 本身是 <section id="%(active)s"> 的 id；同一頁如果剛好有 h3 的 slug
    # 跟它撞名（例如 Alert 頁的 section id="alert"、唯一的 h3 slug 也是
    # "alert"），瀏覽器 getElementById 只認第一個，會讓 #alert 這個錨點失效。
    # 用 used_ids 追蹤本頁已用過的 id，撞名時依序試同一個 <code> 裡的其他
    # 詞（例如 "timeline timeline-vertical" 撞名時改用 "timeline-vertical"），
    # 都撞名才退而求其次加數字尾碼，確保同一頁裡 id 一定唯一。
    used_ids = {active}
    out = content
    for idx, m in enumerate(heading_iter):
        inner = m.group(1)
        code_m = re.search(r'<code>([^<]+)</code>', inner)
        candidates = []
        if code_m:
            for raw in re.split(r'[\/\s]+', code_m.group(1).strip()):
                c = re.sub(r'[^a-zA-Z0-9\-]+', '-', raw).strip('-').lower()
                if c:
                    candidates.append(c)
        slug = ""
        for c in candidates:
            if c not in used_ids:
                slug = c
                break
        if not slug and candidates:
            base = candidates[0]
            n = 2
            while ("%s-%d" % (base, n)) in used_ids:
                n += 1
            slug = "%s-%d" % (base, n)
        if not slug:
            _heading_counter[0] += 1
            slug = "sec-%d" % _heading_counter[0]
        used_ids.add(slug)
        out = out.replace(m.group(0), '<h3 id="%s">%s</h3>' % (slug, inner), 1)

        start = m.end()
        end = heading_iter[idx + 1].start() if idx + 1 < len(heading_iter) else len(content)
        SEARCH_ENTRIES.append({
            "file": fname, "anchor": slug, "title": strip_tags(inner),
            "page": page_title, "snippet": strip_tags(content[start:end])[:160],
        })
    return out

def write_page(active, title, content):
    content = process_content_for_search(active, title, content)
    nav = render_nav(active)
    pager = render_pager(active)
    html = HEAD_TMPL % {"title": title, "nav": nav, "content": content + "\n" + pager, "ver": BUILD_VER}
    fname = FNAME[active]
    open(os.path.join(OUT, fname), "w", encoding="utf-8").write(html)
    print("wrote", fname, len(html))

##############################################################################
# 組頁
##############################################################################

principles_body = re.sub(r'<span class="badge-note">.*?</span>\s*', '', principles)
principles_body = strip_section(principles_body)
density_body = strip_section(density)

# 總覽頁的卡片導覽，照側邊欄同樣的分組顯示
index_groups = [
    ("基礎", [
        ("design-colors.html", "色彩", "品牌綠色階、語意色、6 種請款狀態色、中性色"),
        ("design-type-space.html", "字級/間距/圓角/陰影", "字級字重、間距 tokens、圓角、陰影"),
    ]),
    ("元件", [
        ("design-button.html", "Button", "Primary/Secondary/Danger/Text，語意色、外框、群組、分裂按鈕、Loading"),
        ("design-form-layout.html", "Form Layout", "Vertical/Horizontal/Inline 三種表單排法"),
        ("design-input.html", "Input", "文字輸入、狀態、Textarea、Input Group、MultiSelect、AutoComplete、Checkbox/Radio/Toggle"),
        ("design-select-date.html", "Select & DatePicker", "下拉選單（含小尺寸篩選）、日期與日期區間選擇"),
        ("design-card.html", "Card", "card/card-lg 兩種卡片"),
        ("design-badge-tag.html", "Badge & Tag", "Status Badge/Tag/Category Chip"),
        ("design-tab.html", "Tab", "含數量徽章的分頁"),
        ("design-table.html", "Table", "含排序、展開列、分組、頭像、進度、驗證圖示"),
        ("design-paginator.html", "Paginator", "分頁：頁碼、每頁筆數、筆數說明、精簡版"),
        ("design-alert.html", "Alert", "提示訊息"),
        ("design-toast.html", "Toast", "標題與內文、語意色與停留時間、位置與版型"),
        ("design-dialog.html", "Dialog & Drawer", "彈窗與側滑面板"),
        ("design-empty-state.html", "Empty State", "空狀態畫面"),
        ("design-upload.html", "Upload", "憑證上傳拖放區"),
        ("design-navigation.html", "Navigation", "側邊導覽、頂欄"),
        ("design-stat-chart.html", "Stat & Chart", "KPI 卡、圖表色票、圖例"),
        ("design-list.html", "List", "待處理清單、交易列、卡頭篩選、強調卡片"),
        ("design-timeline.html", "Timeline", "簽核進度：送出、簽核、駁回、重送、發放的時間紀錄"),
    ]),
    ("版型", [
        ("design-prototype.html", "後台原型", "可操作的管理後台原型：儀表板、支出管理、新增支出、請款記錄、簽核、發放、類別管理、預算管理、人員管理、個人設定"),
        ("design-layout-shell.html", "頁面骨架", "側邊導覽、頂欄、頁首、間距與收合規則"),
        ("design-layout-home.html", "首頁（儀表板）", "KPI 列、圖表列、清單列的排法"),
        ("design-layout-list.html", "列表頁（CRUD）", "工具列、批次操作、每列操作、刪除確認、空狀態、分頁、手機版"),
    ]),
    ("指南", [
        ("design-architecture.html", "架構規則/無障礙", "樣式三層架構、無障礙檢查清單、元件速查表"),
    ]),
]
index_groups_html = []
for gname, items in index_groups:
    cards = "\n".join(
        '<a class="index-card" href="%s"><div class="ic-title">%s</div><div class="ic-desc">%s</div></a>' % it
        for it in items
    )
    index_groups_html.append('<h3 style="margin-top:var(--space-xl);">%s</h3><div class="index-grid">%s</div>' % (gname, cards))
index_groups_html = "\n".join(index_groups_html)

index_content = """
    <section id="principles">
      <span class="badge-note">v2.1<span class="sep" aria-hidden="true"></span>分頁式文件<span class="sep" aria-hidden="true"></span>彙整自 docs/dev/design.md + 視覺優化提案 + Dashboard/Freya 對照補件</span>
      %s
    </section>
    <section id="layout-rules">
      <h2>排版原則</h2>
      <p class="lede">同一個畫面的文字樣式越少越好，層級靠粗細與顏色區分，避免視覺疲勞。詳情抽屜、卡片、表單都適用。</p>
      <ul class="rules">
        <li><strong>字級上限 4 種</strong>：頁面或抽屜標題、區塊標題、內文 16px、輔助文字 14px。金額這類關鍵數字是唯一例外。</li>
        <li><strong>用粗細與顏色分層級</strong>：區塊標題 16px 粗體黑色；欄位名稱 16px 一般字重灰色（<code>muted</code>）；欄位值 16px 黑色（<code>ink</code>）。不再為了分層級多加一種字級。</li>
        <li><strong>顏色只有三種用途</strong>：文字只用黑、灰兩色；綠色（<code>primary-text</code>）只給可以點的東西；狀態色只出現在 Status Badge / Tag 裡。</li>
        <li><strong>預設狀態不顯示，只標示例外</strong>：系統自動排程、預設值不另外標註；需要讓人注意的狀況才用 Tag 標示。</li>
        <li><strong>不用括號補充說明</strong>：需要提示時改用 Tag，或直接刪掉；括號會讓一行文字變長、層級變亂。</li>
        <li><strong>用卡片與間距分組，不加分隔線</strong>：相關資訊放進同一張卡片或白底小格，不用細線切開。</li>
        <li><strong>並列資訊用直線分隔</strong>：兩段資訊並排時用 <code>.sep</code>（淺灰細直線，左右 8px），不用「·」或「/」。</li>
        <li><strong>低頻資訊收起來</strong>：建立者、建立時間、最後更新這類紀錄，放在詳情最下方的「紀錄」區塊，預設收合，點標題列在原地展開；不用浮層或 tooltip。</li>
        <li><strong>不用純黑，文字只用 4 階色</strong>：<code>ink</code>、<code>slate</code>、<code>muted</code>、<code>muted-soft</code>，同一藍灰色相；詳見色彩頁「文字色階」。</li>
        <li><strong>文字最小 12px</strong>：附件檔名、圖表標示等小字也不得小於 12px。</li>
      </ul>
    </section>
    <section id="density">
      %s
    </section>
    <section id="nav-index">
      <h2>文件導覽</h2>
      <p class="lede">這份文件是分頁式的，每個元件各自一頁，方便瀏覽跟之後維護。</p>
      %s
    </section>
""" % (principles_body, density_body, index_groups_html)
write_page("index", "總覽", index_content)

write_page("colors", "色彩", '<section id="colors">%s</section>' % strip_section(colors))

type_space_content = """
    <section id="typography">%s</section>
    <section id="spacing">%s</section>
    <section id="radius">%s</section>
    <section id="shadow">%s</section>
""" % (strip_section(typography), strip_section(spacing), strip_section(radius), strip_section(shadow))
write_page("type-space", "字級/間距/圓角/陰影", type_space_content)

def simple_page(active, title, lede, blocks, right_blocks=None, ratio=None, below=None):
    # right_blocks 有內容時，改用參考 Freya UI Kit 的左右兩欄排列。
    # 比例不是固定的，依每頁實際內容類型判斷：兩欄內容量/寬度需求接近就用
    # 1fr 1fr（50/50）；左欄是需要較寬版面的元件（如多欄表單、資料表）就
    # 加大左欄比例（例如 1.6fr 1fr ≈ 62/38）；只有單一元件的頁面則不分欄。
    # below：兩欄排完之後、要整寬獨立一塊的內容（例如概念上跟前兩者不對等
    # 的第三種變體），不塞進兩欄格線裡。
    if right_blocks:
        grid = ratio or "1fr 1fr"
        inner = '<div class="col-layout" style="grid-template-columns:%s;"><div class="col">%s</div><div class="col">%s</div></div>' % (
            grid, "".join(blocks), "".join(right_blocks)
        )
    else:
        inner = "".join(blocks)
    if below:
        inner += "".join(below)
    body = '<section id="%s"><h2>%s</h2><p class="lede">%s</p>%s</section>' % (
        active, title, lede, inner
    )
    write_page(active, title, body)

pv_note = '專案優先使用 PrimeVue 元件（已由 <code>presets/quickey.ts</code> 對齊主色），以下為 PrimeVue 無對應元件、或需自製共用元件時的參考。'

# Button 頁：改成「種類×狀態」矩陣＋尺寸/圖示/組合/排列的標註格線，內容在 partials/button.py
_btn_ns = {}
exec(read_partial("button.py"), _btn_ns)
simple_page("button", "Button", "對應 PrimeVue <code>&lt;Button&gt;</code>（顏色已由 <code>presets/quickey.ts</code> 對齊）。這頁定義 Quickey 裡每種按鈕的用途、狀態、尺寸與排列方式。", [_btn_ns["BUTTON_CONTENT"]])
form_note = pv_note + '<br><strong>欄位標籤</strong>：與輸入值同字級（專案內 16px），只靠顏色區分——標籤 <code>slate</code>／500，輸入值 <code>ink</code>／400。粗體留給頁面／視窗標題與按鈕。欄位群組內的子標籤（例如金額底下的未稅金額、稅率、含稅金額）用 <code>field-sublabel</code>：14px／400 <code>muted</code>。'
simple_page("form-layout", "Form Layout", form_note, [NEW_FORM_VERTICAL], [NEW_FORM_HORIZONTAL], ratio="1fr 1fr", below=[NEW_FORM_INLINE])
simple_page("input", "Input", pv_note, [basic_input_block, advanced_input_block], [NEW_INPUT_STATES, NEW_CHECKBOX_RADIO_TOGGLE], ratio="1.35fr 1fr")
_SUBJ_DEMO = [(c, c + " " + n) for c, n in [("6111", "薪資支出"), ("6112", "租金支出"), ("6113", "文具用品"), ("6114", "旅費"), ("6116", "郵電費"), ("6117", "修繕費"), ("6118", "廣告費"), ("6119", "水電瓦斯費"), ("6120", "保險費"), ("6121", "交際費"), ("6128", "伙食費"), ("6129", "職工福利"), ("6132", "訓練費"), ("6133", "勞務費"), ("6134", "其他營業費用")]]
SELECT_DATE_CONTENT = SELECT_DATE_CONTENT.replace(
    '      <p class="note">對應 PrimeVue <code>&lt;Select&gt;</code>',
    '      <div class="demo"><div class="demo-row" style="align-items:flex-start;">'
    + _qfield("sd-subj", "會計科目（可搜尋）", qds_select(_SUBJ_DEMO, None, placeholder="請選擇會計科目", label_id="sd-subj").replace("data-qds-select", 'data-qds-select data-filter="輸入代碼或名稱搜尋"', 1))
    + '</div></div>\n      <p class="note">選項多的選單（例如類別管理的會計科目）加 PrimeVue <code>filter</code>：面板頂端固定一個搜尋框，打開就自動聚焦，可輸入代碼或名稱即時篩選，沒有符合時顯示「找不到符合的選項」；↓ 從搜尋框移到第一個選項，Enter 直接選第一個符合的選項。</p>\n'
    + '      <p class="note">對應 PrimeVue <code>&lt;Select&gt;</code>', 1)

simple_page("select-date", "Select & DatePicker", "下拉選單與日期選擇。對應 PrimeVue <code>&lt;Select&gt;</code> 與 <code>&lt;DatePicker&gt;</code>：實作直接用 PrimeVue（已由 <code>presets/quickey.ts</code> 套用專案色），這頁定義它們在 Quickey 裡的外觀、狀態與使用時機；頁面上的示範可以實際操作。", [SELECT_DATE_CONTENT])
simple_page("card", "Card", pv_note, [card_block])
simple_page("badge-tag", "Badge & Tag", pv_note, [badge_status_block, badge_tag_block, badge_chip_block])
simple_page("tab", "Tab", pv_note, [tab_block])
TABLE_INLINE_EDIT = """
      <h3>行內編輯（單一欄位） — <code>inline-edit</code></h3>
      <div class="demo"><div class="demo-row" style="align-items:center; gap:var(--space-xl);">
        <div><div class="demo-label">一般</div><button type="button" class="ie-trigger">NT$ 12,000</button></div>
        <div><div class="demo-label">hover / focus</div><button type="button" class="ie-trigger is-hover"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20h4L18.5 9.5a2.1 2.1 0 0 0-4-4L4 16v4z"/></svg>NT$ 12,000</button></div>
        <div><div class="demo-label">未設定</div><button type="button" class="ie-trigger empty">未設定</button></div>
        <div><div class="demo-label">編輯中</div><label class="search-sm" style="width:168px;"><span style="color:var(--muted);">NT$</span><input value="12000" style="text-align:right;" aria-label="預算金額"></label></div>
      </div></div>
      <p class="note">一列只有一個可改的欄位時（例如預算管理的預算金額），不另外放「編輯/儲存」按鈕：直接點金額就變成輸入框（PrimeVue <code>&lt;InputNumber&gt;</code>），按 Enter 或點其他地方即儲存、Esc 取消，儲存後用 Toast 回饋。平常看起來是一般文字；hover 或鍵盤 focus 時出現淡框與鉛筆圖示提示可以點。觸發區與輸入框同寬同高（168 × 44px），切換時表格不跳動。一列有多個可改欄位時，改用 Dialog 或獨立編輯頁。</p>
"""

simple_page("table", "Table", pv_note, [NEW_TABLE_EXTRAS], [table_block, '<p class="note">分頁（Paginator）已獨立成 <a href="design-paginator.html">Paginator</a> 頁。</p>', TABLE_INLINE_EDIT], ratio="1.6fr 1fr")
_pg_ns = {}
exec(read_partial("paginator.py"), _pg_ns)
simple_page("paginator", "Paginator", "表格或清單超過一頁時的分頁元件。對應 PrimeVue <code>&lt;Paginator&gt;</code>，實作直接用 PrimeVue；這頁定義版面、狀態與使用規則，示範可以實際操作。", [_pg_ns["PAGINATOR_CONTENT"]])
simple_page("alert", "Alert", pv_note, [alert_block])
_toast_ns = {}
exec(read_partial("toast.py"), _toast_ns)
simple_page("toast", "Toast", pv_note, [_toast_ns["TOAST_CONTENT"]])
simple_page("dialog", "Dialog & Drawer", pv_note, [dialog_block])
simple_page("empty-state", "Empty State", pv_note, [empty_block])
simple_page("upload", "Upload", pv_note, [upload_block])

write_page("nav-topbar", "Navigation", '<section id="nav-topbar"><h2>Navigation</h2><p class="lede">後台的導覽骨架：側邊導覽與頂欄，可在<a href="design-prototype.html">後台原型</a>中看到實際組合。PrimeVue 沒有對應的後台導覽骨架元件，屬於自製共用元件。</p>%s%s%s%s</section>' % (
    DASH_NAV_H3, DASH_NAV_BODY, DASH_TOPBAR_H3, DASH_TOPBAR_BODY
))

write_page("stat-chart", "Stat & Chart", '<section id="stat-chart"><h2>Stat & Chart</h2><p class="lede">首頁常見的數據呈現元件：KPI 卡、圖表色票與圖例，可在<a href="design-prototype.html">後台原型</a>中看到實際組合。PrimeVue 沒有對應的KPI 卡/圖表色票元件，屬於自製共用元件。</p>%s%s%s%s%s%s</section>' % (
    DASH_KPI_H3, DASH_KPI_BODY, DASH_CHART_H3, DASH_CHART_BODY, DASH_LEGEND_H3, DASH_LEGEND_BODY
))

FILTER_SELECT_H3 = '<h3>卡頭小篩選 — <code>qds-select-sm</code></h3>'
FILTER_SELECT_BODY = """
      <div class="demo">%s</div>
      <p class="note">卡片標題列右上角的輕量篩選（例如切換期間「本月/近三個月/近六個月」），就是 <a href="design-select-date.html">Select</a> 的小尺寸：高 44px、1.5px 外框、圓角 16px、內距較窄，不搶卡片標題的注意力。舊的靜態 <code>filter-select</code> 已由它取代。</p>
""" % qds_select([("month", "本月"), ("3m", "近三個月"), ("6m", "近六個月"), ("1y", "近一年")], "month", size="sm")
write_page("list", "List", '<section id="list"><h2>List</h2><p class="lede">幾種清單型元件：純文字待辦清單、含頭像與金額的交易列、卡頭小篩選、強調用 CTA 卡片，可在<a href="design-prototype.html">後台原型</a>中看到實際組合。PrimeVue 沒有對應元件（<code>DataView</code>/<code>Listbox</code> 的呈現方式不符這裡的視覺需求），屬於自製共用元件。</p>%s%s%s%s%s%s%s%s</section>' % (
    DASH_ACTIONLIST_H3, DASH_ACTIONLIST_BODY, TX_ROW_H3, TX_ROW_BODY, FILTER_SELECT_H3, FILTER_SELECT_BODY, HIGHLIGHT_CARD_H3, HIGHLIGHT_CARD_BODY
))

write_page("timeline", "Timeline", '<section id="timeline"><h2>Timeline</h2><p class="lede">請款單的簽核進度元件，可在<a href="design-prototype.html">後台原型</a>中看到實際組合。PrimeVue 有 <code>Steps</code>/<code>Timeline</code> 元件，但預設樣式與這裡的「已完成/進行中/駁回」語意色不符，這裡是以 PrimeVue Timeline 的結構概念為基礎、用專案既有 tokens 自製的版本，而非直接引入 PrimeVue 原生樣式。</p>%s</section>' % NEW_TIMELINE)

# 後台原型的示意資料：直接讀前端的 mock（frontend/src/mocks），讓原型跟實際前端的欄位與資料同步。
import json as _json
MOCKS = os.environ.get("QDS_MOCKS", os.path.join(HERE, "..", "..", "frontend", "src", "mocks"))
def _mock(name):
    try:
        return _json.load(open(os.path.join(MOCKS, name + ".json"), encoding="utf-8"))
    except FileNotFoundError:
        print("WARN: 找不到 mock", name); return []
_users = [{k: v for k, v in u.items() if k != "password"} for u in _mock("users")]
_reimb = [{k: v for k, v in r.items() if k not in ("receiptUrls",)} | {"receiptCount": len(r.get("receiptUrls") or [])} for r in _mock("reimbursements")]
_exp = [{k: v for k, v in e.items() if k != "attachments"} | {"attachmentCount": len(e.get("attachments") or [])} for e in _mock("expenses")]
PROTO_DATA = {"categories": _mock("categories"), "users": _users, "invitations": [{k: v for k, v in i.items() if k != "token"} for i in _mock("invitations")],
              "reimbursements": _reimb, "expenses": _exp, "budgets": _mock("budgets"), "budgetTemplates": _mock("budget-templates")}
PROTO_DATA_JS = "window.QDS_PROTO_DATA = " + _json.dumps(PROTO_DATA, ensure_ascii=False) + ";"

# 版型：後台原型（互動）＋三份規則頁。原型的 HTML/JS/CSS 在 partials/prototype.html、dashboard.js、dashboard.css
_proto_ns = {"qds_select": qds_select, "qds_datepicker": qds_datepicker, "qds_period": qds_period}
exec(read_partial("prototype.py"), _proto_ns)
PROTOTYPE_HTML = _proto_ns["PROTOTYPE_HTML"]
PROTOTYPE_CONTENT = (
    '<section id="prototype"><h2>後台原型</h2><p class="lede">Quickey 管理後台的可操作原型，全部由「元件」組成、照「版型」規則排版。'
    '側邊導覽可以切換各頁，資料在各頁之間同步；網址加上 <code>#expenses</code> 這類頁面代號可以直接打開指定頁。功能與欄位跟後台前端同步，資料讀自前端 mock。</p>\n'
    + PROTOTYPE_HTML
    + '<details class="proto-notes"><summary>這個原型可以操作的地方</summary>' + read_partial("prototype-notes.html") + '</details>'
    + "\n      <script>\n" + PROTO_DATA_JS + "\n" + read_partial("dashboard.js") + "\n      </script>\n</section>"
)
write_page("prototype", "後台原型", PROTOTYPE_CONTENT)
write_page("layout-shell", "頁面骨架", '<section id="layout-shell"><h2>頁面骨架</h2><p class="lede">所有後台頁面共用的外框：側邊導覽、頂欄、頁首與間距。</p>' + read_partial("layout-shell.html") + '</section>')
write_page("layout-home", "首頁（儀表板）", '<section id="layout-home"><h2>首頁（儀表板）</h2><p class="lede">後台首頁的排法：一列 KPI、一列圖表、一列清單。</p>' + read_partial("layout-home.html") + '</section>')
_ll_ns = {"qds_select": qds_select, "qds_datepicker": qds_datepicker}
exec(read_partial("layout_list.py"), _ll_ns)
write_page("layout-list", "列表頁（CRUD）", '<section id="layout-list"><h2>列表頁（CRUD）</h2><p class="lede">「一張表管一種資料」的頁面怎麼排：工具列、批次操作、每列操作、刪除確認、空狀態、分頁與手機版。</p>' + _ll_ns["LAYOUT_LIST_CONTENT"] + '</section>')
# 舊網址 design-dashboard.html 轉址到後台原型（保留檔案，避免舊連結失效）
open(os.path.join(OUT, "design-dashboard.html"), "w", encoding="utf-8").write('<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><title>後台原型 — Quickey Design System</title><meta http-equiv="refresh" content="0; url=design-prototype.html"></head><body><p>此頁已改名為 <a href="design-prototype.html">後台原型</a>。</p></body></html>')

arch_content = """
    <section id="architecture">%s</section>
    <section id="a11y">%s</section>
    <section id="notes">%s</section>
    <section id="spec">
      <h2>元件規範速查表</h2>
      %s
      <table style="margin-top:var(--space-md);">
        <tr><th>元件</th><th>圓角</th><th>說明</th></tr>
        <tr><td>checkbox</td><td>6px</td><td>自訂方形樣式，勾選／半選為 primary-solid 實心底＋白色符號</td></tr>
        <tr><td>radio</td><td>full</td><td>保持圓形，選中色 primary-solid，避免和 checkbox 混淆</td></tr>
        <tr><td>toggle</td><td>full</td><td>開＝primary-solid，關＝hairline-strong</td></tr>
        <tr><td>input-group</td><td>control 16px</td><td>前綴/後綴用 surface 底標示不可編輯</td></tr>
        <tr><td>pagination</td><td>sm / full（選中）</td><td>選中頁碼實心圓 primary-solid</td></tr>
        <tr><td>tx-row</td><td>—</td><td>頭像＋金額，金額正負用 success/danger</td></tr>
        <tr><td>highlight-card</td><td>card-lg 20px</td><td>實色 ink 底，提醒/CTA 用</td></tr>
      </table>
    </section>
""" % (strip_section(architecture), strip_section(a11y), strip_section(notes), spec_table)
write_page("architecture", "架構規則/無障礙", arch_content)

tokens_css = style + "\n" + EXTRA_CSS + "\n" + read_partial("components.css") + "\n" + read_partial("dashboard.css")
open(os.path.join(OUT, "design-components.js"), "w", encoding="utf-8").write("// 自動產生，請勿手動編輯 —— 原始碼在 _generator/partials/components.js\n" + read_partial("components.js"))
print("wrote design-components.js")
open(os.path.join(OUT, "design-tokens.css"), "w", encoding="utf-8").write(tokens_css)
print("wrote design-tokens.css", len(tokens_css))

import json
search_js = "// 自動產生，請勿手動編輯 —— 由 build_pages.py 在每次 build 時重新產生\nvar QDS_SEARCH_INDEX = " + json.dumps(SEARCH_ENTRIES, ensure_ascii=False, indent=None) + ";\n"
open(os.path.join(OUT, "design-search-index.js"), "w", encoding="utf-8").write(search_js)
print("wrote design-search-index.js", len(search_js), "(%d entries)" % len(SEARCH_ENTRIES))

print("ALL DONE")
