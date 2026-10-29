<script setup lang="ts">
/**
 * 請款單簽核進度（管理端抽屜、員工端請款詳情共用）。
 * 送出請款 → 各簽核關卡 → 發放；實心圓圖示，完成的路段連線為綠色。
 * 有 history 時依時間列出每次送出／重送／簽核／駁回／發放（含操作人）；沒有時以 approvalProgress 推算。
 * history、paidAt、paidBy 皆為【原型】欄位，見 Notion 卡片 2。
 */
import { computed } from 'vue'
import type { Reimbursement } from '@/types/domain'
import { formatDate, formatDateTime } from '@/utils/format'

const props = defineProps<{ reimbursement: Reimbursement; labelledby?: string }>()

interface TlItem { cls: 'approved' | 'current' | 'rejected' | 'pending'; icon: string; title: string; status: string; meta?: string[]; comment?: string | null }

/** 尚未發生的關卡（目前與之後的簽核、發放） */
function upcoming(x: Reimbursement): TlItem[] {
  const list: TlItem[] = []
  if (x.status === 'in_review') {
    const p = x.approvalProgress
    const steps = p?.steps ?? []
    if (!steps.length) list.push({ cls: 'current', icon: 'pi-clock', title: '管理員簽核', status: '等待中' })
    steps.forEach((s, i) => {
      if (s.status !== 'pending') return
      const current = i + 1 === p!.currentStep
      list.push({ cls: current ? 'current' : 'pending', icon: current ? 'pi-clock' : 'pi-circle', title: s.stageName, status: current ? '等待中' : '尚未開始' })
    })
    list.push({ cls: 'pending', icon: 'pi-circle', title: '發放', status: '尚未開始' })
  } else if (x.status === 'approved') {
    list.push({ cls: 'current', icon: 'pi-clock', title: '發放', status: '等待發放' })
  }
  return list
}

/** 有 history：依時間列出每一次送出／重送／簽核／駁回／發放 */
function fromHistory(x: Reimbursement): TlItem[] {
  const list: TlItem[] = (x.history ?? []).map((e) => {
    const meta = [...(e.by ? [e.by.name] : []), e.type === 'pay' && e.at.length <= 10 ? formatDate(e.at) : formatDateTime(e.at)]
    switch (e.type) {
      case 'submit': return { cls: 'approved', icon: 'pi-check', title: '送出請款', status: '已送出', meta }
      case 'resubmit': return { cls: 'approved', icon: 'pi-replay', title: '重新送出', status: '已送出', meta }
      case 'withdraw': return { cls: 'pending', icon: 'pi-undo', title: '取消簽核', status: '退回草稿', meta }
      case 'approve': return { cls: 'approved', icon: 'pi-check', title: e.stage ?? '管理員簽核', status: '已通過', meta, comment: e.comment }
      case 'reject': return { cls: 'rejected', icon: 'pi-times', title: e.stage ?? '管理員簽核', status: '已退回', meta, comment: e.comment }
      case 'pay': return { cls: 'approved', icon: 'pi-check', title: '發放', status: '已發放', meta }
      case 'void': return { cls: 'rejected', icon: 'pi-ban', title: '作廢', status: '已作廢', meta }
      default: return { cls: 'approved', icon: 'pi-undo', title: '取消作廢', status: '回到已核銷', meta }
    }
  })
  if (x.status === 'draft') list.push({ cls: 'current', icon: 'pi-pencil', title: '重新送出', status: '草稿' })
  return [...list, ...upcoming(x)]
}

/** 沒有 history（舊資料）：以 approvalProgress 推算 */
function fromProgress(x: Reimbursement): TlItem[] {
  if (x.status === 'draft') {
    return [
      { cls: 'current', icon: 'pi-pencil', title: '送出請款', status: '草稿' },
      { cls: 'pending', icon: 'pi-circle', title: '管理員簽核', status: '尚未開始' },
      { cls: 'pending', icon: 'pi-circle', title: '發放', status: '尚未開始' },
    ]
  }
  const list: TlItem[] = [{ cls: 'approved', icon: 'pi-check', title: '送出請款', status: '已送出', meta: [x.employee.name, formatDateTime(x.createdAt)] }]
  for (const s of x.approvalProgress?.steps ?? []) {
    if (s.status === 'approved') list.push({ cls: 'approved', icon: 'pi-check', title: s.stageName, status: '已通過', meta: [s.reviewedBy?.name ?? '—', formatDateTime(s.reviewedAt)], comment: s.comment })
    else if (s.status === 'rejected') list.push({ cls: 'rejected', icon: 'pi-times', title: s.stageName, status: '已退回', meta: [s.reviewedBy?.name ?? '—', formatDateTime(s.reviewedAt)], comment: s.comment })
  }
  if (x.status === 'paid') list.push({ cls: 'approved', icon: 'pi-check', title: '發放', status: '已發放', meta: [...(x.paidBy ? [x.paidBy.name] : []), x.paidAt ? formatDate(x.paidAt) : formatDateTime(x.updatedAt)] })
  else if (x.status === 'voided') list.push({ cls: 'rejected', icon: 'pi-ban', title: '作廢', status: '已作廢', meta: [formatDateTime(x.updatedAt)] })
  return [...list, ...upcoming(x)]
}

const items = computed<TlItem[]>(() => {
  const x = props.reimbursement
  // 只有草稿且從未送出時 history 為空陣列 → 用推算版顯示完整流程
  return x.history?.length ? fromHistory(x) : fromProgress(x)
})
</script>

<template>
  <ol class="timeline" :aria-labelledby="labelledby">
    <li v-for="(t, i) in items" :key="i" class="tl-item" :class="t.cls" :aria-current="t.cls === 'current' ? 'step' : undefined">
      <span class="tl-icon"><i :class="['pi', t.icon]" aria-hidden="true" /></span>
      <div class="tl-content">
        <div class="tl-head"><span class="tl-title">{{ t.title }}</span><span class="tl-status">{{ t.status }}</span></div>
        <div v-if="t.meta?.length" class="tl-meta"><template v-for="(m, j) in t.meta" :key="j"><span v-if="j" class="sep" aria-hidden="true" />{{ m }}</template></div>
        <div v-if="t.comment" class="tl-comment">{{ t.comment }}</div>
      </div>
    </li>
  </ol>
</template>
