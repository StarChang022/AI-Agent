<script setup lang="ts">
/**
 * 批次通過代墊款：每筆可個別選付款帳戶（PRD 規則 20），預設帶上一次使用的帳戶。
 * 通過後 API 會逐筆建立對應支出，規則同 ApproveWithExpenseDialog。
 */
import { ref, watch } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import AccountSelect from '@/components/admin/AccountSelect.vue'
import ReimbursementSummary from '@/components/admin/ReimbursementSummary.vue'
import type { ReimbursementSummary as ReimbursementRow } from '@/api/reimbursements'
import { useAccountOptions } from '@/composables/useAccountOptions'
import { formatCurrency } from '@/utils/format'

const props = defineProps<{
  targets: ReimbursementRow[]
  submitting?: boolean
  /** 通過時發現已被刪除的帳戶 */
  staleAccountIds?: string[]
}>()
const emit = defineEmits<{
  close: []
  /** 請款單 id → 帳戶 id */
  confirmed: [accountIds: Record<string, string>]
}>()

const accountIds = ref<Record<string, string | null>>({})
const errors = ref<Record<string, string>>({})
// 帳戶新增視窗開著時按 Esc 只關它，不連這個彈窗一起關
const creatingFor = ref<string | null>(null)
const { options, lastUsedAccountId, loading, load, add } = useAccountOptions()

watch(
  () => props.targets,
  async (targets, prev) => {
    // 部分通過後留下的筆數要保留已選的帳戶，只有打開視窗時才重置
    if (!targets.length || prev?.length) return
    accountIds.value = Object.fromEntries(targets.map((t) => [t.id, null]))
    errors.value = {}
    await load()
    for (const t of props.targets) accountIds.value[t.id] ??= lastUsedAccountId.value
  },
  { immediate: true },
)

const inputId = (id: string) => `batch-account-${id}`

watch(
  () => props.staleAccountIds,
  (ids) => {
    const stale = props.targets.filter((t) => ids?.includes(accountIds.value[t.id] ?? ''))
    if (!stale.length) return
    for (const t of stale) {
      accountIds.value[t.id] = null
      errors.value[t.id] = '這個帳戶已被刪除，請重新選擇'
    }
    void load()
    document.getElementById(inputId(stale[0].id))?.focus()
  },
)

function onAccountChange(id: string) {
  errors.value[id] = ''
}

function onConfirm() {
  const missing = props.targets.filter((t) => !accountIds.value[t.id])
  if (missing.length) {
    errors.value = Object.fromEntries(missing.map((t) => [t.id, '請選擇帳戶']))
    document.getElementById(inputId(missing[0].id))?.focus()
    return
  }
  emit('confirmed', accountIds.value as Record<string, string>)
}
</script>

<template>
  <Dialog
    :visible="targets.length > 0"
    modal
    :dismissable-mask="false"
    :close-on-escape="!creatingFor"
    :header="`批次通過 ${targets.length} 筆`"
    :style="{ width: 'min(92vw, 560px)' }"
    @update:visible="emit('close')"
  >
    <div class="flex flex-col gap-4">
      <ReimbursementSummary :targets="targets" />
      <p class="dlg-note">通過後每筆會自動建立一筆支出，付款狀態預設為「未付款」。</p>
      <ul class="ba-list">
        <li v-for="t in targets" :key="t.id" class="ba-row">
          <div :id="`batch-row-${t.id}`" class="ba-info">
            <b>{{ t.employee.name }}</b>
            <span class="cell-sub" :title="t.description">{{ t.description }}</span>
            <span class="ba-amount">{{ formatCurrency(t.amount) }}</span>
          </div>
          <div class="q-field ba-account">
            <label :id="`batch-label-${t.id}`" :for="inputId(t.id)">付款帳戶 <span class="req">*</span></label>
            <AccountSelect
              v-model="accountIds[t.id]"
              :creating="creatingFor === t.id"
              :input-id="inputId(t.id)"
              :labelled-by="`batch-label-${t.id} batch-row-${t.id}`"
              :options="options"
              :loading="loading"
              :invalid="!!errors[t.id]"
              :error-id="errors[t.id] ? `batch-err-${t.id}` : undefined"
              @update:creating="creatingFor = $event ? t.id : null"
              @update:model-value="onAccountChange(t.id)"
              @created="add"
            />
            <span v-if="errors[t.id]" :id="`batch-err-${t.id}`" class="q-error">
              <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors[t.id] }}
            </span>
          </div>
        </li>
      </ul>
    </div>

    <template #footer>
      <Button label="取消" outlined :disabled="submitting" @click="emit('close')" />
      <Button :label="`通過 ${targets.length} 筆`" :loading="submitting" @click="onConfirm" />
    </template>
  </Dialog>
</template>

<style scoped>
.ba-list { display: flex; flex-direction: column; list-style: none; margin: 0; padding: 0; }
.ba-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 220px;
  align-items: start;
  gap: 16px;
  padding: 12px 0;
  border-top: 1px solid var(--color-hairline);
}
.ba-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; font-size: 14px; }
.ba-amount { font-variant-numeric: tabular-nums; }
.ba-account { min-width: 0; }

@media (max-width: 639.98px) {
  .ba-row { grid-template-columns: minmax(0, 1fr); gap: 8px; }
}
</style>
