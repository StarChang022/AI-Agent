<script setup lang="ts">
/** 資金移轉明細（抽屜內容）：移轉內容、憑證、手續費支出、歷程。 */
import { ref } from 'vue'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import LinkedRecordRow from '@/components/LinkedRecordRow.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'
import type { ExpenseAttachment, Transfer } from '@/types/domain'
import { formatCurrencyExact, formatDate } from '@/utils/format'

defineProps<{ transfer: Transfer }>()

const previewAtt = ref<ExpenseAttachment | null>(null)
</script>

<template>
  <div class="dt-body">
    <section class="dt-summary" aria-label="移轉摘要">
      <div class="dt-summary-heading">{{ transfer.fromAccount.name }} → {{ transfer.toAccount.name }}</div>
      <p v-if="transfer.note" class="dt-summary-desc">{{ transfer.note }}</p>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">金額</span>
          <span class="dt-stat-value">{{ formatCurrencyExact(transfer.amount) }}</span>
        </div>
        <div class="dt-stat">
          <span class="dt-stat-label">移轉日期</span>
          <span class="dt-stat-value">{{ formatDate(transfer.transferDate) }}</span>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="tf-basic">
      <h3 id="tf-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>轉出帳戶</dt><dd>{{ transfer.fromAccount.name }}</dd></div>
        <div class="dt-row"><dt>轉入帳戶</dt><dd>{{ transfer.toAccount.name }}</dd></div>
        <div class="dt-row"><dt>手續費</dt><dd>{{ formatCurrencyExact(transfer.fee) }}</dd></div>
        <div class="dt-row"><dt>建立者</dt><dd>{{ transfer.createdBy.name }}</dd></div>
      </dl>
      <!-- 垃圾桶內的手續費支出開不了詳情，移轉還原後才連得過去 -->
      <LinkedRecordRow
        v-if="transfer.feeExpenseId && !transfer.deletedAt"
        :to="{ name: 'admin-expenses', query: { open: transfer.feeExpenseId } }"
        label="手續費支出"
        action="前往支出"
      >
        {{ formatCurrencyExact(transfer.fee) }}
      </LinkedRecordRow>
    </section>

    <section class="dt-section" aria-labelledby="tf-doc">
      <h3 id="tf-doc" class="dt-section-title">憑證</h3>
      <div v-if="transfer.attachments.length" class="dt-thumbs">
        <button
          v-for="(att, i) in transfer.attachments"
          :key="i"
          type="button"
          class="aspect-square rounded-md border border-[var(--color-hairline)] overflow-hidden bg-[var(--color-surface)] flex items-center justify-center hover:border-[var(--color-primary-700)] transition-colors"
          :aria-label="`預覽 ${att.filename}`"
          @click="previewAtt = att"
        >
          <img v-if="att.mimeType.startsWith('image/')" :src="att.dataUrl" :alt="att.filename" class="w-full h-full object-cover" />
          <span v-else class="w-full h-full flex flex-col items-center justify-center gap-1 p-1.5"><i class="pi pi-file-pdf text-2xl text-[var(--color-danger)]" aria-hidden="true" /><span class="w-full truncate text-center text-xs text-[var(--color-muted)]">{{ att.filename }}</span></span>
        </button>
      </div>
      <p v-else class="dt-empty"><i class="pi pi-paperclip mr-1" aria-hidden="true" />尚未上傳憑證檔案</p>
    </section>

    <AuditLogList target-type="transfer" :target-id="transfer.id" />

    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="previewAtt = null"
    />
  </div>
</template>
