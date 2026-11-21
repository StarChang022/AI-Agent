module ExpenseTrash
  # 支出的還原、永久刪除與連帶作廢來源代墊款。單筆 API、批次 API 共用（docs/dev/trash-batch-api.md）。
  # 規則不允許時丟 TrashActions::Refused；每次呼叫各自一個交易。
  Refused = TrashActions::Refused

  module_function

  # 從垃圾桶還原：清掉 deleted_at，狀態保留。
  # 手續費支出只能經由移轉還原（PRD 第 19 條）；來源代墊款已作廢的要先到請款記錄取消作廢。
  def restore!(expense, by:)
    if expense.transfer_fee?
      raise Refused.new("TRANSFER_FEE_LOCKED", :conflict, "資金移轉產生的手續費支出不可還原，請到移轉處理")
    end
    if expense.source_reimbursement&.status == "voided"
      raise Refused.new("REIMBURSEMENT_VOIDED", :conflict, "來源代墊款已作廢，不可還原；要還原請先到請款記錄取消作廢")
    end

    prev_deleted_at = expense.deleted_at&.iso8601
    ActiveRecord::Base.transaction do
      expense.restore_from_trash!
      AuditLog.record!(expense, action: "restore", by: by,
        before: { deleted_at: prev_deleted_at },
        after:  { deleted_at: nil })
    end
    expense
  end

  # 來源代墊款還能作廢（審核中、駁回、已核准）時，永久刪除必須一起作廢。
  def void_required?(expense)
    Reimbursement::VOIDABLE_STATUSES.include?(expense.source_reimbursement&.status)
  end

  # 永久刪除：真的 DELETE。void_reimbursement 為 true 時連帶作廢來源代墊款，void_comment 必填。
  # 移轉目前對應的手續費支出（移轉在垃圾桶）不可單獨永久刪除；手續費改為 0 留下的可以。
  # audit log 必須在 destroy! 前寫入，否則 target.company 連動撈不到。
  # 來源代墊款保留，只解除它對本筆支出的關聯（expense_id 清空）。
  def purge!(expense, by:, void_reimbursement: false, void_comment: nil)
    if expense.current_fee_transfer
      raise Refused.new("TRANSFER_FEE_LOCKED", :conflict, "資金移轉還在垃圾桶，手續費支出不可單獨永久刪除，請到移轉處理")
    end
    if void_required?(expense) && !void_reimbursement
      raise Refused.new("VOID_REQUIRED", :unprocessable_content, "來源代墊款會同時作廢，請填寫作廢原因")
    end

    reimbursement = void_reimbursement ? voidable_reimbursement!(expense, void_comment) : nil

    ActiveRecord::Base.transaction do
      void_reimbursement!(reimbursement, by: by, comment: void_comment) if reimbursement
      AuditLog.record!(expense, action: "purge", by: by, before: expense.audit_snapshot)
      # 代墊款的 expense_id 外鍵指向本筆，須先解除，否則 destroy! 會被 FK 擋下
      expense.company.reimbursements.where(expense_id: expense.id)
        .update_all(expense_id: nil, updated_at: Time.current)
      expense.destroy!
    end
  end

  # 刪除（進垃圾桶）與永久刪除共用：檢查能否連帶作廢，回要作廢的代墊款。
  def voidable_reimbursement!(expense, comment)
    unless expense.source == "reimbursement"
      raise Refused.new("NOT_REIMBURSEMENT_SOURCED", :unprocessable_content, "這筆支出不是代墊款產生的")
    end
    raise Refused.new("COMMENT_REQUIRED", :unprocessable_content, "請填寫作廢原因") if comment.to_s.strip.blank?

    reimbursement = expense.company.reimbursements.find_by(id: expense.source_ref_id)
    raise Refused.new("REIMBURSEMENT_NOT_FOUND", :unprocessable_content, "找不到來源代墊款") if reimbursement.nil?
    unless Reimbursement::VOIDABLE_STATUSES.include?(reimbursement.status)
      raise Refused.new("INVALID_STATE", :conflict, "來源代墊款目前的狀態不可作廢")
    end

    reimbursement
  end

  # 把來源代墊款設為 voided 並寫 void 事件與 audit log；須在呼叫端的交易內。
  def void_reimbursement!(reimbursement, by:, comment:)
    comment     = comment.to_s.strip
    prev_status = reimbursement.status
    reimbursement.status = "voided"
    reimbursement.push_event!(type: "void", by: by.id, comment: comment)
    reimbursement.save!
    AuditLog.record!(reimbursement, action: "void", by: by,
      before: { status: prev_status },
      after:  { status: "voided", comment: comment })
  end
end
