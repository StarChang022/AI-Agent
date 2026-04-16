import sys
import os
import re
from datetime import datetime

def parse_markdown(md_text):
    """Simple parser to convert markdown text to HTML following the block rules."""
    html_lines = []
    lines = md_text.strip().split('\n')
    
    in_ul = False
    in_ol = False
    in_p = False

    def close_lists():
        nonlocal in_ul, in_ol, in_p
        if in_p:
            html_lines.append('</p>')
            in_p = False
        if in_ul:
            html_lines.append('</ul>')
            in_ul = False
        if in_ol:
            html_lines.append('</ol>')
            in_ol = False

    for line in lines:
        stripped = line.strip()
        if not stripped:
            close_lists()
            continue
            
        if stripped.startswith('### '):
            close_lists()
            html_lines.append(f'<h3 class="inside">{stripped[4:].strip()}</h3>')
        elif stripped.startswith('> '):
            close_lists()
            val = stripped[2:].strip()
            val = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', val)
            val = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', val)
            html_lines.append(f'<blockquote>{val}</blockquote>')
        elif stripped.startswith('- '):
            if in_p: close_lists()
            if in_ol: close_lists()
            if not in_ul:
                html_lines.append('<ul>')
                in_ul = True
            val = stripped[2:].strip()
            val = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', val)
            val = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', val)
            html_lines.append(f'\t<li>{val}</li>')
        elif re.match(r'^\d+\.\s', stripped):
            if in_p: close_lists()
            if in_ul: close_lists()
            if not in_ol:
                html_lines.append('<ol>')
                in_ol = True
            val = re.sub(r'^\d+\.\s+', '', stripped)
            val = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', val)
            val = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', val)
            html_lines.append(f'\t<li>{val}</li>')
        else:
            if not in_p and not in_ul and not in_ol:
                html_lines.append('<p>')
                in_p = True
            
            val = line
            val = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', val)
            val = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', val)
            html_lines.append(val)
            
    close_lists()
    return '\n'.join(['\t\t\t\t\t\t\t' + l if not l.startswith('\t') else '\t\t\t\t\t\t\t' + l.strip() for l in html_lines])

