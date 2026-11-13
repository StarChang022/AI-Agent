<script setup lang="ts">
/**
 * 新增／編輯資金移轉（PRD 規則 19、docs/dev/transfers-api.md §1）。
 * 移轉日期早於帳戶起始月份時不可儲存；收支的同類情況只是提示（CashFlowExcludedHint），這裡是擋下。
 */
import { computed, nextTick, reactive, ref, toRef, useId, watch } from 'vue'
import Button from 'primevue/button'
import DatePicker from '@/components/qds/DatePicker'
import Dialog from 'primevue/dialog'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import { useToast } from 'primevue/usetoast'
import AccountSelect from '@/components/admin/AccountSelect.vue'
import AttachmentField from '@/components/AttachmentField.vue'
import { HttpError } from '@/api/service'
import {
  createTransfer,
  deleteTransferAttachment,
  getTransfer,
  updateTransfer,
  type TransferRequest,
  type TransferSide,
} from '@/api/transfers'
import { useAccountOptions } from '@/composables/useAccountOptions'
import { newAttachmentIds, toFormAttachment, useAttachmentUploads } from '@/composables/useAttachmentUploads'
import type { Transfer } from '@/types/domain'
import type { FormAttachment } from '@/types/expense-form'
import { formatMonth, toIsoDate } from '@/utils/format'
import { userErrorToast } from '@/utils/userFeedback'

const props = defineProps<{ transfer?: Transfer | null }>()
const visible = defineModel<boolean>('visible', { required: true })
const emit = defineEmits<{
  saved: [transfer: Transfer]
  /** 編輯時刪除了已儲存的圖檔（立即生效，不必按儲存）；參數為刪除後的整筆移轉 */
  attachmentDeleted: [transfer: Transfer]
}>()

const toast = useToast()
const uid = useId()

const form = reactive({
  fromAccountId: null as string | null,
  toAccountId: null as string | null,
  amount: null as number | null,
  fee: 0 as number | null,
  transferDate: null as Date | null,
  note: '',
  attachments: [] as FormAttachment[],
})
const errors = reactive({ fromAccountId: '', toAccountId: '', amount: '', transferDate: '', fee: '' })
type ErrorField = keyof typeof errors

const submitting = ref(false)
// 憑證預覽開著時按 Esc 只關上層視窗，不連這個視窗一起關
const previewing = ref(false)

const isEdit = computed(() => !!props.transfer)

const uploads = useAttachmentUploads(toRef(form, 'attachments'), {
  deleteSaved: (attachmentId) => deleteTransferAttachment((props.transfer as Transfer).id, attachmentId),
  onSavedDeleted: (t) => emit('attachmentDeleted', t as Transfer),
  fetchSaved: () => getTransfer((props.transfer as Transfer).id).then((t) => t.attachments),
})
const { options: accountOptions, loading: accountsLoading, load: loadAccounts } = useAccountOptions()

/** 兩個帳戶都不符時一次列出，免得改好一個才看到另一個 */
const openingBlockedHint = computed(() => {
  if (!form.transferDate) return ''
  const date = toIsoDate(form.transferDate)
  const ids = [form.fromAccountId, form.toAccountId]
  const blocked = accountOptions.value.filter((a) => ids.includes(a.id) && a.openingMonth && date < a.openingMonth)
  if (!blocked.length) return ''
  const names = blocked.map((a) => `「${a.name}」（${formatMonth(a.openingMonth as string)}）`).join('、')
  return `移轉日期早於帳戶${names}的起始月份，不可儲存。要記錄這筆移轉，請先到帳戶設定把起始月份和起始金額往前調。`
})
const dateError = computed(() => errors.transferDate || openingBlockedHint.value)

const SAME_ACCOUNT_ERROR = '轉出與轉入帳戶不能相同'

watch(
  () => [form.fromAccountId, form.toAccountId],
  ([from, to], [prevFrom]) => {
    if (from !== prevFrom) errors.fromAccountId = ''
    errors.toAccountId = from && from === to ? SAME_ACCOUNT_ERROR : ''
    errors.transferDate = ''
  },
)

watch(
  visible,
  (v) => {
    // 關閉（含取消、Esc）：刪除這次上傳但未儲存的暫存檔
    if (!v) {
      uploads.discard()
      return
    }
    const t = props.transfer
    form.fromAccountId = t?.fromAccount.id ?? null
    form.toAccountId = t?.toAccount.id ?? null
    form.amount = t?.amount ?? null
    form.fee = t?.fee ?? 0
    form.transferDate = t ? new Date(`${t.transferDate}T00:00:00`) : new Date()
    form.note = t?.note ?? ''
    form.attachments = t ? t.attachments.map((a) => toFormAttachment(a, true)) : []
    ;(Object.keys(errors) as ErrorField[]).forEach((k) => (errors[k] = ''))
    void loadAccounts()
  },
  { immediate: true },
)

