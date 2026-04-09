import csv
import io

file_path = '/Users/starchang/Documents/CloudFolder/01 GitHub/AI-Agent/PlayPlus Cold Mail/冷郵件對象/20260409.csv'

# Data for Day 7
day7_data = [
    {
        "title": "Re: 【商務聯繫】致營運部與人資負責人",
        "content": "您好，想確認您是否有收到我上週關於「貿易內部系統優化」的信件？若貴公司正忙於電商部門與跨國團隊的擴編，或許我們可以先針對小部分的優化進行簡短交流。\n\n可以從 https://playplus.com.tw/ 參考我們的案例。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致採購部與營運負責人",
        "content": "您好，冒昧再打擾，想確認您之前是否有收到關於「跨國供應鏈系統優化」的提案？考慮到貴公司在泰國與越南的佈局，若近期正忙於全球採購團隊的擴張，我們很樂意提供相關系統建置案例供您參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 傢寓電商平台如何更有效承接品牌流量？",
        "content": "您好，想跟您確認一下是否有收到上週關於「傢俱電商平台優化」的訊息？若貴團隊正專注於三創門市與網購通路的擴張，或許我們可以找個時間聊聊如何讓線上平台更高效地承接流量。\n\n歡迎從 https://playplus.com.tw/ 參考我們的作品。\n\n感謝您"
    },
    {
        "title": "Re: 提升加值代理業務的數位營運效率",
        "content": "李協理 您好，幾天前寄了一封關於「B2B 科技代理商數位轉型」的郵件給您，不知道您是否有空看過了？若軍崴科技近期正忙於產品經理與技術團隊的擴編，我們能提供相關營運優化範例供您參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致行銷與業務部負責人",
        "content": "您好，想跟您追蹤一下是否有收到關於「重塑 KYB 品牌網站形象」的信件？若貴公司正忙於招募國貿業務夥伴，或許我們可以針對如何利用數位門面提升業務推廣效率快速聊聊。\n\n更多案例請參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致電商與行銷部負責人",
        "content": "您好，想確認您是否有收到上週關於「保健品牌電商體驗優化」的提案？若華世正積極擴展電商與通路業務，我們可以先分享一份針對此產業的平台建置案例供您評估：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致品牌與行銷總監",
        "content": "您好，想確認您之前是否有收到關於「空間美學作品集優化」的信件？若貴團隊近期正忙於品牌策略與視覺企劃的擴編，我們很樂意分享如何透過模組化設計展現您的專業。\n\n作品集請參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致行銷與電商營運負責人",
        "content": "您好，冒昧追蹤一下，想確認您是否有收到關於「食品電商 LINE 客服自動化」的訊息？若貴公司正忙於招募社群與營運夥伴，導入自動化工具或許能大幅減輕團隊負擔。\n\n專案案例請參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 降低食品電商的客服與營運溝通成本",
        "content": "Gaby 您好，想確認您是否有收到上週關於「LINE 客服與營運自動化」的信件？若瑞亞近期正忙於理貨與社群團隊的擴編，或許我們可以找個幾分鐘聊聊如何透過工具提升效率。\n\n歡迎參考我們的作品：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致業務與行銷部負責人",
        "content": "您好，想確認您是否有收到關於「旅館產業數位展示平台優化」的提案？即使目前團隊營運穩定，建立更強的數位防禦力對全球拓展至關重要。我們可以先寄送相關案例供您評估：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致行銷與專案部負責人",
        "content": "您好，想確認您之前是否有收到關於「農產品品牌信任感優化」的信件？若貴公司正忙於通路開發與專案擴張，一個能清晰展示安全價值的網站將會是很好的助力。\n\n更多服務請見：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致行銷與產品開發部負責人",
        "content": "您好，想確認您是否有收到上週關於「醫藥等級數位門面優化」的信件？若貴團隊正專注於產品行銷的擴張，或許我們可以針對如何轉化研發實力為視覺語言進行交流。\n\n案例參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 強化醫療保健產品線的數位行銷效能",
        "content": "Jackie 您好，想確認您是否有收到關於「醫療保健產品線數位展示優化」的提案？若致勝近期正忙於行銷專員的招募，我們可以先提供相關案例供您評估如何提升團隊效率。\n\n歡迎參考：https://playplus.com.tw/。\n\n感謝您"
    },
    {
        "title": "Re: 【商務聯繫】致行銷與業務部負責人",
        "content": "您好，冒昧追蹤一下，想確認您是否有收到關於「影音系統整合業網站優化」的信件？在穩定的營運基礎上強化數位門面，能為未來的市場競爭打下更好的基礎。\n\n作品集請參考：https://playplus.com.tw/。\n\n感謝您"
    }
]

rows = []
with open(file_path, mode='r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    for i, row in enumerate(reader):
        if i < len(day7_data):
            # Indices based on header:
            # Day 7 -> 16
            # day7_title -> 17
            # day7_content -> 18
            row[17] = day7_data[i]["title"]
            row[18] = day7_data[i]["content"]
            # Ensure Day 7 date is set (if not already there)
            if not row[16]:
                row[16] = "2026/4/15"
        rows.append(row)

with open(file_path, mode='w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(rows)

print("Updated Day 7 titles and contents.")
