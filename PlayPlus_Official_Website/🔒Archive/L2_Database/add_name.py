import os

base_dir = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Official_Website/文案內容/portfolio'

files = [
    'anest.md', 'chaodays.md', 'chrb.md', 'chuang-jie.md', 'frontier.md',
    'hongguanartonline.md', 'investanchors.md', 'isi.md', 'j-garden.md',
    'kingspace.md', 'mitac-meeting-room-booking-system.md', 'neopsy.md',
    'optree.md', 'secom-esg.md', 'secom-sigmu-articles.md',
    'secom-smarthome.md', 'siangyu.md', 'starworld_2-0.md', 'stemcell.md',
    'tfif-app.md', 'tsn.md', 'virtualman.md', 'wmoon.md'
]

for file in files:
    path = os.path.join(base_dir, file)
    if not os.path.exists(path):
        print(f"File not found: {path}")
        continue
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    lines = content.split('\n')
    
    # 1. Find the title line and extract the name
    extracted_name = ""
    for line in lines:
        if line.startswith('**title**:'):
            title_val = line.split('**title**:')[1].strip()
            # Normalize full-width pipes to half-width pipes
            normalized_title = title_val.replace('｜', '|')
            if '|' in normalized_title:
                parts = normalized_title.split('|')
                extracted_name = parts[-1].strip()
            else:
                print(f"Warning: No '|' or '｜' found in title of {file}: {title_val}")
            break
            
    # 2. Filter out any existing **name**: line
    cleaned_lines = [l for l in lines if not l.startswith('**name**:')]
    
    # 3. Find **list-summary**: and insert **name**: above it
    final_lines = []
    inserted = False
    for line in cleaned_lines:
        if line.startswith('**list-summary**:'):
            final_lines.append(f"**name**: {extracted_name}")
            inserted = True
        final_lines.append(line)
        
    if not inserted:
        print(f"Warning: Could not find list-summary in {file} to insert name.")
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(final_lines))
    print(f"Processed {file} -> name: {extracted_name}")

print("Batch Update Name Completed!")
