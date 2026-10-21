import re
from bs4 import BeautifulSoup

EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')

html = "a" * 100000 + "@" + "b" * 100000 + "." + "c" * 100000
print("Testing Regex...")
EMAIL_REGEX.findall(html)
print("Regex done.")

print("Testing BeautifulSoup...")
soup = BeautifulSoup(html, 'html.parser')
print("BS done.")
