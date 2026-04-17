import os
import glob

base_dir = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"

extensions = ["*.csv", "*.py", "*.md"]

for ext in extensions:
    for filepath in glob.glob(os.path.join(base_dir, "**", ext), recursive=True):
        if not os.path.isfile(filepath):
            continue
            
        try:
            with open(filepath, "r", encoding="utf-8-sig") as f:
                content = f.read()
                
            if "email" in content:
                new_content = content.replace("email", "email")
                with open(filepath, "w", encoding="utf-8-sig") as f:
                    f.write(new_content)
                print(f"Updated: {filepath}")
        except Exception as e:
            print(f"Error on {filepath}: {e}")
