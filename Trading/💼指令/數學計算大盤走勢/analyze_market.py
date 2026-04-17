import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy import stats
import os
import datetime

# Set plotting style
plt.style.use('fivethirtyeight')

# Path to the data file
CSV_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/股票/0000加權指數/大盤交易資料.csv'
REPORT_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/💼指令/數學計算大盤走勢/✅數學計算大盤走勢.md'
ARTIFACTS_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/💼指令/數學計算大盤走勢/charts'

# Create chart directory
os.makedirs(ARTIFACTS_DIR, exist_ok=True)

def clean_value(val):
    if isinstance(val, str):
        return float(val.replace(',', '').replace('"', ''))
    return val

# 1. Data Loading
print("Loading data...")
df = pd.read_csv(CSV_PATH)

# Auto-detect columns based on common names to ensure future compatibility
col_mapping = {}
for col in df.columns:
    col_str = str(col).lower()
    if any(k in col_str for k in ['日期', 'date', 'time']): col_mapping[col] = '交易日期'
    elif any(k in col_str for k in ['開盤', 'open']): col_mapping[col] = '開盤'
    elif any(k in col_str for k in ['最高', 'high']): col_mapping[col] = '最高'
    elif any(k in col_str for k in ['最低', 'low']): col_mapping[col] = '最低'
    elif any(k in col_str for k in ['收盤', 'close']): col_mapping[col] = '收盤'

df = df.rename(columns=col_mapping)

required_cols = ['交易日期', '開盤', '最高', '最低', '收盤']
if not all(c in df.columns for c in required_cols):
    raise ValueError(f"Missing required columns. Found: {list(df.columns)}")

# Convert columns to numeric
for col in required_cols[1:]: # Skip '交易日期'
    if df[col].dtype == object or df[col].dtype == str:
        df[col] = df[col].apply(clean_value)

# Convert 交易日期 to datetime
df['交易日期'] = pd.to_datetime(df['交易日期'])
df = df.sort_values('交易日期').reset_index(drop=True)

# Filter for past 5 years
last_date = df['交易日期'].max()
five_years_ago = last_date - pd.DateOffset(years=5)
df_recent = df[df['交易日期'] >= five_years_ago].copy()

# Helper for Win (漲) - Close > Open
df_recent['Win'] = (df_recent['收盤'] > df_recent['開盤']).astype(int)

# ---------------------------------------------------------
# Part 1: Markov Chain (馬可夫鏈)
# ---------------------------------------------------------
print("Running Markov Chain analysis...")
# Transitions: (t-2, t-1) -> t
df_recent['S1'] = df_recent['Win'].shift(1)
df_recent['S2'] = df_recent['Win'].shift(2)

# All 3-day sequence combinations (S2, S1, Win)
seq_counts = df_recent.groupby(['S2', 'S1', 'Win']).size().unstack(fill_value=0)
seq_counts.index = seq_counts.index.map(lambda x: ('UP' if x[0] == 1 else 'DOWN', 'UP' if x[1] == 1 else 'DOWN'))
seq_counts.columns = ['Loss', 'Win']

# Probabilities
seq_probs = seq_counts.div(seq_counts.sum(axis=1), axis=0)

# Target:连续2天涨后，第3天涨的几度
p_win_after_2_win = seq_probs.loc[('UP', 'UP'), 'Win']

# Frequency of all 3-day sequences (t-2, t-1, t)
sequences = []
states = [0, 1]
for s2 in states:
    for s1 in states:
        for s0 in states:
            pattern = ('UP' if s2 == 1 else 'DOWN', 'UP' if s1 == 1 else 'DOWN', 'UP' if s0 == 1 else 'DOWN')
            count = len(df_recent[(df_recent['S2'] == s2) & (df_recent['S1'] == s1) & (df_recent['Win'] == s0)])
            prob = count / (len(df_recent) - 2)
            sequences.append({'Pattern': pattern, 'Count': count, 'Probability': f"{prob:.2%}"})

# ---------------------------------------------------------
# Part 2: Monte Carlo Simulation (蒙地卡羅模擬)
# ---------------------------------------------------------
print("Running Monte Carlo simulation...")
returns = np.log(df_recent['收盤'] / df_recent['收盤'].shift(1)).dropna()
mu = returns.mean()
sigma = returns.std()

last_price = df_recent['收盤'].iloc[-1]
days = 10
simulations = 10000

# Geometric Brownian Motion simulation
daily_returns = np.exp((mu - 0.5 * sigma**2) + sigma * np.random.standard_normal((days, simulations)))
price_paths = np.zeros_like(daily_returns)
price_paths[0] = last_price * daily_returns[0]
for t in range(1, days):
    price_paths[t] = price_paths[t-1] * daily_returns[t]

final_prices = price_paths[-1]
lower_ci = np.percentile(final_prices, 2.5)
upper_ci = np.percentile(final_prices, 97.5)
med_price = np.median(final_prices)

