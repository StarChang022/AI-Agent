import requests
import re
from bs4 import BeautifulSoup

def is_valid_email(email: str) -> bool:
    return True

EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')

def extract_emails_from_html(html: str):
    emails = set()
    soup = BeautifulSoup(html, 'html.parser')
    for a in soup.find_all('a', href=True):
        pass
    decoded_text = soup.get_text()
    for email in EMAIL_REGEX.findall(decoded_text):
        emails.add(email.lower())
    for email in EMAIL_REGEX.findall(html):
        emails.add(email.lower())
    return emails

for url in ["http://floorworks.net", "http://twpemay.com", "http://ksnak.com"]:
    try:
        html = requests.get(url, timeout=10).text
        print(f"Downloaded {url}, size: {len(html)}")
        extract_emails_from_html(html)
        print(f"Parsed {url}")
    except Exception as e:
        print(f"Error {url}: {e}")
