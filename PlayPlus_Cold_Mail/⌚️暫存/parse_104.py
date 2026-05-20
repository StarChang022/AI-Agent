from bs4 import BeautifulSoup

with open("test_104.html", "r", encoding="utf-8") as f:
    soup = BeautifulSoup(f, "html.parser")

print("--- Paragraphs ---")
for i, p in enumerate(soup.find_all('p')[:20]):
    print(f"[{i}] class={p.get('class')}: {p.text.strip()[:100]}")

print("\n--- Links ---")
for i, a in enumerate(soup.find_all('a')):
    href = a.get('href', '')
    if '104.com.tw' not in href and href.startswith('http'):
        print(f"External Link: href={href} class={a.get('class')} text={a.text.strip()} title={a.get('title')}")
