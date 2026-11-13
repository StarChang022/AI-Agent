<script setup lang="ts">
/**
 * 新增／編輯帳戶視窗，帳戶設定頁與收支表單的帳戶下拉共用。
 * 帶 account 為編輯：修改起始金額、起始月份要二次確認（PRD 規則 20）。
 */
import { computed, reactive, ref, useId, watch } from 'vue'
import Button from 'primevue/button'
import DatePicker from '@/components/qds/DatePicker'
import Dialog from 'primevue/dialog'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import {
  createAccount,
  getOpeningMonthImpact,
  updateAccount,
  type UpdateAccountRequest,
} from '@/api/accounts'
import { HttpError } from '@/api/service'
import type { Account } from '@/types/domain'
import { formatCurrencyExact, formatDate, formatMonth, toIsoMonth } from '@/utils/format'
import { userErrorToast } from '@/utils/userFeedback'

const props = defineProps<{ account?: Account | null }>()
const visible = defineModel<boolean>('visible', { required: true })
const emit = defineEmits<{ saved: [account: Account] }>()

const confirm = useConfirm()
const toast = useToast()
const uid = useId()

/** 起始月份只能選 2000 年 1 月至當月 */
const MIN_OPENING_MONTH = new Date(2000, 0, 1)
const maxOpeningMonth = new Date()

const form = reactive({
  name: '',
  openingAmount: null as number | null,
  openingMonth: null as Date | null,
})
const errors = reactive({ name: '', openingAmount: '', openingMonth: '' })
const submitting = ref(false)
// 二次確認開著時按 Esc 只關確認視窗，不連這個視窗一起關
const confirming = ref(false)

const isEdit = computed(() => !!props.account)

watch(
  visible,
  (v) => {
    if (!v) return
    form.name = props.account?.name ?? ''
    form.openingAmount = props.account?.openingAmount ?? null
    form.openingMonth = props.account ? new Date(`${props.account.openingMonth}T00:00:00`) : new Date()
    errors.name = errors.openingAmount = errors.openingMonth = ''
  },
  { immediate: true },
)

function validate(): boolean {
  errors.name = form.name.trim() ? '' : '請填寫帳戶名稱'
  errors.openingAmount = form.openingAmount === null ? '請填寫起始金額' : ''
  errors.openingMonth = form.openingMonth ? '' : '請選擇起始月份'
  return !errors.name && !errors.openingAmount && !errors.openingMonth
}

/**
 * 起始月份往後調時，改完後有幾筆收付款不計入現金流。
 * 有移轉會早於新月份時不可調整（PRD 規則 19），回 null 並顯示在欄位下方；
 * 查不到時也擋下，不在沒有提示的情況下改。
 */
async function fetchImpactNote(account: Account, nextMonth: string): Promise<string | null> {
  if (nextMonth <= account.openingMonth.slice(0, 7)) return ''
  try {
    const impact = await getOpeningMonthImpact(account.id, nextMonth)
    if (impact.blockingTransferCount > 0) {
      errors.openingMonth = `有 ${impact.blockingTransferCount} 筆資金移轉的日期早於這個起始月份，最早為 ${formatDate(impact.earliestTransferDate)}，請先修改移轉日期或刪除移轉。`
      return null
    }
    return impact.outsideCashFlowCount > 0
      ? `改完後有 ${impact.outsideCashFlowCount} 筆收付款早於起始月份，不計入現金流。`
      : ''
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '無法確認受影響的筆數'), life: 3500 })
    return null
  }
}

