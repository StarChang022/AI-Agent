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
import { useAuthStore } from '@/stores/auth'
import { isCurrentReviewer } from '@/utils/approval'

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
    payMode: null as PayMode | null,
    payTargets: [] as ReimbursementSummary[],
    payComment: '',
    payError: '',
    submitting: false,
  })

  const uid = () => auth.currentUser?.id ?? ''
  const isAdmin = () => auth.role === 'admin'
  const nameOf = (r: ReimbursementSummary | null) => r?.employee.name ?? ''
  const done = async (ids: string[]) => {
    await onDone?.(ids)
  }

  const can = {
    review: (r: ReimbursementSummary) => isCurrentReviewer(r, uid()),
    void: (r: ReimbursementSummary) =>
      isAdmin() && ['in_review', 'rejected', 'approved'].includes(r.status),
    revertVoid: (r: ReimbursementSummary) => isAdmin() && r.status === 'voided',
  }

  // 批次呼叫同一個 API；用 allSettled 讓單筆失敗不影響其他筆
  async function runBatch<T>(ids: string[], fn: (id: string) => Promise<T>) {
    const results = await Promise.allSettled(ids.map(fn))
    const ok = results.filter((r) => r.status === 'fulfilled').length
    return { ok, fail: ids.length - ok }
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
    state.approveTarget = r
  }
  function closeApprove() {
    state.approveTarget = null
  }
  async function onApproveConfirmed(payload: { comment: string | null }) {
    const t = state.approveTarget
    if (!t) return
    state.submitting = true
    try {
      let ok = false
      try {
        await approveReimbursement(t.id, { comment: payload.comment })
        ok = true
      } catch {
        ok = false
      }
      toast.add({
        severity: ok ? 'success' : 'warn',
        summary: ok ? `已通過「${t.description}」` : '操作失敗',
        life: 3000,
      })
      closeApprove()
      await done([t.id])
    } finally {
      state.submitting = false
    }
  }
  /** 批次核准（不帶 comment）。 */
  async function batchApprove(targets: ReimbursementSummary[]) {
    const ids = targets.map((t) => t.id)
    state.submitting = true
    try {
      const { ok, fail } = await runBatch(ids, (id) => approveReimbursement(id, {}))
      toast.add({
        severity: ok ? 'success' : 'warn',
        summary: `已通過 ${ok} 筆`,
        detail: fail ? `${fail} 筆無法處理` : undefined,
        life: 3000,
      })
      await done(ids)
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
      const { ok, fail } =
        mode === 'void'
          ? await runBatch(ids, (id) => apiVoidReimbursement(id, { comment }))
          : await runBatch(ids, (id) => revertVoidReimbursement(id))
      toast.add({
        severity: ok ? 'success' : 'warn',
        summary: `${PAY_MODE_META[mode].header}：完成 ${ok} 筆`,
        detail: fail ? `${fail} 筆無法處理` : undefined,
        life: 3500,
      })
      cancelPay()
      await done(ids)
    } finally {
      state.submitting = false
    }
  }

  return { state, can, nameOf, openReject, cancelReject, submitReject, openApprove, closeApprove, onApproveConfirmed, batchApprove, openPay, cancelPay, submitPay }
}

export type ReimbursementActions = ReturnType<typeof useReimbursementActions>
