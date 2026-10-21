import json
import os

json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"
scratch_dir = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/scratch"

def main():
    with open(json_path, 'r', encoding='utf-8') as f:
        records = json.load(f)
    
    os.makedirs(scratch_dir, exist_ok=True)
    
    batches = [
        (0, 25, "batch1.txt"),
        (25, 50, "batch2.txt"),
        (50, 75, "batch3.txt"),
        (75, len(records), "batch4.txt")
    ]
    
    for start, end, filename in batches:
        out_path = os.path.join(scratch_dir, filename)
        with open(out_path, 'w', encoding='utf-8') as f:
            for r in records[start:end]:
                f.write(f"=== INDEX {r['row_idx']} | {r['name']} ===\n")
                f.write(f"{r['desc'].strip()}\n\n")
        print(f"Wrote {filename} ({start} to {end-1})")

if __name__ == "__main__":
    main()
