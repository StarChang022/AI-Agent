<script setup lang="ts">
import { ref, watch } from 'vue'
import type { ReimbursementSummary as ReimbursementRow } from '@/api/reimbursements'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import ReimbursementSummary from '@/components/admin/ReimbursementSummary.vue'

/**
 * 代墊款核准彈窗：核准後 API 會自動建立對應支出，UI 只收核准意見。
 * vendor / 類別 / 付款狀態不再由使用者在此決定 — 由後端統一處理
 * （員工名（廠商名稱）、沿用類別、payoutStatus=pending）。
 */
interface Props {
  visible: boolean
  reimbursement: ReimbursementRow | null
  employeeName: string
  submitting?: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirmed', payload: { comment: string | null }): void
}>()

const comment = ref('')

watch(
  () => props.visible,
  (v) => {
    if (v) comment.value = ''
  },
  { immediate: true },
)

function onConfirm() {
  emit('confirmed', { comment: comment.value.trim() || null })
}

function onCancel() {
  emit('close')
}
</script>

<template>
  <Dialog
    :visible="visible"
    modal
    :dismissable-mask="false"
    header="通過請款"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="onCancel"
  >
    <div v-if="reimbursement" class="flex flex-col gap-4">
      <ReimbursementSummary :targets="[reimbursement]" />

      <p class="text-sm text-[var(--color-muted)]">
        通過後會自動建立一筆支出，付款狀態預設為「未付款」。
      </p>

      <div class="q-field">
        <label for="approve-comment">備註（選填）</label>
        <Textarea id="approve-comment" auto-resize v-model="comment" rows="2" placeholder="例如：金額與發票相符" class="w-full" />
      </div>
    </div>

    <template #footer>
      <Button label="取消" outlined :disabled="submitting" @click="onCancel" />
      <Button label="通過" :loading="submitting" @click="onConfirm" />
    </template>
  </Dialog>
</template>
