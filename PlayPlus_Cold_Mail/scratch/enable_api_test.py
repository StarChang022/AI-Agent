import os
from google.oauth2 import service_account
from googleapiclient import discovery

CREDENTIALS_PATH = os.path.expanduser("~/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_api/eternal-skyline-494002-j8-d157225e7bdc.json")
PROJECT_ID = "eternal-skyline-494002-j8"

def enable_api():
    try:
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_PATH,
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        service = discovery.build('serviceusage', 'v1', credentials=credentials)
        
        # Check if Vertex AI (aiplatform.googleapis.com) is enabled
        service_name = f'projects/{PROJECT_ID}/services/aiplatform.googleapis.com'
        request = service.services().get(name=service_name)
        response = request.execute()
        
        if response.get('state') == 'ENABLED':
            print("Vertex AI API is already enabled.")
        else:
            print("Vertex AI API is NOT enabled. Attempting to enable...")
            op = service.services().enable(name=service_name).execute()
            print(f"Enable request sent. Operation: {op.get('name')}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    enable_api()
