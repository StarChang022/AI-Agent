# 註冊非預設的 MIME type。
# xlsx 由 reports controller 用於匯出 Excel；caxlsx gem 產出 OOXML spreadsheet。
Mime::Type.register "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :xlsx
