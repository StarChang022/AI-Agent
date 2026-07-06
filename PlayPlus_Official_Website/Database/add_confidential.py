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
    
    if '**confidential**:' in content:
        print(f"Skipping {file}, already contains confidential")
        continue

    lines = content.split('\n')
    new_lines = []
    found = False
    for line in lines:
        new_lines.append(line)
        if line.startswith('**urlwebsite**:'):
            new_lines.append('**confidential**: No')
            found = True
            
    if not found:
        print(f"Warning: urlwebsite tag not found in {file}")
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))
    print(f"Updated {file}")

print("Batch Update Completed!")
