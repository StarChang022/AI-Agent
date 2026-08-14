import os
import re
from bs4 import BeautifulSoup
from bs4 import Comment

base_dir = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Official_Website/文案內容'
portfolio_dir = os.path.join(base_dir, 'portfolio')
portfolio_html_path = os.path.join(base_dir, 'portfolio.html')

with open(portfolio_html_path, 'r', encoding='utf-8') as f:
    portfolio_html_soup = BeautifulSoup(f, 'html.parser')

files_to_process = [
    'mitac-meeting-room-booking-system.md',
    'neopsy.md',
    'optree.md',
    'secom-sigmu-articles.md',
    'secom-esg.md',
    'secom-smarthome.md',
    'siangyu.md',
    'starworld_2-0.md',
    'stemcell.md',
    'tfif-app.md',
    'tsn.md',
    'virtualman.md',
    'wmoon.md'
]

def find_matching_close(text, start_idx, tag_name='div'):
    open_tag = f'<{tag_name}'
    close_tag = f'</{tag_name}>'
    open_count = 0
    i = start_idx
    while i < len(text):
        next_open = text.find(open_tag, i)
        next_close = text.find(close_tag, i)
        if next_open != -1 and next_open < next_close:
            char_after = text[next_open + len(open_tag):next_open + len(open_tag) + 1]
            if char_after in (' ', '>', '\n', '\t'):
                open_count += 1
            i = next_open + len(open_tag)
        elif next_close != -1:
            open_count -= 1
            i = next_close + len(close_tag)
            if open_count == 0:
                return i
        else:
            break
    return -1

def dedent_raw_html(html_str):
    if not html_str:
        return ''
    lines = html_str.split('\n')
    
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
        
    if not lines:
        return ''
        
    min_indent = float('inf')
    for i, line in enumerate(lines):
        if i == 0 and not (line.startswith('\t') or line.startswith(' ')):
            continue
        if line.strip():
            indent = len(line) - len(line.lstrip('\t '))
            if indent < min_indent:
                min_indent = indent
                
    if min_indent == float('inf'):
        min_indent = 0
        
    out_lines = []
    for i, line in enumerate(lines):
        if i == 0 and not (line.startswith('\t') or line.startswith(' ')):
            out_lines.append(line)
        elif line.strip():
            out_lines.append(line[min_indent:])
        else:
            out_lines.append('')
    return '\n'.join(out_lines)

for md_file in files_to_process:
    base_name = md_file[:-3]
    html_file = base_name + '.html'
    html_path = os.path.join(portfolio_dir, html_file)
    md_path = os.path.join(portfolio_dir, md_file)
    
    if not os.path.exists(html_path):
        continue
        
    with open(html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
        
    soup = BeautifulSoup(html_content, 'html.parser')
    
    doc_id = base_name
    title_tag = soup.find('title')
    title = title_tag.text.replace(' | PlayPlus 普魯士國際', '').strip() if title_tag else ''
    
    desc_tag = soup.find('meta', attrs={'name': 'description'})
    description = desc_tag['content'].strip() if desc_tag and desc_tag.has_attr('content') else ''
    
    kw_tag = soup.find('meta', attrs={'name': 'keywords'})
    keywords = kw_tag['content'].strip() if kw_tag and kw_tag.has_attr('content') else ''
    
    list_summary = ''
    a_tag = portfolio_html_soup.find('a', href=f'portfolio/{html_file}')
    if a_tag:
        p_tag = a_tag.find('p')
        if p_tag:
            list_summary = p_tag.text.strip()
            
    foreword = ''
    banner_comment = soup.find(string=lambda text: isinstance(text, Comment) and text.strip() == 'Banner')
    if banner_comment:
        sibling = banner_comment.next_sibling
        while sibling:
            if hasattr(sibling, 'get') and sibling.get('class') and 'hero' in sibling.get('class'):
                col = sibling.find('div', class_='column gap-small')
                if col:
                    p = col.find('p')
                    if p:
                        foreword = p.text.strip()
                        break
            if hasattr(sibling, 'get') and sibling.get('class') and 'column' in sibling.get('class') and 'gap-small' in sibling.get('class'):
                p = sibling.find('p')
                if p:
                    foreword = p.text.strip()
                    break
            sibling = sibling.next_sibling
            
    tags = []
    tags_container = soup.find('div', class_='tags')
    if tags_container:
        tag_divs = tags_container.find_all('div', class_='tag')
        tags = [t.text.strip() for t in tag_divs]
    tags_str = ', '.join(tags)
    
    urlwebsite = ''
    actions_div = soup.find('div', class_='actions')
    if actions_div:
        a_href = actions_div.find('a')
        if a_href and a_href.has_attr('href'):
            urlwebsite = a_href['href'].strip()

    geo_html = ''
    c_idx = html_content.find('<!-- GEO Summary Box -->')
    if c_idx != -1:
        div_idx = html_content.find('<div class="summary-box', c_idx)
        if div_idx != -1:
            end_idx = find_matching_close(html_content, div_idx, 'div')
            if end_idx != -1:
                geo_html = html_content[div_idx:end_idx]

    content_html = ''
    c_idx = html_content.find('<!-- Content -->')
    if c_idx != -1:
        div_idx = html_content.find('<div class="content column', c_idx)
        if div_idx != -1:
            end_idx = find_matching_close(html_content, div_idx, 'div')
            if end_idx != -1:
                content_html = html_content[div_idx:end_idx]
            
    md_content = f"""# Head Editor

**id**: {doc_id}
**title**: {title}
**description**: {description}
**keywords**: {keywords}
**list-summary**: {list_summary}
**foreword**: {foreword}
**tags**: {tags_str}
**urlwebsite**: {urlwebsite}

---

# GEO Summary Box Editor

{dedent_raw_html(geo_html)}

---

# Content Editor

{dedent_raw_html(content_html)}
"""
    with open(md_path, 'w', encoding='utf-8') as f:
        f.write(md_content)
    
    print(f"Processed {md_file}")

print("Done")
