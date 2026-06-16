import os
import json
import vertexai
from vertexai.generative_models import GenerativeModel

key_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/eternal-skyline-494002-j8-356884d3e786.json"
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = key_path

try:
    with open(key_path, 'r') as f:
        key_data = json.load(f)
    project_id = key_data["project_id"]
    print("Project ID:", project_id)
    
    vertexai.init(project=project_id, location="us-central1")
    model = GenerativeModel("gemini-1.5-flash-002")
    response = model.generate_content("Hello! What is your name?")
    print("Response text:", response.text)
except Exception as e:
    print("Error during test:", e)
