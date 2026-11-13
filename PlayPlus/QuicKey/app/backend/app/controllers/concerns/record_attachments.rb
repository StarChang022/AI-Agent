# 支出、收入、資金移轉共用：建立 / 編輯時掛上暫存檔、編輯頁刪除已存圖檔（docs/dev/attachments-api.md 第 3、4 節）。
module RecordAttachments
  extend ActiveSupport::Concern

  private

  # 存檔前呼叫：取出 attachment_ids 對應的檔案並檢查張數。沒帶回空陣列。
  def claim_attachments(record)
    blobs = AttachmentFiles.claim!(current_user, params[:attachment_ids])
    AttachmentFiles.check_count!(record, blobs)
    blobs
  end

  # 交易內、存檔後呼叫：新檔案接在最後。有新掛上時回 [前檔名陣列, 後檔名陣列]（寫稽核用），否則 nil。
  def attach_claimed!(record, blobs)
    return nil if blobs.empty?

    before = AttachmentFiles.filenames(AttachmentFiles.blobs_of(record))
    return nil unless AttachmentFiles.append!(record, blobs)

    # 只有圖檔變更時才更新 updated_at；欄位也有變更時已更新過，再 touch 會清掉稽核要用的 saved_changes
    record.touch unless record.previously_new_record? || record.saved_changes?
    [ before, AttachmentFiles.filenames(AttachmentFiles.blobs_of(record)) ]
  end

  # 編輯頁刪除已存圖檔：立即生效，寫 update 稽核（前後列檔名）。交易結束後才刪實體檔案，
  # 其他紀錄（例如代墊款）還在用的檔案保留。
  def remove_attachment!(record)
    blob = nil
    ActiveRecord::Base.transaction do
      record.lock!
      before = AttachmentFiles.filenames(AttachmentFiles.blobs_of(record))
      blob = AttachmentFiles.detach!(record, params[:attachment_id])
      if blob.nil?
        raise AttachmentFiles::Error.new("ATTACHMENT_NOT_FOUND", "找不到這張圖檔，請重新整理", status: :not_found)
      end

      record.touch
      AuditLog.record!(record, action: "update", by: current_user,
        before: { attachments: before },
        after:  { attachments: AttachmentFiles.filenames(AttachmentFiles.blobs_of(record)) })
    end
    AttachmentFiles.purge_unused([ blob ])
  end

  # update 稽核：欄位 diff 加上圖檔變更（前後檔名陣列），兩者都沒有就不寫。
  def audit_update_with_attachments!(record, fields, attachments_change)
    diff = record.saved_changes.slice(*fields)
    before, after = diff.empty? ? [ {}, {} ] : AuditLog.update_payload(diff)
    if attachments_change
      before["attachments"], after["attachments"] = attachments_change
    end
    return if before.empty? && after.empty?

    AuditLog.record!(record, action: "update", by: current_user, before: before, after: after)
  end

  def render_in_trash
    render json: { error: "IN_TRASH", message: "這筆紀錄在垃圾桶內，還原後才能刪除圖檔" }, status: :conflict
  end
end