# Plotting simulation results
plt.figure(figsize=(10, 6))
plt.hist(final_prices, bins=50, alpha=0.7, color='skyblue', edgecolor='black')
plt.axvline(last_price, color='red', linestyle='--', label=f'Current Price: {last_price:.0f}')
plt.axvline(lower_ci, color='green', linestyle=':', label=f'2.5% CI: {lower_ci:.0f}')
plt.axvline(upper_ci, color='green', linestyle=':', label=f'97.5% CI: {upper_ci:.0f}')
plt.axvline(med_price, color='orange', linestyle='-', label=f'Median: {med_price:.0f}')
plt.title(f'Monte Carlo Simulation: 10-Day Index Distribution (10,000 runs)')
plt.xlabel('Price')
plt.ylabel('Frequency')
plt.legend()
monte_carlo_plot = os.path.join(ARTIFACTS_DIR, 'monte_carlo.png')
plt.savefig(monte_carlo_plot)
plt.close()

# ---------------------------------------------------------
# Part 3: RSI Feature Engineering & Statistical Testing
# ---------------------------------------------------------
print("Running RSI analysis...")
def calculate_rsi(data, window=14):
    delta = data.diff()
    up = delta.where(delta > 0, 0)
    down = -delta.where(delta < 0, 0)
    avg_gain = up.rolling(window=window).mean()
    avg_loss = down.rolling(window=window).mean()
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))

df_recent['RSI'] = calculate_rsi(df_recent['收盤'])
df_recent['Next_Win'] = (df_recent['收盤'].shift(-1) > df_recent['開盤'].shift(-1)).astype(int)

# Bucket RSI
breaks = range(0, 110, 10)
df_recent['RSI_Bucket'] = pd.cut(df_recent['RSI'], bins=breaks, labels=[f"{i}-{i+10}" for i in range(0, 100, 10)])

rsi_stats = df_recent.dropna(subset=['RSI_Bucket', 'Next_Win']).groupby('RSI_Bucket', observed=False)['Next_Win'].agg(['count', 'mean'])
rsi_stats = rsi_stats.rename(columns={'mean': 'WinRate'})

# Overall win rate baseline
baseline_win_rate = df_recent['Next_Win'].mean()

# Calculate P-value (one-sided binomial test: is win rate different from baseline)
def safe_binom(count, win_rate, p_base):
    if count == 0 or np.isnan(win_rate):
        return 1.0
    k = int(round(count * win_rate))
    n = int(count)
    return stats.binomtest(k, n, p=p_base).pvalue

rsi_stats['P_Value'] = rsi_stats.apply(lambda x: safe_binom(x['count'], x['WinRate'], baseline_win_rate), axis=1)
rsi_stats['ExpectedValue'] = (rsi_stats['WinRate'] - baseline_win_rate) * 100 # Profitability nudge vs baseline

# ---------------------------------------------------------
# Part 4: Candlestick Pattern (K線形態歷史勝率)
# ---------------------------------------------------------
print("Running Candlestick pattern analysis...")
# Long Lower Shadow: (min(O,C) - L) > 2 * abs(O-C)
df_recent['Body'] = abs(df_recent['收盤'] - df_recent['開盤'])
df_recent['LowerShadow'] = df_recent[['開盤', '收盤']].min(axis=1) - df_recent['最低']
df_recent['Is_LongLowerShadow'] = (df_recent['LowerShadow'] > 2 * df_recent['Body']) & (df_recent['Body'] > 0)

# Performance: T+1, T+3, T+5 returns
df_recent['Ret1'] = (df_recent['收盤'].shift(-1) / df_recent['收盤']) - 1
df_recent['Ret3'] = (df_recent['收盤'].shift(-3) / df_recent['收盤']) - 1
df_recent['Ret5'] = (df_recent['收盤'].shift(-5) / df_recent['收盤']) - 1

pattern_df = df_recent[df_recent['Is_LongLowerShadow']].copy()

metrics = {}
for h in [1, 3, 5]:
    ret_col = f'Ret{h}'
    valid_returns = pattern_df[ret_col].dropna()
    if len(valid_returns) > 0:
        win_rate = (valid_returns > 0).mean()
        avg_ret = valid_returns.mean()
        wins = valid_returns[valid_returns > 0]
        losses = valid_returns[valid_returns <= 0]
        pl_ratio = abs(wins.mean() / losses.mean()) if len(losses) > 0 else float('inf')
        metrics[h] = {'Sample': len(valid_returns), 'WinRate': win_rate, 'AvgRet': avg_ret, 'PL_Ratio': pl_ratio}

# Plot distribution for T+1 returns
if len(pattern_df) > 0:
    plt.figure(figsize=(10, 6))
    plt.hist(pattern_df['Ret1'].dropna() * 100, bins=20, color='salmon', edgecolor='black')
    plt.axvline(0, color='black', linestyle='--')
    plt.title('Distribution of 1-Day Returns After Long Lower Shadow Pattern')
    plt.xlabel('Return (%)')
    plt.ylabel('Frequency')
    pattern_plot = os.path.join(ARTIFACTS_DIR, 'pattern_returns.png')
    plt.savefig(pattern_plot)
    plt.close()