function validate(): boolean {
  errors.fromAccountId = form.fromAccountId ? '' : '請選擇轉出帳戶'
  if (!form.toAccountId) errors.toAccountId = '請選擇轉入帳戶'
  else errors.toAccountId = form.fromAccountId === form.toAccountId ? SAME_ACCOUNT_ERROR : ''
  errors.amount = form.amount && form.amount > 0 ? '' : '請填寫大於 0 的金額'
  errors.fee = (form.fee ?? 0) < 0 ? '手續費不可為負' : ''
  errors.transferDate = form.transferDate ? '' : '請選擇移轉日期'
  return !Object.values(errors).some(Boolean) && !openingBlockedHint.value
}

/** 依畫面順序；值是欄位 id 的後綴 */
function focusFirstError() {
  const inputs: [string, string][] = [
    [errors.fromAccountId, 'from'],
    [errors.toAccountId, 'to'],
    [errors.amount, 'amount'],
    [errors.fee, 'fee'],
    [dateError.value, 'date'],
  ]
  const first = inputs.find(([error]) => error)
  if (first) void nextTick(() => document.getElementById(`${uid}-${first[1]}`)?.focus())
}

async function onSubmit() {
  if (submitting.value) return
  if (!validate()) {
    focusFirstError()
    return
  }
  if (uploads.isUploading.value) {
    toast.add({ severity: 'warn', summary: '圖檔上傳中', detail: '請等上傳完成後再儲存。', life: 3000 })
    return
  }
  const attachmentIds = newAttachmentIds(form.attachments)
  const body: TransferRequest = {
    fromAccountId: form.fromAccountId as string,
    toAccountId: form.toAccountId as string,
    amount: form.amount as number,
    fee: form.fee ?? 0,
    transferDate: toIsoDate(form.transferDate as Date),
    note: form.note.trim() || null,
    attachmentIds,
  }
  const transfer = props.transfer
  submitting.value = true
  try {
    const saved = transfer ? await updateTransfer(transfer.id, body) : await createTransfer(body)
    uploads.markAttached(form.attachments)
    toast.add({
      severity: 'success',
      summary: transfer ? '已更新移轉' : '已新增移轉',
      detail: `${saved.fromAccount.name} → ${saved.toAccount.name}`,
      life: 2500,
    })
    emit('saved', saved)
    visible.value = false
  } catch (err) {
    if (await uploads.handleSaveError(err)) {
      toast.add({ severity: 'error', ...userErrorToast(err, isEdit.value ? '更新移轉失敗' : '新增移轉失敗'), life: 3500 })
      return
    }
    showSaveError(err)
  } finally {
    submitting.value = false
  }
}

const SIDE_FIELDS: Record<TransferSide, 'fromAccountId' | 'toAccountId'> = { from: 'fromAccountId', to: 'toAccountId' }
const ERROR_FIELDS: Record<string, ErrorField> = {
  TRANSFER_DATE_BEFORE_OPENING: 'transferDate',
  INVALID_TRANSFER_DATE: 'transferDate',
  INVALID_AMOUNT: 'amount',
  INVALID_FEE: 'fee',
}

function showSaveError(err: unknown) {
  const body = err instanceof HttpError ? (err.body as { error?: string; sides?: TransferSide[] }) : undefined
  const code = body?.error
  const failed = userErrorToast(err, isEdit.value ? '更新移轉失敗' : '新增移轉失敗')
  const field = code ? ERROR_FIELDS[code] : undefined
  if (field) {
    // 帳戶的起始月份可能在打開視窗後才改過，重新載入讓即時檢查跟上
    if (code === 'TRANSFER_DATE_BEFORE_OPENING') void loadAccounts()
    errors[field] = failed.detail
  } else if (body?.sides?.length) {
    if (code === 'ACCOUNT_NOT_FOUND') {
      body.sides.forEach((side) => (form[SIDE_FIELDS[side]] = null))
      void loadAccounts()
    }
    void nextTick(() => {
      body.sides?.forEach((side) => (errors[SIDE_FIELDS[side]] = failed.detail))
      focusFirstError()
    })
  } else {
    toast.add({ severity: 'error', ...failed, life: 3500 })
  }
}
</script>

