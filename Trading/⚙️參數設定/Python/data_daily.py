import subprocess
import sys
import os
import time

def run_script(script_name, description):
    """
    執行指定的 Python 腳本並輸出結果。
    """
    # 獲取目前檔案所在的目錄
    base_dir = os.path.dirname(os.path.abspath(__file__))
    script_path = os.path.join(base_dir, script_name)
    
    print("=" * 50)
    print(f"🚀 正在啟動: {description} ({script_name})")
    print(f"⏰ 開始時間: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 50)
    
    try:
        # 使用目前的 Python 解譯器執行
        result = subprocess.run([sys.executable, script_path], check=True)
        print("-" * 50)
        print(f"✅ {description} 執行成功！")
    except subprocess.CalledProcessError as e:
        print("-" * 50)
        print(f"❌ {description} 執行失敗。錯誤代碼: {e.returncode}")
        # 如果需要可以在失敗時中斷
        # sys.exit(1)
    except FileNotFoundError:
        print("-" * 50)
        print(f"❌ 找不到檔案: {script_path}")
    
    print(f"⏰ 結束時間: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

def main():
    start_all = time.time()
    
    # 定義要執行的腳本及其描述
    scripts_to_run = [
        ("data_daily_Stocks.py", "個股交易資訊"),
        ("data_daily_TAIEX.py", "加權指數交易資訊 (TAIEX)"),
        ("data_daily_TPEx.py", "櫃買指數交易資訊 (TPEx)")
    ]
    
    print("🌟🌟🌟  開始執行每日數據更新程序  🌟🌟🌟")
    
    for script, desc in scripts_to_run:
        run_script(script, desc)
        
    duration = time.time() - start_all
    print("=" * 50)
    print(f"🎉 所有更新任務已完成！")
    print(f"⏱️ 總耗時: {duration:.2f} 秒")
    print("=" * 50 + "\n")

if __name__ == "__main__":
    main()
