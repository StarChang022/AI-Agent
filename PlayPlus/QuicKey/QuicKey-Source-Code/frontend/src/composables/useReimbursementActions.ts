/**
 * 請款單的後台動作（核准/駁回/作廢/取消作廢），請款記錄與簽核兩頁共用；
 * 對話框在 components/admin/ReimbursementDialogs.vue。
 * 核准時後端 approve endpoint 會自動建立對應支出（payoutStatus=pending）；
 * 之後的「發放」動作在支出管理頁完成，Reimbursement.status 由 Expense 付款時反向同步。
 */
import { reactive } from 'vue'
import { useToast } from 'primevue/usetoast'
import {
  approveReimbursement,
  rejectReimbursement,
  revertVoidReimbursement,
  voidReimbursement as apiVoidReimbursement,
  type ReimbursementSummary,
} from '@/api/reimbursements'
import { isAccountUnavailable } from '@/api/accounts'
import { useAuthStore } from '@/stores/auth'
import { isCurrentReviewer } from '@/utils/approval'
import { userErrorToast } from '@/utils/userFeedback'
import { useReviewCount } from '@/composables/useReviewCount'

export type PayMode = 'void' | 'revert-void'

export const PAY_MODE_META: Record<PayMode, { header: string; confirm: string; severity?: 'danger' }> = {
  void: { header: '作廢請款', confirm: '確認作廢', severity: 'danger' },
  'revert-void': { header: '取消作廢', confirm: '取消作廢' },
}

