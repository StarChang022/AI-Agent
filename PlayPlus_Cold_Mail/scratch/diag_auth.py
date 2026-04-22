import json
import os
from google.oauth2.service_account import Credentials
import google.auth.transport.requests

CREDENTIALS_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_api/eternal-skyline-494002-j8-d157225e7bdc.json"
SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]

with open(CREDENTIALS_PATH) as f:
    info = json.load(f)

creds = Credentials.from_service_account_info(info, scopes=SCOPES)
request = google.auth.transport.requests.Request()
print(f"Testing credentials for: {info.get('client_email')}")
try:
    creds.refresh(request)
    print("Refresh successful!")
    print(f"Token: {creds.token[:10]}...")
except Exception as e:
    print(f"Refresh failed: {e}")
