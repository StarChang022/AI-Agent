#!/bin/bash

# 詢問用戶要複製過去的新的檔名中間的部分
read -p "請輸入新的檔名中間的部分（前綴 'sidekiq' 和副檔名 'service' 會自動添加）: " middle_part

# 構造完整的檔名
new_filename="sidekiq_${middle_part}.service"

# 檢查用戶是否輸入了檔名中間的部分
if [ -z "$middle_part" ]; then
  echo "錯誤：您必須輸入檔名中間的部分"
  exit 1
fi

# 複製 ./service/sidekiq.service 到 /lib/systemd/system 下面
sudo cp "./service/sidekiq.service" "/lib/systemd/system/$new_filename"

# 檢查檔案是否複製成功
if [ $? -ne 0 ]; then
  echo "錯誤：檔案複製失敗"
  exit 1
fi

# reload system service
sudo systemctl daemon-reload

# 啟動這個服務
sudo systemctl start "$new_filename"

# 檢查服務是否啟動成功
if systemctl --quiet is-active "$new_filename"; then
  echo "服務已成功啟動"
else
  echo "錯誤：服務啟動失敗"
  exit 1
fi