# ---------------------------------------------------------
# Generate Markdown Report
# ---------------------------------------------------------
print("Generating report...")
today_str = datetime.date.today().strftime("%Y-%m-%d")

report = f"""# 數學計算大盤走勢分析報告
**報告日期**: {today_str}

本報告基於過去 5 年的加權指數大盤數據，從數學與統計學角度對市場走勢、規律及特定指標進行深度分析。

## 1. 馬可夫鏈 (Markov Chain)
分析過去 5 年數據，統計連續 2 天上漲後第 3 天的行情機率。

- **連續 2 天上漲後第 3 天上漲機率**: **{p_win_after_2_win:.2%}**
- **所有三日序列組合統計**:

| 序列組合 (T-2, T-1, T) | 次數 | 機率分佈 |
| :--- | :--- | :--- |
"""

for s in sorted(sequences, key=lambda x: x['Pattern']):
    p_str = '-'.join(s['Pattern'])
    report += f"| {p_str} | {s['Count']} | {s['Probability']} |\n"

report += f"""
## 2. 蒙地卡羅模擬 (Monte Carlo Simulation)
基於幾何布朗運動 (GBM)，對未來 10 個交易日的價格路徑進行 10,000 次模擬。

- **數據基準 (過去 5 年)**: 
  - 每日對數收益率平均值 (μ): {mu:.6f}
  - 每日對數收益率標準差 (σ): {sigma:.6f}
- **模擬預測 (10 天後)**:
  - **目前價格**: {last_price:.2f}
  - **機率最高價格 (中位數)**: {med_price:.2f}
  - **95% 置信區間 (CI)**: [{lower_ci:.2f}, {upper_ci:.2f}]

![蒙地卡羅模擬分布圖](file://{monte_carlo_plot})

## 3. 特徵工程與統計檢定 (RSI 指標分析)
分析 RSI (14) 指標在不同區間時，隔天 K 線收紅的勝率與期望值。

| RSI 區間 | 樣本數 | 隔天勝率 | 期望值增量 | P-value |
| :--- | :--- | :--- | :--- | :--- |
"""

for bucket, row in rsi_stats.iterrows():
    p_val_mark = " (顯著)" if row['P_Value'] < 0.05 else ""
    report += f"| {bucket} | {int(row['count'])} | {row['WinRate']:.2%} | {row['ExpectedValue']:.2f}% | {row['P_Value']:.4f}{p_val_mark} |\n"

report += f"""
## 4. K線形態歷史勝率 (長下影線)
識別特徵：影線長度 > 實體長度 2 倍。

- **總樣本數**: {len(pattern_df)}
- **績效統計**:

| 持有期間 | 平均報酬率 | 勝率 | 盈虧比 (P/L) |
| :--- | :--- | :--- | :--- |
"""

for h, m in metrics.items():
    report += f"| {h} 天 | {m['AvgRet']:.2%} | {m['WinRate']:.2%} | {m['PL_Ratio']:.2f} |\n"

report += f"""
![長下影線後 1 日收益分佈](file://{pattern_plot})

## 總結與結論
1. **短期慣性**: 根據馬可夫鏈分析，{'連續上漲具備一定的慣性' if p_win_after_2_win > 0.5 else '連續上漲後回檔機率較高'}，目前的『漲-漲-漲』機率為 {p_win_after_2_win:.2%}。
2. **波動預期**: 蒙地卡羅模擬顯示，未來 10 天的價格波動中心位於 {med_price:.2f}，波動範圍較大的區間在 {lower_ci:.2f} 至 {upper_ci:.2f} 之間。
3. **指標指引**: RSI 在 **{rsi_stats['WinRate'].idxmax()}** 區間時具備最高的隔天勝率 ({rsi_stats['WinRate'].max():.2%})。
4. **形態戰備**: 「長下影線」在 T+5 的平均報酬率為 {metrics.get(5, {}).get('AvgRet', 0):.2%}，勝率為 {metrics.get(5, {}).get('WinRate', 0):.2%}，{'顯示該形態在短中期具備抄底價值' if metrics.get(5, {}).get('AvgRet', 0) > 0 else '顯示該形態目前無顯著獲利空間'}。

"""

# Explicit Trading Recommendation Logic
expected_trend = (med_price - last_price) / last_price
if expected_trend > 0.005 and p_win_after_2_win > 0.5:
    recommendation = "**買進 (Buy)** - 動量與短期期望值皆偏多"
elif expected_trend < -0.005 and p_win_after_2_win < 0.5:
    recommendation = "**賣出 (Sell)** - 動量與短期期望值皆偏空"
else:
    recommendation = "**觀望 (Wait)** - 市場訊號分歧或缺乏顯著方向性"

report += f"### 💡 未來20個交易日明確交易建議\n基於上述數學與統計分析的總和考量，接下來「未來20個交易日」的交易建議為：{recommendation}\n\n"


with open(REPORT_PATH, 'w', encoding='utf-8') as f:
    f.write(report)

print(f"Report generated successfully at: {REPORT_PATH}")
