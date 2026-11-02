<script setup lang="ts">
import { ref, watch } from 'vue'
import type { ReimbursementSummary as ReimbursementRow } from '@/api/reimbursements'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import AccountSelect from '@/components/admin/AccountSelect.vue'
import ReimbursementSummary from '@/components/admin/ReimbursementSummary.vue'
import { useAccountOptions } from '@/composables/useAccountOptions'

/**
 * 代墊款核准彈窗：核准後 API 會自動建立對應支出，UI 收付款帳戶與核准意見。
 * vendor / 類別 / 付款狀態不再由使用者在此決定 — 由後端統一處理
 * （員工名（廠商名稱）、沿用類別、payoutStatus=pending）。
 */
interface Props {
  visible: boolean
  reimbursement: ReimbursementRow | null
  employeeName: string
  submitting?: boolean
  /** 通過時發現已被刪除的帳戶 */
  staleAccountIds?: string[]
}

const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirmed', payload: { comment: string | null; accountId: string }): void
}>()

const comment = ref('')
const accountId = ref<string | null>(null)
const accountError = ref('')
// 帳戶新增視窗開著時按 Esc 只關它，不連這個彈窗一起關
const creatingAccount = ref(false)
const { options, lastUsedAccountId, loading: accountsLoading, load, add } = useAccountOptions()

watch(
  () => props.visible,
  async (v) => {
    if (!v) return
    comment.value = ''
    accountId.value = null
    accountError.value = ''
    await load()
    if (props.visible && !accountId.value) accountId.value = lastUsedAccountId.value
  },
  { immediate: true },
)

watch(
  () => props.staleAccountIds,
  (ids) => {
    if (!accountId.value || !ids?.includes(accountId.value)) return
    accountId.value = null
    accountError.value = '這個帳戶已被刪除，請重新選擇'
    void load()
    document.getElementById('approve-account')?.focus()
  },
)

function onConfirm() {
  if (!accountId.value) {
    accountError.value = '請選擇帳戶'
    return
  }
  emit('confirmed', { comment: comment.value.trim() || null, accountId: accountId.value })
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
    :close-on-escape="!creatingAccount"
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
        <label id="approve-account-label" for="approve-account">付款帳戶 <span class="req">*</span></label>
        <AccountSelect
          v-model="accountId"
          v-model:creating="creatingAccount"
          input-id="approve-account"
          labelled-by="approve-account-label"
          :options="options"
          :loading="accountsLoading"
          :invalid="!!accountError"
          :error-id="accountError ? 'approve-account-err' : undefined"
          @update:model-value="accountError = ''"
          @created="add"
        />
        <span v-if="accountError" id="approve-account-err" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ accountError }}
        </span>
      </div>

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
