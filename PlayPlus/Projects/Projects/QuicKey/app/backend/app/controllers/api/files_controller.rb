module Api
  # 讀圖檔（docs/dev/attachments-api.md「讀取」）。網址本身帶短效簽章 token，給 <img src> 用，
  # 所以不走 Bearer token；token 綁使用者，讀取時仍再檢查一次權限。
  # 無效、過期、沒有權限、檔案已刪除一律 404。
  class FilesController < ApplicationController
    skip_before_action :authenticate!

    # GET /api/files/:token?download=1
    def show
      blob, = AttachmentFiles.resolve_token(params[:token])
      return head :not_found if blob.nil?

      # 不是 JPG／PNG／PDF 的（只可能來自舊資料轉檔）一律下載，不讓瀏覽器直接開
      type = AttachmentFiles::ALLOWED_MIMES.include?(blob.content_type) ? blob.content_type : "application/octet-stream"
      download = type == "application/octet-stream" || ActiveModel::Type::Boolean.new.cast(params[:download])
      response.headers["Cache-Control"] = "private, max-age=3600"
      send_data blob.download, type: type, disposition: download ? "attachment" : "inline", filename: blob.filename.to_s
    rescue ActiveStorage::FileNotFoundError
      head :not_found
    end
  end
end
