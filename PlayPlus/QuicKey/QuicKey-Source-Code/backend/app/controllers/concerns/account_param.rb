# 寫入收支時解析 params[:account_id]：只接受本公司未刪除的帳戶。
# 沒帶或無效時 render 錯誤並回 nil（呼叫端以 performed? 判斷）。
module AccountParam
  extend ActiveSupport::Concern

  private

  def find_account_param
    if params[:account_id].blank?
      render json: { error: "ACCOUNT_REQUIRED", message: "請選擇帳戶" }, status: :unprocessable_content
      return nil
    end

    account = current_user.company.accounts.kept.find_by(id: params[:account_id])
    return account if account

    render json: { error: "ACCOUNT_NOT_FOUND", message: "找不到這個帳戶，請重新選擇" }, status: :unprocessable_content
    nil
  end
end
