from bs4 import BeautifulSoup
import re

with open("test_104.html", "r", encoding="utf-8") as f:
    soup = BeautifulSoup(f, "html.parser")

for a in soup.find_all('a'):
    href = a.get('href', '')
    if 'pd-polymer.com' in href:
        print(f"Found URL tag: {a.prettify()}")

print("Profile 1 tag:")
p1 = soup.find('p', class_='intro-profile mb-0 text-break')
if p1:
    print(p1.prettify())

print("Profile 2 tag:")
p2 = soup.find('p', class_='r3 mb-0 text-break')
if p2:
    print(p2.prettify())
