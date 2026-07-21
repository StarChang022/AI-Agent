import json

json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"
with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for comp, emails in data.items():
    for key in ['day1_title', 'day7_title', 'day30_title']:
        if key in emails and isinstance(emails[key], str):
            if "關於" in emails[key] and "的流程優化經驗" in emails[key]:
                emails[key] = emails[key].replace("關於", "").replace("的流程優化經驗", "的流程優化案例分享")
            elif "關於優化報帳流程的最後一封信" in emails[key]:
                emails[key] = emails[key].replace("關於優化報帳流程的最後一封信", "優化報帳流程的最後一封信")

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Updated temporary JSON successfully.")
