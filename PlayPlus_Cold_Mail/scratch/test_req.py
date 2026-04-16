import requests
import re
from bs4 import BeautifulSoup
import subprocess

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def get_104(url):
    print("Testing 104 URL:", url)
    res = requests.get(url, headers=HEADERS)
    print("Status code:", res.status_code)
    emails = re.findall(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", res.text)
    print("Mails:", emails)
    
def get_whois(domain):
    try:
        proc = subprocess.run(["whois", domain], capture_output=True, text=True, timeout=10)
        emails = re.findall(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}", proc.stdout)
        print("WHOIS raw emails:", set([e.lower() for e in emails]))
    except Exception as e:
        print("WHOIS error:", e)

get_104("https://www.104.com.tw/company/1a2x6bhzvo")
get_whois("biocutin.com.tw")
