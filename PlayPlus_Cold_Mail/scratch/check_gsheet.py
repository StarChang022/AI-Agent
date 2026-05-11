import sys
import os

# Add the directory to sys.path
script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
crawler_dir = os.path.join(parent_dir, "⚙️參數設定", "crawler_104_python")
sys.path.append(crawler_dir)

import gsheet_helper as gs

def check():
    try:
        service = gs.get_service()
        rows, fieldnames = gs.read_all_rows(service)
        print(f"Fieldnames: {fieldnames}")
        print(f"Row count: {len(rows)}")
        if rows:
            print("First row data sample:")
            for k, v in rows[0].items():
                print(f"  {k}: {v}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check()
