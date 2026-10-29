<script setup lang="ts">
/**
 * 後台請款單明細（放在右側 Drawer）。
 * 內容：摘要（類別、說明、金額、下一步）→ 基本資訊 → 憑證 → 簽核進度 Timeline（送出請款 → 管理員簽核 → 發放）
 * → 對應支出（只列付款狀態＋前往支出；建立時間已在 Timeline「送出請款」呈現，不另列）。沒有資料的欄位（例如收據的發票號碼）不顯示。
 * 對應 design-system 後台原型「請款單明細」與 design-timeline.html。
 */
import { computed, ref } from 'vue'
import type { Reimbursement } from '@/types/domain'
import { formatCurrency, formatDate } from '@/utils/format'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import ReimbursementTimeline from '@/components/ReimbursementTimeline.vue'
import ReimbursementInvoiceRows from '@/components/ReimbursementInvoiceRows.vue'
import LinkedRecordRow from '@/components/LinkedRecordRow.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'
import { useReimbursementPayout } from '@/composables/useReimbursementPayout'

const props = defineProps<{ reimbursement: Reimbursement }>()

const previewIdx = ref<number | null>(null)
const receiptName = (i: number) => r.value.receiptNames?.[i] ?? `附件 ${i + 1}`

const r = computed(() => props.reimbursement)
const { payoutInfo } = useReimbursementPayout()
const linkedExpense = computed(() => r.value.linkedExpense)
const isImage = (url: string) => url.startsWith('data:image/')

/** 摘要第二格：依狀態顯示「下一步」或完成日期 */
const nextStep = computed<{ label: string; value: string }>(() => {
  const x = r.value
  switch (x.status) {
    case 'draft':
      return { label: '下一步', value: '等待申請人送出' }
    case 'in_review':
      return { label: '下一步', value: '等待簽核' }
    case 'rejected':
      return { label: '下一步', value: '等待申請人重送' }
    case 'approved': {
      const p = payoutInfo(x)
      return p ? { label: '預計發放日', value: p.date } : { label: '下一步', value: '等待發放' }
    }
    case 'paid':
      return { label: '發放日', value: payoutInfo(x)?.date ?? formatDate(x.updatedAt) }
    default:
      return { label: '作廢日', value: formatDate(x.updatedAt) }
  }
})

</script>

<template>
  <div class="dt-body">
    <!-- 摘要：類別、說明；金額與下一步並排（同支出詳情） -->
    <section class="dt-summary" aria-label="請款摘要">
      <div class="dt-summary-heading">{{ r.category.name }}</div>
      <p v-if="r.description" class="dt-summary-desc">{{ r.description }}</p>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">金額</span>
          <span class="dt-stat-value">{{ formatCurrency(r.amount) }}</span>
        </div>
        <div class="dt-stat">
          <span class="dt-stat-label">{{ nextStep.label }}</span>
          <span class="dt-stat-value">{{ nextStep.value }}</span>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="rb-basic">
      <h3 id="rb-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>申請人</dt><dd>{{ r.employee.name }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ r.category.name }}</dd></div>
        <div class="dt-row"><dt>費用日期</dt><dd>{{ formatDate(r.incurredAt) }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="rb-doc">
      <h3 id="rb-doc" class="dt-section-title">憑證</h3>
      <dl class="dt-list">
        <ReimbursementInvoiceRows :reimbursement="r" />
      </dl>
      <div v-if="r.receiptUrls.length" class="dt-thumbs">
        <button
          v-for="(url, i) in r.receiptUrls"
          :key="i"
          type="button"
          class="aspect-square rounded-md border border-[var(--color-hairline)] overflow-hidden bg-[var(--color-surface)] flex items-center justify-center hover:border-[var(--color-primary-700)] transition-colors"
          :aria-label="`預覽${r.receiptNames?.[i] ?? `附件 ${i + 1}`}`"
          @click="previewIdx = i"
        >
          <img v-if="isImage(url)" :src="url" alt="" class="w-full h-full object-cover" />
          <span v-else class="w-full h-full flex flex-col items-center justify-center gap-1 p-1.5"><i class="pi pi-file-pdf text-2xl text-[var(--color-danger)]" aria-hidden="true" /><span class="w-full truncate text-center text-[10px] text-[var(--color-muted)]">{{ receiptName(i) }}</span></span>
        </button>
      </div>
      <p v-else class="dt-empty"><i class="pi pi-paperclip mr-1" aria-hidden="true" />申請人未上傳憑證檔案</p>
    </section>

    <section class="dt-section" aria-labelledby="rb-flow">
      <h3 id="rb-flow" class="dt-section-title">簽核進度</h3>
      <ReimbursementTimeline :reimbursement="r" labelledby="rb-flow" />
    </section>

    <!-- 對應支出：資料與上方相同，只顯示付款狀態與前往支出的連結（簽核通過會自動建立支出） -->
    <section v-if="linkedExpense" class="dt-section" aria-labelledby="rb-exp">
      <h3 id="rb-exp" class="dt-section-title">對應支出</h3>
      <LinkedRecordRow
        :to="{ name: 'admin-expenses', query: { open: linkedExpense.id } }"
        label="付款狀態"
        action="前往支出"
      >
        <span class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]" :class="linkedExpense.payoutStatus === 'paid' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'">{{ linkedExpense.payoutStatus === 'paid' ? '已付款' : '待付款' }}</span>
      </LinkedRecordRow>
    </section>

    <AuditLogList target-type="reimbursement" :target-id="r.id" />

    <AttachmentPreviewDialog
      :src="previewIdx === null ? null : r.receiptUrls[previewIdx] ?? null"
      :filename="previewIdx === null ? undefined : receiptName(previewIdx)"
      @close="previewIdx = null"
    />
  </div>
</template>
