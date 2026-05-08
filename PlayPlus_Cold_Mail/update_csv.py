import pandas as pd

df = pd.read_csv('冷郵件對象/名單副本.csv')

# Helper function to set values
def set_emails(index, d1_t, d1_c, d7_t, d7_c, d14_t, d14_c, d30_t, d30_c, d60_t, d60_c):
    df.at[index, 'day1_title'] = d1_t
    df.at[index, 'day1_content'] = d1_c
    df.at[index, 'day7_title'] = d7_t
    df.at[index, 'day7_content'] = d7_c
    df.at[index, 'day14_title'] = d14_t
    df.at[index, 'day14_content'] = d14_c
    df.at[index, 'day30_title'] = d30_t
    df.at[index, 'day30_content'] = d30_c
    df.at[index, 'day60_title'] = d60_t
    df.at[index, 'day60_content'] = d60_c

df.to_csv('冷郵件對象/名單副本.csv', index=False)
print("Updated successfully")