async function onSubmit() {
  if (submitting.value || !validate()) return
  const account = props.account
  const nextAmount = form.openingAmount as number
  const nextMonth = toIsoMonth(form.openingMonth as Date)
  const amountChanged = !!account && nextAmount !== account.openingAmount
  const monthChanged = !!account && nextMonth !== account.openingMonth.slice(0, 7)
  if (!account || (!amountChanged && !monthChanged)) {
    void save()
    return
  }
  submitting.value = true
  const impactNote = monthChanged ? await fetchImpactNote(account, nextMonth) : ''
  submitting.value = false
  if (impactNote === null) return
  const changes = [
    amountChanged ? `起始金額將由 ${formatCurrencyExact(account.openingAmount)} 改為 ${formatCurrencyExact(nextAmount)}。` : '',
    monthChanged ? `起始月份將由 ${formatMonth(account.openingMonth)} 改為 ${formatMonth(nextMonth)}。` : '',
    impactNote,
  ].join('')
  confirming.value = true
  confirm.require({
    header: amountChanged && monthChanged ? '修改起始金額與月份' : amountChanged ? '修改起始金額' : '修改起始月份',
    message: `${changes}這個帳戶的餘額與各月期初會一併變動。確定要修改嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '確認修改',
    rejectLabel: '取消',
    accept: () => {
      confirming.value = false
      void save()
    },
    reject: () => (confirming.value = false),
    onHide: () => (confirming.value = false),
  })
}

async function save() {
  const name = form.name.trim()
  const openingAmount = form.openingAmount as number
  const openingMonth = toIsoMonth(form.openingMonth as Date)
  const account = props.account
  submitting.value = true
  try {
    if (account) {
      const body: UpdateAccountRequest = {}
      if (name !== account.name) body.name = name
      if (openingAmount !== account.openingAmount) body.openingAmount = openingAmount
      if (openingMonth !== account.openingMonth.slice(0, 7)) body.openingMonth = openingMonth
      if (Object.keys(body).length) {
        const updated = await updateAccount(account.id, body)
        toast.add({ severity: 'success', summary: '已更新帳戶', detail: updated.name, life: 2500 })
        emit('saved', updated)
      }
    } else {
      const created = await createAccount({ name, openingAmount, openingMonth })
      toast.add({ severity: 'success', summary: '已新增帳戶', detail: created.name, life: 2500 })
      emit('saved', created)
    }
    visible.value = false
  } catch (err) {
    showSaveError(err)
  } finally {
    submitting.value = false
  }
}

function showSaveError(err: unknown) {
  const code = err instanceof HttpError ? (err.body as { error?: string })?.error : undefined
  const failed = userErrorToast(err, isEdit.value ? '更新帳戶失敗' : '新增帳戶失敗')
  if (code === 'DUPLICATE_NAME' || code === 'INVALID_NAME') errors.name = failed.detail
  else if (code === 'INVALID_OPENING_AMOUNT') errors.openingAmount = failed.detail
  else if (code === 'INVALID_OPENING_MONTH' || code === 'OPENING_MONTH_AFTER_TRANSFER') errors.openingMonth = failed.detail
  else toast.add({ severity: 'error', ...failed, life: 3500 })
}
</script>

<template>
  <Dialog
    v-model:visible="visible"
    modal
    :header="isEdit ? '編輯帳戶' : '新增帳戶'"
    :close-on-escape="!confirming"
    :style="{ width: 'min(92vw, 440px)' }"
  >
    <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
      <div class="q-field">
        <label :for="`${uid}-name`">帳戶名稱 <span class="req">*</span></label>
        <InputText
          :id="`${uid}-name`"
          v-model="form.name"
          placeholder="例如：永豐-總公司、零用金"
          maxlength="50"
          autofocus
          aria-required="true"
          :invalid="!!errors.name"
          :aria-describedby="errors.name ? `${uid}-name-err` : undefined"
          @input="errors.name = ''"
        />
        <span v-if="errors.name" :id="`${uid}-name-err`" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.name }}
        </span>
      </div>
      <div class="q-field">
        <label :for="`${uid}-amount`">起始金額 <span class="req">*</span></label>
        <InputNumber
          v-model="form.openingAmount"
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
          :invalid="!!errors.openingAmount"
          :aria-describedby="errors.openingAmount ? `${uid}-amount-err` : undefined"
          fluid
          @update:model-value="errors.openingAmount = ''"
        />
        <span v-if="errors.openingAmount" :id="`${uid}-amount-err`" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.openingAmount }}
        </span>
      </div>
      <div class="q-field">
        <label :for="`${uid}-month`">起始月份 <span class="req">*</span></label>
        <DatePicker
          v-model="form.openingMonth"
          :input-id="`${uid}-month`"
          view="month"
          date-format="yy/mm"
          :min-date="MIN_OPENING_MONTH"
          :max-date="maxOpeningMonth"
          :manual-input="false"
          placeholder="請選擇起始月份"
          show-icon
          icon-display="input"
          aria-required="true"
          :invalid="!!errors.openingMonth"
          :aria-describedby="errors.openingMonth ? `${uid}-month-err` : undefined"
          fluid
          @update:model-value="errors.openingMonth = ''"
        />
        <span class="dlg-note">起始金額視為這個月月初的餘額，這個月之前的收付款不計入現金流。只支援新台幣。</span>
        <span v-if="errors.openingMonth" :id="`${uid}-month-err`" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.openingMonth }}
        </span>
      </div>
      <button type="submit" class="hidden" />
    </form>
    <template #footer>
      <Button label="取消" outlined :disabled="submitting" @click="visible = false" />
      <Button label="儲存" :loading="submitting" @click="onSubmit" />
    </template>
  </Dialog>
</template>
