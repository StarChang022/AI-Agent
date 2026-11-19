module ExcelImport
  # 整份退回的錯誤（檔案格式、缺必要欄、類別已變更等）。controller 統一轉成
  # { error: code, message } 回前端；message 可直接顯示給使用者。
  class Error < StandardError
    attr_reader :code, :status

    def initialize(code, message, status: :unprocessable_content)
      super(message)
      @code   = code
      @status = status
    end
  end
end
