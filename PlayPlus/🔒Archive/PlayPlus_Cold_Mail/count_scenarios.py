import json
from collections import Counter
with open('rows_data.json', 'r') as f:
    data = json.load(f)
c = Counter([d['scenario'] for d in data])
print(c)