export function useReimbursementActions(onDone?: (ids: string[]) => void | Promise<void>) {
  const auth = useAuthStore()
  const toast = useToast()

  const state = reactive({
    rejectTargets: [] as ReimbursementSummary[],
    rejectComment: '',
    rejectError: '',
    approveTarget: null as ReimbursementSummary | null,
    batchApproveTargets: [] as ReimbursementSummary[],
    /** 通過時發現已被刪除的帳戶；核准彈窗據此清掉失效的選擇並重撈清單 */
    staleAccountIds: [] as string[],
    payMode: null as PayMode | null,
    payTargets: [] as ReimbursementSummary[],
    payComment: '',
    payError: '',
    submitting: false,
  })

  const uid = () => auth.currentUser?.id ?? ''
  const isAdmin = () => auth.role === 'admin'
  const nameOf = (r: ReimbursementSummary | null) => r?.employee.name ?? ''
  const { refresh: refreshReviewCount } = useReviewCount()
  // 核准/駁回/作廢/取消作廢都可能改變待簽核筆數，順便更新側邊欄 badge
  const done = async (ids: string[]) => {
    void refreshReviewCount()
    await onDone?.(ids)
  }

  const can = {
    review: (r: ReimbursementSummary) => isCurrentReviewer(r, uid()),
    void: (r: ReimbursementSummary) =>
      isAdmin() && ['in_review', 'rejected', 'approved'].includes(r.status),
    revertVoid: (r: ReimbursementSummary) => isAdmin() && r.status === 'voided',
  }

  // 批次呼叫同一個 API；用 allSettled 讓單筆失敗不影響其他筆。firstError 給全部失敗時顯示原因
  async function runBatch<T>(ids: string[], fn: (id: string) => Promise<T>) {
    const results = await Promise.allSettled(ids.map(fn))
    const failures = results.flatMap((r, i) => (r.status === 'rejected' ? [{ id: ids[i], reason: r.reason as unknown }] : []))
    return { ok: ids.length - failures.length, fail: failures.length, firstError: failures[0]?.reason, failures }
  }

  // ─── 駁回 ───
  function openReject(targets: ReimbursementSummary[]) {
    if (!targets.length) return
    state.rejectTargets = targets
    state.rejectComment = ''
    state.rejectError = ''
  }
  function cancelReject() {
    state.rejectTargets = []
  }
  async function submitReject() {
    const comment = state.rejectComment.trim()
    if (!comment) {
      state.rejectError = '請填寫退回原因'
      return
    }
    const ids = state.rejectTargets.map((t) => t.id)
    state.submitting = true
    try {
      const { ok, fail } = await runBatch(ids, (id) => rejectReimbursement(id, { comment }))
      toast.add({
        severity: ok ? 'success' : 'warn',
        summary: `已退回 ${ok} 筆`,
        detail: fail ? `${fail} 筆無法處理` : '退回原因會通知申請人',
        life: 3000,
      })
      cancelReject()
      await done(ids)
    } finally {
      state.submitting = false
    }
  }

  // ─── 核准（後端 approve endpoint 連動建立對應支出）───
  function openApprove(r: ReimbursementSummary) {
    state.staleAccountIds = []
    state.approveTarget = r
  }
  function closeApprove() {
    state.approveTarget = null
  }
  async function onApproveConfirmed(payload: { comment: string | null; accountId: string }) {
    const t = state.approveTarget
    if (!t) return
    state.submitting = true
    try {
      try {
        await approveReimbursement(t.id, payload)
        toast.add({ severity: 'success', summary: `已通過「${t.description}」`, life: 3000 })
      } catch (err) {
        // 帳戶在視窗開著時被刪：留在視窗重選，意見不用重打
        if (isAccountUnavailable(err)) {
          state.staleAccountIds = [payload.accountId]
          return
        }
        toast.add({ severity: 'warn', ...userErrorToast(err, '操作失敗'), life: 3000 })
      }
      closeApprove()
      await done([t.id])
    } finally {
      state.submitting = false
    }
  }
  function openBatchApprove(targets: ReimbursementSummary[]) {
    state.staleAccountIds = []
    state.batchApproveTargets = targets
  }
  function closeBatchApprove() {
    state.batchApproveTargets = []
  }
  /** 批次核准（不帶 comment）；accountIds 為請款單 id → 帳戶 id，每筆可不同。 */
  async function onBatchApproveConfirmed(accountIds: Record<string, string>) {
    const ids = state.batchApproveTargets.map((t) => t.id)
    state.submitting = true
    try {
      const { ok, fail, firstError, failures } = await runBatch(ids, (id) =>
        approveReimbursement(id, { accountId: accountIds[id] }),
      )
      // 帳戶失效的筆數留在視窗重選；其他失敗照舊提示筆數
      const staleIds = failures.filter((f) => isAccountUnavailable(f.reason)).map((f) => f.id)
      if (staleIds.length) {
        toast.add({
          severity: 'warn',
          summary: ok ? `已通過 ${ok} 筆` : '批次通過失敗',
          detail: `${staleIds.length} 筆的帳戶已被刪除，請重新選擇${fail > staleIds.length ? `；另有 ${fail - staleIds.length} 筆無法處理` : ''}`,
          life: 3500,
        })
        state.staleAccountIds = [...new Set(staleIds.map((id) => accountIds[id]))]
        state.batchApproveTargets = state.batchApproveTargets.filter((t) => staleIds.includes(t.id))
      } else {
        toast.add(
          ok
            ? {
                severity: 'success',
                summary: `已通過 ${ok} 筆`,
                detail: fail ? `${fail} 筆無法處理` : undefined,
                life: 3000,
              }
            : { severity: 'warn', ...userErrorToast(firstError, '批次通過失敗'), life: 3000 },
        )
        closeBatchApprove()
      }
      await done(ids.filter((id) => !staleIds.includes(id)))
    } finally {
      state.submitting = false
    }
  }

  // ─── 作廢/取消作廢 ───
  function openPay(mode: PayMode, targets: ReimbursementSummary[]) {
    if (!targets.length) return
    state.payMode = mode
    state.payTargets = targets
    state.payComment = ''
    state.payError = ''
  }
  function cancelPay() {
    state.payMode = null
    state.payTargets = []
  }
  async function submitPay() {
    const mode = state.payMode
    if (!mode) return
    // 作廢原因必填（前端擋 + 後端 COMMENT_REQUIRED 擋）
    if (mode === 'void' && !state.payComment.trim()) {
      state.payError = '請填寫作廢原因'
      return
    }
    const ids = state.payTargets.map((t) => t.id)
    state.submitting = true
    try {
      const comment = state.payComment.trim()
      const { ok, fail, firstError } =
        mode === 'void'
          ? await runBatch(ids, (id) => apiVoidReimbursement(id, { comment }))
          : await runBatch(ids, (id) => revertVoidReimbursement(id))
      // 全部失敗時顯示後端原因（例如對應支出已永久刪除、無法取消作廢）
      toast.add(
        ok
          ? {
              severity: 'success',
              summary: `${PAY_MODE_META[mode].header}：完成 ${ok} 筆`,
              detail: fail ? `${fail} 筆無法處理` : undefined,
              life: 3500,
            }
          : { severity: 'warn', ...userErrorToast(firstError, `${PAY_MODE_META[mode].header}失敗`), life: 5000 },
      )
      cancelPay()
      await done(ids)
    } finally {
      state.submitting = false
    }
  }

  return { state, can, nameOf, openReject, cancelReject, submitReject, openApprove, closeApprove, onApproveConfirmed, openBatchApprove, closeBatchApprove, onBatchApproveConfirmed, openPay, cancelPay, submitPay }
}

export type ReimbursementActions = ReturnType<typeof useReimbursementActions>
