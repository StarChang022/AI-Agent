class ApplicationController < ActionController::API
  include Authenticatable

  # 圖檔上傳、掛上、刪除的錯誤（docs/dev/attachments-api.md）。
  rescue_from AttachmentFiles::Error do |e|
    render json: e.as_json, status: e.status
  end

  # 垃圾桶還原、永久刪除與連帶作廢被規則擋下（app/services/trash_actions.rb）。
  rescue_from TrashActions::Refused do |e|
    render json: e.as_json, status: e.status
  end
end
