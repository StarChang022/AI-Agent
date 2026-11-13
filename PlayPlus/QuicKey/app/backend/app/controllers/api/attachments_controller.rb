module Api
  # 圖檔暫存檔（docs/dev/attachments-api.md 第 1、2 節）。管理員、員工都可用。
  # 掛上紀錄由各紀錄的建立 / 編輯 API 處理；刪除已存圖檔由各紀錄的 attachments 子路由處理。
  class AttachmentsController < ApplicationController
    # POST /api/attachments   multipart: files[]
    def create
      files = Array(params[:files]).select { |f| f.is_a?(ActionDispatch::Http::UploadedFile) }
      blobs = AttachmentFiles.upload!(files, current_user)
      render json: { data: blobs.map { |b| AttachmentFiles.blob_json(b, current_user) } }, status: :created
    end

    # DELETE /api/attachments/:id 或 DELETE /api/attachments?ids[]=
    # 只刪自己上傳、尚未掛上的暫存檔；其餘略過，一律 204。
    def destroy
      AttachmentFiles.discard_uploads!(current_user, params[:id] ? [ params[:id] ] : params[:ids])
      head :no_content
    end
  end
end
