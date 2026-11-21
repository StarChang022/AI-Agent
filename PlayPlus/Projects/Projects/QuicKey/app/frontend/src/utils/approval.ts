import type {
  ApprovalProgress,
  ApprovalStep,
  Reimbursement,
  User,
} from '@/types/domain'
import type { ReimbursementSummary } from '@/api/reimbursements'

/**
 * 判斷指定使用者是否為該筆請款「當前這一 step」的候選簽核人。
 * 用來決定簽核頁的「待簽核」清單與 Dialog 內是否顯示核准/駁回按鈕。
 */
export function isCurrentReviewer(
  reimbursement: ReimbursementSummary,
  userId: string,
): boolean {
  if (
    reimbursement.status !== 'in_review' ||
    !reimbursement.approvalProgress
  ) {
    return false
  }
  const step =
    reimbursement.approvalProgress.steps[
      reimbursement.approvalProgress.currentStep - 1
    ]
  return !!step && step.candidates.includes(userId)
}

/**
 * 判斷使用者是否曾經在該筆請款的任一 step 中簽核（含歷史）。
 * 用來組「已處理」清單。
 */
export function hasReviewed(
  reimbursement: Reimbursement,
  userId: string,
): boolean {
  if (!reimbursement.approvalProgress) return false
  return reimbursement.approvalProgress.steps.some(
    (s) => s.reviewedBy?.id === userId,
  )
}

function makeStep(
  order: number,
  stageName: string,
  candidates: string[],
): ApprovalStep {
  return {
    order,
    stageName,
    candidates,
    status: 'pending',
    reviewedBy: null,
    comment: null,
    reviewedAt: null,
  }
}

/**
 * 建立簽核路徑：單層，由管理員簽核。
 * 現階段規格為 1 admin + N employee，員工提交的請款都由該 admin 審核。
 */
export function buildApprovalProgress(
  filer: User,
  users: User[],
): ApprovalProgress {
  const adminIds = users.filter((u) => u.role === 'admin').map((u) => u.id)
  const candidates =
    filer.role === 'admin'
      ? adminIds.filter((id) => id !== filer.id).length > 0
        ? adminIds.filter((id) => id !== filer.id)
        : [filer.id]
      : adminIds

  return {
    currentStep: 1,
    steps: [makeStep(1, '管理員簽核', candidates)],
  }
}