def build_content_html(content_text):
    sections = re.split(r'\n(?=## )', '\n' + content_text)
    final_html_blocks = []
    
    for sec in sections:
        sec = sec.strip()
        if not sec: continue
        
        if sec.startswith('## '):
            parts = sec.split('\n', 1)
            header_text = parts[0][3:].strip()
            rest_text = parts[1] if len(parts) > 1 else ''
            
            block_html = '\t\t\t\t\t\t<div class="column">\n'
            block_html += f'\t\t\t\t\t\t\t<h2 class="inside">{header_text}</h2>\n'
            if rest_text.strip():
                block_html += parse_markdown(rest_text) + '\n'
            block_html += '\t\t\t\t\t\t</div>'
            final_html_blocks.append(block_html)
        else:
            block_html = '\t\t\t\t\t\t<div class="column">\n'
            block_html += parse_markdown(sec) + '\n'
            block_html += '\t\t\t\t\t\t</div>'
            final_html_blocks.append(block_html)
            
    return '\n'.join(final_html_blocks)

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_blog_page.py <path_to_markdown_file>")
        sys.exit(1)

    md_filepath = sys.argv[1]
    if not os.path.exists(md_filepath):
        print(f"Error: File not found: {md_filepath}")
        sys.exit(1)

    filename = os.path.basename(md_filepath)
    match = re.match(r'^(\d{8})-(.+)\.md$', filename)
    if not match:
        print("Error: Markdown filename must be in format YYYYMMDD-ArticleName.md")
        sys.exit(1)

    date_str = match.group(1)
    article_name = match.group(2)
    date_formatted = f"{date_str[:4]}/{date_str[4:6]}/{date_str[6:8]}"
    sitemap_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}T12:00:00+00:00"

    print(f"Processing: {article_name} ({date_formatted})")

    with open(md_filepath, 'r', encoding='utf-8') as f:
        text = f.read()

    lines = text.split('\n')
    metadata = {}
    content_lines = []
    in_table = False
    table_done = False

    for line in lines:
        if line.startswith('|') and not table_done:
            in_table = True
            parts = [p.strip() for p in line.split('|')[1:-1]]
            if len(parts) == 2:
                key, val = parts[0], parts[1]
                if key not in ['項目', '---']:
                    metadata[key] = val
        else:
            if in_table:
                table_done = True
            if table_done:
                content_lines.append(line)

    tags_str = metadata.get('標籤', '')
    tags = [t.strip() for t in tags_str.split(',') if t.strip()]
    description = metadata.get('Description', '')
    keywords = metadata.get('Keywords', '')
    url_name = metadata.get('URL', '')

    if not url_name:
        print("Error: URL not found in markdown metadata table")
        sys.exit(1)

    content_text = '\n'.join(content_lines).strip()
    content_html = build_content_html(content_text)

    target_dir = "/Users/starchang/Documents/CloudFolder/GitHub/playplus2025_transition_version"

    # ==========================
    # 1. Update blog.html
    # ==========================
    blog_html_path = os.path.join(target_dir, 'blog.html')
    if os.path.exists(blog_html_path):
        with open(blog_html_path, 'r', encoding='utf-8') as f:
            blog_html = f.read()

        tag_html = '\n'.join([f'\t\t\t\t\t<div class="tag">{t}</div>' for t in tags])

        list_item = f"""
<div class="col-sm-6 col-md-4 col-lg-3 filter column gap-micro centre">
	<a href="blog/{url_name}.html">
		<div class="cards article-summary">
			<img src="images/blog/{url_name}/cover.webp" alt="{article_name}">
			<div class="content">
				<div class="tags">
{tag_html}
				</div>
				<h3 class="inside">{article_name}</h3>
				<div class="date">{date_formatted}</div>
			</div>
		</div>
	</a>
</div>
"""
        target_str = '<div id="blogs" class="row column grid-container col-mb-30" data-layout="fitRows">'
        if target_str in blog_html and list_item.strip() not in blog_html:
            blog_html = blog_html.replace(target_str, target_str + "\n" + list_item.strip('\n'))
            with open(blog_html_path, 'w', encoding='utf-8') as f:
                f.write(blog_html)
            print(f"Updated {blog_html_path}")
        else:
            print("Notice: blog.html already contains this item or target string not found.")
    else:
        print(f"File not found: {blog_html_path}")

    # ==========================
    # 2. Update sitemap.xml
    # ==========================
    sitemap_path = os.path.join(target_dir, 'public/sitemap.xml')
    if os.path.exists(sitemap_path):
        with open(sitemap_path, 'r', encoding='utf-8') as f:
            sitemap_content = f.read()

        sitemap_node = f"""
<url>
  <loc>https://playplus.com.tw/blog/{url_name}.html</loc>
  <lastmod>{sitemap_date}</lastmod>
  <priority>0.70</priority>
</url>
"""
        sitemap_target = "<!-- Blog -->"
        if sitemap_target in sitemap_content and f"https://playplus.com.tw/blog/{url_name}.html" not in sitemap_content:
            # Insert at the end of the Blog section. The blog section ends when <!-- Services --> starts.
            blog_section_end = sitemap_content.find("<!-- Services -->")
            if blog_section_end != -1:
                # Find the last </url> before <!-- Services -->
                last_url_end = sitemap_content.rfind("</url>", 0, blog_section_end)
                if last_url_end != -1:
                    insert_pos = last_url_end + 6
                    sitemap_content = sitemap_content[:insert_pos] + "\n" + sitemap_node.strip('\n') + sitemap_content[insert_pos:]
                    with open(sitemap_path, 'w', encoding='utf-8') as f:
                        f.write(sitemap_content)
                    print(f"Updated {sitemap_path}")
        else:
            print("Notice: sitemap.xml already contains this URL or target string not found.")
    else:
        print(f"File not found: {sitemap_path}")

    # ==========================
    # 3. Create YYYYYMMDD-ArticleName.html
    # ==========================
    template_path = os.path.join(target_dir, 'blog/YYYYMMDD-empty.html')
    output_path = os.path.join(target_dir, f'blog/{url_name}.html')

    if os.path.exists(template_path):
        with open(template_path, 'r', encoding='utf-8') as f:
            page_html = f.read()

        # Basic replacements
        page_html = page_html.replace('UrlName', url_name)
        page_html = page_html.replace('ArticleName', article_name)
        page_html = page_html.replace('假設這是描述', description)
        page_html = page_html.replace('假設這是關鍵字', keywords)

        # Hero tags replacement
        # Find: <div class="tags">...</div> inside hero column
        tag_html = '\n'.join([f'\t\t\t\t\t\t\t<div class="tag">{t}</div>' for t in tags])
        page_html = re.sub(
            r'(<div class="hero column">.*?<div class="tags">).*?(</div>\s*<div class="date">)',
            rf'\1\n{tag_html}\n\t\t\t\t\t\t\2',
            page_html,
            flags=re.DOTALL
        )

        # Hero date replacement
        page_html = re.sub(
            r'(<div class="hero column">.*?<div class="date">).*?(</div>)',
            rf'\g<1>{date_formatted}\g<2>',
            page_html,
            flags=re.DOTALL
        )

        # Content replacement
        page_html = re.sub(
            r'(<!-- Content -->\s*<div class="content column gap-frame-half">).*?(</div>\s*</div>\s*</div>\s*</section>)',
            rf'\1\n{content_html}\n\t\t\t\t\t\2',
            page_html,
            flags=re.DOTALL
        )

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(page_html)
        print(f"Created {output_path}")

    else:
        print(f"File not found: {template_path}")

if __name__ == "__main__":
    main()
