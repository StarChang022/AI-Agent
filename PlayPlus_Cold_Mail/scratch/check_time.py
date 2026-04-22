import http.client
import time
import datetime

def get_google_time():
    conn = http.client.HTTPConnection("google.com")
    conn.request("GET", "/")
    res = conn.getresponse()
    date_str = res.getheader('date')
    # date_str is like 'Wed, 22 Apr 2026 05:31:00 GMT'
    google_time = datetime.datetime.strptime(date_str, '%a, %d %b %Y %H:%M:%S %Z')
    return google_time

local_time = datetime.datetime.utcnow()
google_time = get_google_time()

print(f"Local UTC:  {local_time}")
print(f"Google UTC: {google_time}")
print(f"Diff:       {local_time - google_time}")
