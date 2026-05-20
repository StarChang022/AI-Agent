import os
import io
import json
import subprocess
import googleapiclient.discovery
from google.oauth2 import service_account
from googleapiclient.http import MediaIoBaseUpload
import re
import html



# Define configurations
CREDENTIALS_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/rosy-zoo-447904-j1-a600c9e990ca.json'
DOCUMENT_ID = '1e5l_alAZWkdB6UvnfOrPU_bL3l9SYokkckh2y1qGnfg'
PICTURES_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/eVendor/pictures'

def upload_to_tmpfiles(filepath):
    """
    Uploads a file to tmpfiles.org using curl and returns the direct download link.
    """
    print(f"Uploading {os.path.basename(filepath)} to temporary hosting...")
    cmd = [
        "curl", "-s",
        "-F", f"file=@{filepath}",
        "https://tmpfiles.org/api/v1/upload"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise Exception(f"curl failed: {res.stderr}")
    
    try:
        data = json.loads(res.stdout)
    except json.JSONDecodeError:
        raise Exception(f"Failed to parse response: {res.stdout}")
        
    if data.get('status') == 'success':
        url = data['data']['url']
        # Convert standard preview URL to direct download URL
        dl_url = url.replace('https://tmpfiles.org/', 'https://tmpfiles.org/dl/')
        return dl_url
    else:
        raise Exception(f"Upload API failed: {data}")

def main():
    if not os.path.exists(PICTURES_DIR):
        print(f"Error: Pictures directory '{PICTURES_DIR}' does not exist.")
        return
        
    # Get all image files and sort them alphabetically
    files = os.listdir(PICTURES_DIR)
    image_extensions = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp')
    image_files = sorted([f for f in files if f.lower().endswith(image_extensions)])
    
    if not image_files:
        print("No images found in the pictures directory.")
        return
        
    print(f"Found {len(image_files)} images to upload:")
    for img in image_files:
        print(f"  - {img}")
        
    # Authenticate with Google Drive API
    print("Authenticating with Google Drive API...")
    scopes = ['https://www.googleapis.com/auth/drive']
    creds = service_account.Credentials.from_service_account_file(CREDENTIALS_PATH, scopes=scopes)
    drive_service = googleapiclient.discovery.build('drive', 'v3', credentials=creds)
    
    # Export current Google Doc to HTML
    print("Exporting Google Doc as HTML...")
    html_bytes = drive_service.files().export(fileId=DOCUMENT_ID, mimeType='text/html').execute()
    html_text = html_bytes.decode('utf-8')
    
    # Unescape HTML entities (e.g. convert &#20379; back to Chinese characters)
    html_text_unescaped = html.unescape(html_text)
    
    # Extract all existing H3 headings from the HTML
    h3_matches = re.findall(r'<h3[^>]*>(.*?)</h3>', html_text_unescaped, re.DOTALL)
    existing_titles = []
    for h3_content in h3_matches:
        # Remove inner HTML tags (like <span>) to get plain text
        plain_text = re.sub(r'<[^>]+>', '', h3_content).strip()
        existing_titles.append(plain_text)
    
    # Process images and build the new HTML snippet to append
    image_html_snippets = []
    for filename in image_files:
        title = os.path.splitext(filename)[0]
        
        # Check if already present in the Google Doc (either with or without extension)
        if title in existing_titles or filename in existing_titles:
            print(f"Skipping '{filename}': Already present in the Google Doc.")
            continue
            
        filepath = os.path.join(PICTURES_DIR, filename)
        
        # Upload image and get URL
        try:
            img_url = upload_to_tmpfiles(filepath)
            print(f"Uploaded successfully. Temp URL: {img_url}")
        except Exception as e:
            print(f"Error uploading {filename}: {e}")
            continue
            
        # Build HTML snippet for this image
        snippet = f'<h3>{title}</h3><p><img src="{img_url}" style="width: 19cm;" /></p><p><br></p><p><br></p>'
        image_html_snippets.append(snippet)
        
    if not image_html_snippets:
        print("No images were successfully prepared for upload. Aborting document update.")
        return
        
    # Append the images snippet to the body of the HTML
    combined_images_html = "".join(image_html_snippets)
    marker = '</body>'
    if marker in html_text:
        new_html = html_text.replace(marker, combined_images_html + marker)
    else:
        new_html = html_text + combined_images_html
        
    # Update the Google Doc using Google Drive API
    print("Updating Google Doc with new image content...")
    media_body = MediaIoBaseUpload(io.BytesIO(new_html.encode('utf-8')), mimetype='text/html')
    updated_file = drive_service.files().update(
        fileId=DOCUMENT_ID,
        media_body=media_body
    ).execute()
    
    print(f"Success! Google Doc updated successfully. Document ID: {updated_file.get('id')}")

if __name__ == '__main__':
    main()
