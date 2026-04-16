import requests
import re
from bs4 import BeautifulSoup

try:
    import whois
except ImportError:
    whois = None

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
}

def test_104(url):
    print(f"Testing 104 URL: {url}")
    try:
        resp = requests.get(url, headers=HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, 'html.parser')
        text = soup.get_text(" ")
        emails = re.findall(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", text)
        print("Mails found in 104:", set([e.lower() for e in emails]))
    except Exception as e:
        print("104 Exception:", e)
        
def test_whois(domain):
    print(f"Testing WHOIS: {domain}")
    if not whois:
        print("python-whois module not installed.")
        return
    try:
        w = whois.whois(domain)
        emails = w.emails
        if type(emails) is str:
            emails = [emails]
        if emails:
            print("Mails found in WHOIS:", set([e.lower() for e in emails]))
        else:
            print("No mails found in WHOIS.")
    except Exception as e:
        print("WHOIS Exception:", e)

test_104("https://www.104.com.tw/company/1a2x6bhzvo")
test_whois("biocutin.com.tw")
test_whois("arecnetworks.com.tw")