<template>
  <Dialog
    v-model:visible="visible"
    modal
    :header="isEdit ? '編輯資金移轉' : '新增資金移轉'"
    :close-on-escape="!previewing && !uploads.confirming.value"
    :style="{ width: 'min(92vw, 640px)' }"
  >
    <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :id="`${uid}-from-label`" :for="`${uid}-from`">轉出帳戶 <span class="req">*</span></label>
          <AccountSelect
            v-model="form.fromAccountId"
            :input-id="`${uid}-from`"
            :labelled-by="`${uid}-from-label`"
            :options="accountOptions"
            :loading="accountsLoading"
            :invalid="!!errors.fromAccountId"
            :error-id="errors.fromAccountId ? `${uid}-from-err` : undefined"
            autofocus
          />
          <span v-if="errors.fromAccountId" :id="`${uid}-from-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.fromAccountId }}
          </span>
        </div>
        <div class="q-field">
          <label :id="`${uid}-to-label`" :for="`${uid}-to`">轉入帳戶 <span class="req">*</span></label>
          <AccountSelect
            v-model="form.toAccountId"
            :input-id="`${uid}-to`"
            :labelled-by="`${uid}-to-label`"
            :options="accountOptions"
            :loading="accountsLoading"
            :invalid="!!errors.toAccountId"
            :error-id="errors.toAccountId ? `${uid}-to-err` : undefined"
          />
          <span v-if="errors.toAccountId" :id="`${uid}-to-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.toAccountId }}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :for="`${uid}-amount`">金額 <span class="req">*</span></label>
          <InputNumber
            v-model="form.amount"
            :input-id="`${uid}-amount`"
            mode="currency"
            currency="TWD"
            locale="zh-TW"
            :min-fraction-digits="0"
            :max-fraction-digits="2"
            :min="0"
            :max="9999999999.99"
            placeholder="0"
            aria-required="true"
            :invalid="!!errors.amount"
            :aria-describedby="errors.amount ? `${uid}-amount-err` : undefined"
            fluid
            @update:model-value="errors.amount = ''"
          />
          <span v-if="errors.amount" :id="`${uid}-amount-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.amount }}
          </span>
        </div>
        <div class="q-field">
          <label :for="`${uid}-fee`">手續費</label>
          <InputNumber
            v-model="form.fee"
            :input-id="`${uid}-fee`"
            mode="currency"
            currency="TWD"
            locale="zh-TW"
            :min-fraction-digits="0"
            :max-fraction-digits="2"
            :min="0"
            :max="9999999999.99"
            placeholder="0"
            :invalid="!!errors.fee"
            :aria-describedby="`${uid}-fee-note${errors.fee ? ` ${uid}-fee-err` : ''}`"
            fluid
            @update:model-value="errors.fee = ''"
          />
          <span :id="`${uid}-fee-note`" class="dlg-note">大於 0 時，自動產生一筆已付款的手續費支出，帳戶為轉出帳戶。</span>
          <span v-if="errors.fee" :id="`${uid}-fee-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.fee }}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :for="`${uid}-date`">移轉日期 <span class="req">*</span></label>
          <DatePicker
            v-model="form.transferDate"
            :input-id="`${uid}-date`"
            date-format="yy/mm/dd"
            :manual-input="false"
            placeholder="請選擇移轉日期"
            show-icon
            icon-display="input"
            aria-required="true"
            :invalid="!!dateError"
            :aria-describedby="dateError ? `${uid}-date-err` : undefined"
            fluid
            @update:model-value="errors.transferDate = ''"
          />
        </div>
        <div class="q-field">
          <label :for="`${uid}-note`">備註</label>
          <InputText :id="`${uid}-note`" v-model="form.note" maxlength="200" placeholder="例如：提領零用金" />
        </div>
      </div>
      <div role="status">
        <span v-if="dateError" :id="`${uid}-date-err`" class="q-error tf-date-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" /><span>{{ dateError }}</span>
        </span>
      </div>

      <div class="q-field">
        <span class="q-label">憑證</span>
        <AttachmentField
          v-model:previewing="previewing"
          :attachments="form.attachments"
          :deleting-keys="uploads.deletingKeys.value"
          compact
          @add="uploads.addFiles"
          @remove="uploads.remove"
          @expired="uploads.onExpired"
        />
      </div>
      <button type="submit" class="hidden" />
    </form>
    <template #footer>
      <Button label="取消" outlined :disabled="submitting" @click="visible = false" />
      <Button label="儲存" :loading="submitting" @click="onSubmit" />
    </template>
  </Dialog>
</template>

<style scoped>
.tf-date-error { align-items: flex-start; }
.tf-date-error .pi { margin-top: 3px; }
</style>
