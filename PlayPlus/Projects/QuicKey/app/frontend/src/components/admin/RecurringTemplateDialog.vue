<script setup lang="ts">
/**
 * 建立／編輯固定收支範本（PRD 規則 17、docs/dev/recurring-api.md §1.1、§1.2）。
 * 建立，或編輯時改到週期相關欄位，送出前先查會當場產生的筆數並確認。
 */
import { computed, nextTick, reactive, ref, useId, watch } from 'vue'
import Button from 'primevue/button'
import DatePicker from '@/components/qds/DatePicker'
import Dialog from 'primevue/dialog'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import AccountSelect from '@/components/admin/AccountSelect.vue'
import { isAccountUnavailable } from '@/api/accounts'
import { listCategories, type Category } from '@/api/categories'
import {
  createRecurringTemplate,
  previewRecurringTemplate,
  updateRecurringTemplate,
  type CreateRecurringTemplateRequest,
  type RecurringPreview,
  type RecurringSchedule,
  type SavedRecurringTemplate,
} from '@/api/recurring'
import { HttpError } from '@/api/service'
import { useAccountOptions } from '@/composables/useAccountOptions'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import {
  RECURRING_DIRECTION_LABELS,
  type DocumentType,
  type RecurringDirection,
  type RecurringFrequency,
  type RecurringTemplate,
  type TaxRate,
} from '@/types/domain'
import { formatMonth, toIsoMonth } from '@/utils/format'
import { categoryBlockedHint } from '@/utils/recurring'
import { userErrorToast } from '@/utils/userFeedback'

const props = defineProps<{ direction: RecurringDirection; template?: RecurringTemplate | null }>()
const visible = defineModel<boolean>('visible', { required: true })
const emit = defineEmits<{ saved: [template: SavedRecurringTemplate] }>()

const confirm = useConfirm()
const toast = useToast()
const uid = useId()

const FREQUENCY_OPTIONS: { value: RecurringFrequency; label: string }[] = [
  { value: 'monthly', label: '每月' },
  { value: 'yearly', label: '每年' },
]
const DAY_OPTIONS = Array.from({ length: 31 }, (_, i) => ({ value: i + 1, label: `${i + 1} 號` }))
const MONTH_OPTIONS = Array.from({ length: 12 }, (_, i) => ({ value: i + 1, label: `${i + 1} 月` }))
const MIN_MONTH = new Date(2000, 0, 1)

const form = reactive({
  name: '',
  categoryId: null as string | null,
  accountId: null as string | null,
  documentType: 'invoice' as DocumentType,
  taxRate: 'business_5' as TaxRate,
  counterparty: '',
  taxId: '',
  amount: null as number | null,
  frequency: 'monthly' as RecurringFrequency,
  dayOfMonth: null as number | null,
  monthOfYear: null as number | null,
  startMonth: null as Date | null,
  endMonth: null as Date | null,
})
const errors = reactive({
  name: '',
  categoryId: '',
  accountId: '',
  counterparty: '',
  taxId: '',
  amount: '',
  monthOfYear: '',
  dayOfMonth: '',
  startMonth: '',
  endMonth: '',
})
type ErrorField = keyof typeof errors

const submitting = ref(false)
// 補產生提示開著時按 Esc 只關上層視窗，不連這個視窗一起關
const confirming = ref(false)

const isEdit = computed(() => !!props.template)
const direction = computed(() => props.template?.direction ?? props.direction)
const directionLabel = computed(() => RECURRING_DIRECTION_LABELS[direction.value])
const counterpartyLabel = computed(() => (direction.value === 'expense' ? '廠商' : '客戶'))
const startLocked = computed(() => !!props.template?.startMonthLocked)
const isInvoice = computed(() => form.documentType === 'invoice')
/** 統編只有支出的發票必填；收入的買方統編一律選填（開給個人的發票沒有買方統編） */
const taxIdRequired = computed(() => isInvoice.value && direction.value === 'expense')

/** 類別在垃圾桶或已停用的歷史範本不能延長，儲存前先說明；同一次編輯換掉類別就可以延長 */
const blockedHint = computed(() => {
  const t = props.template
  if (t?.status !== 'history' || form.categoryId !== t.category.id) return ''
  const hint = categoryBlockedHint(t.category)
  return hint && `${hint}也可以在這裡改選其他類別。`
})

const categories = ref<Category[]>([])
const categoriesLoading = ref(false)
const { options: accountOptions, loading: accountsLoading, load: loadAccounts, add: addAccountOption } = useAccountOptions()

/** 編輯時原本的類別可能已停用或在垃圾桶，保留為選項；沒換的話後端不會擋 */
const categoryOptions = computed(() => {
  const list = categories.value.map((c) => ({ value: c.id, label: c.name }))
  const current = props.template?.category
  if (current && !list.some((o) => o.value === current.id)) {
    list.push({ value: current.id, label: `${current.name}（${current.deletedAt ? '在垃圾桶' : '已停用'}）` })
  }
  return list
})

async function loadOptions(template: RecurringTemplate | null | undefined) {
  categoriesLoading.value = true
  try {
    categories.value = await listCategories({ kind: direction.value })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入類別失敗'), life: 3500 })
  } finally {
    categoriesLoading.value = false
  }
  await loadAccounts()
  if (template) addAccountOption(template.account)
}

/**
 * 選好月份後，PrimeVue 把焦點留在即將關閉的面板裡，面板一關焦點就不見了。
 * 趕在它 150ms 關閉面板前移回欄位，面板照常關閉，不會因為欄位取得焦點又打開。
 */
function returnFocusToMonth(field: 'start' | 'end') {
  setTimeout(() => document.getElementById(`${uid}-${field}`)?.focus(), 50)
}

function monthToDate(month: string): Date {
  return new Date(`${month}-01T00:00:00`)
}

watch(
  visible,
  (v) => {
    if (!v) return
    const t = props.template
    form.name = t?.name ?? ''
    form.categoryId = t?.category.id ?? null
    form.accountId = t?.account.id ?? null
    form.documentType = t?.documentType ?? 'invoice'
    form.taxRate = t?.taxRate ?? 'business_5'
    form.counterparty = t?.counterparty ?? ''
    form.taxId = t?.taxId ?? ''
    form.amount = t?.amount ?? null
    form.frequency = t?.frequency ?? 'monthly'
    form.dayOfMonth = t?.dayOfMonth ?? null
    form.monthOfYear = t?.monthOfYear ?? null
    form.startMonth = t ? monthToDate(t.startMonth) : null
    form.endMonth = t?.endMonth ? monthToDate(t.endMonth) : null
    ;(Object.keys(errors) as ErrorField[]).forEach((k) => (errors[k] = ''))
    void loadOptions(t)
  },
  { immediate: true },
)

/** 收據一律免稅，切回發票時改回營業稅 5%，同收支表單 */
function setDocumentType(type: DocumentType) {
  form.documentType = type
  form.taxRate = type === 'receipt' ? 'exempt_0' : 'business_5'
  errors.taxId = ''
}

function validate(): boolean {
  const taxId = form.taxId.trim()
  errors.name = form.name.trim() ? '' : '請填寫名稱'
  errors.categoryId = form.categoryId ? '' : '請選擇類別'
  errors.accountId = form.accountId ? '' : '請選擇帳戶'
  errors.counterparty = form.counterparty.trim() ? '' : `請填寫${counterpartyLabel.value}`
  if (!taxId) errors.taxId = taxIdRequired.value ? '文件類型為發票時，統一編號必填' : ''
  else errors.taxId = /^\d{8}$/.test(taxId) ? '' : '統一編號應為 8 碼數字'
  errors.amount = form.amount && form.amount > 0 ? '' : '請填寫大於 0 的金額'
  errors.monthOfYear = form.frequency === 'yearly' && !form.monthOfYear ? '請選擇月份' : ''
  errors.dayOfMonth = form.dayOfMonth ? '' : '請選擇日期'
  errors.startMonth = form.startMonth ? '' : '請選擇開始月份'
  errors.endMonth =
    form.startMonth && form.endMonth && toIsoMonth(form.endMonth) < toIsoMonth(form.startMonth)
      ? '結束月份不可早於開始月份'
      : ''
  return !Object.values(errors).some(Boolean)
}

/** 依畫面順序；值是欄位 id 的後綴 */
const ERROR_INPUTS: [ErrorField, string][] = [
  ['name', 'name'],
  ['categoryId', 'category'],
  ['accountId', 'account'],
  ['counterparty', 'counterparty'],
  ['taxId', 'tax-id'],
  ['amount', 'amount'],
  ['monthOfYear', 'month'],
  ['dayOfMonth', 'day'],
  ['startMonth', 'start'],
  ['endMonth', 'end'],
]

async function focusFirstError() {
  const first = ERROR_INPUTS.find(([field]) => errors[field])
  if (!first) return
  await nextTick()
  document.getElementById(`${uid}-${first[1]}`)?.focus()
}

function scheduleBody(): RecurringSchedule {
  return {
    frequency: form.frequency,
    dayOfMonth: form.dayOfMonth as number,
    monthOfYear: form.frequency === 'yearly' ? form.monthOfYear : null,
    startMonth: toIsoMonth(form.startMonth as Date),
    endMonth: form.endMonth ? toIsoMonth(form.endMonth) : null,
  }
}

const SCHEDULE_KEYS: (keyof RecurringSchedule)[] = ['frequency', 'dayOfMonth', 'monthOfYear', 'startMonth', 'endMonth']

function scheduleChanged(template: RecurringTemplate): boolean {
  const schedule = scheduleBody()
  return SCHEDULE_KEYS.some((key) => schedule[key] !== template[key])
}

function backfillRange(periods: string[]): string {
  const first = formatMonth(periods[0])
  const last = formatMonth(periods[periods.length - 1])
  return first === last ? first : `${first} 至 ${last}`
}

function confirmBackfill(preview: RecurringPreview) {
  const pending = direction.value === 'expense' ? '待付款' : '待收款'
  const summary = `${preview.backfillCount} 筆紀錄（${backfillRange(preview.backfillPeriods)}），一律為${pending}`
  confirming.value = true
  confirm.require({
    header: isEdit.value ? '儲存時會產生紀錄' : '補產生已過的期數',
    message: isEdit.value
      ? `修改後，週期日已過且尚未產生的期數，會在儲存時立即產生 ${summary}。確定要儲存嗎？`
      : `週期日已過的期數會補產生 ${summary}。確定要儲存嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '確認',
    rejectLabel: '取消',
    accept: () => {
      confirming.value = false
      void save()
    },
    reject: () => (confirming.value = false),
    onHide: () => (confirming.value = false),
  })
}

async function onSubmit() {
  if (submitting.value) return
  if (!validate()) {
    void focusFirstError()
    return
  }
  const template = props.template
  if (template && !scheduleChanged(template)) {
    void save()
    return
  }
  submitting.value = true
  let preview: RecurringPreview
  try {
    preview = await previewRecurringTemplate(
      template
        ? { ...scheduleBody(), templateId: template.id, categoryId: form.categoryId as string }
        : scheduleBody(),
    )
  } catch (err) {
    showSaveError(err)
    return
  } finally {
    submitting.value = false
  }
  if (!preview.hasPeriods) {
    errors.endMonth = preview.message ?? '開始到結束月份之間沒有任何一期，請調整週期或月份'
    return
  }
  if (preview.backfillCount > 0) {
    // 查詢時「儲存」停用會失去焦點；先移回去，確認視窗關閉時才回得來
    await nextTick()
    document.getElementById(`${uid}-save`)?.focus()
    confirmBackfill(preview)
  } else {
    void save()
  }
}

async function save() {
  const template = props.template
  const body: CreateRecurringTemplateRequest = {
    ...scheduleBody(),
    direction: direction.value,
    name: form.name.trim(),
    categoryId: form.categoryId as string,
    accountId: form.accountId as string,
    documentType: form.documentType,
    taxRate: form.taxRate,
    counterparty: form.counterparty.trim(),
    taxId: form.taxId.trim() || null,
    amount: form.amount as number,
  }
  submitting.value = true
  try {
    const saved = template
      ? await updateRecurringTemplate(template.id, body)
      : await createRecurringTemplate(body)
    const backfilled = saved.backfilledCount ? `，已產生 ${saved.backfilledCount} 筆紀錄` : ''
    toast.add({
      severity: 'success',
      summary: template ? '已更新範本' : '已建立範本',
      detail: `${saved.name}${backfilled}`,
      life: 2500,
    })
    emit('saved', saved)
    visible.value = false
  } catch (err) {
    showSaveError(err)
  } finally {
    submitting.value = false
  }
}

const ERROR_FIELDS: Record<string, ErrorField> = {
  INVALID_NAME: 'name',
  INVALID_COUNTERPARTY: 'counterparty',
  CATEGORY_NOT_FOUND: 'categoryId',
  CATEGORY_WRONG_KIND: 'categoryId',
  ACCOUNT_REQUIRED: 'accountId',
  ACCOUNT_NOT_FOUND: 'accountId',
  TAX_ID_REQUIRED: 'taxId',
  INVALID_TAX_ID: 'taxId',
  INVALID_AMOUNT: 'amount',
  INVALID_SCHEDULE: 'dayOfMonth',
  INVALID_MONTH: 'startMonth',
  START_MONTH_LOCKED: 'startMonth',
  NO_PERIODS: 'endMonth',
  CATEGORY_IN_TRASH: 'endMonth',
  CATEGORY_ARCHIVED: 'endMonth',
}

function showSaveError(err: unknown) {
  const code = err instanceof HttpError ? (err.body as { error?: string })?.error : undefined
  const failed = userErrorToast(err, isEdit.value ? '更新範本失敗' : '建立範本失敗')
  const field = code ? ERROR_FIELDS[code] : undefined
  if (field) errors[field] = failed.detail
  else toast.add({ severity: 'error', ...failed, life: 3500 })
  if (isAccountUnavailable(err)) {
    form.accountId = null
    void loadAccounts()
  }
}
</script>

<template>
  <Dialog
    v-model:visible="visible"
    modal
    :header="isEdit ? `編輯${directionLabel}` : `建立${directionLabel}`"
    :close-on-escape="!confirming"
    :style="{ width: 'min(92vw, 640px)' }"
  >
    <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
      <div class="q-field">
        <label :for="`${uid}-name`">名稱 <span class="req">*</span></label>
        <InputText
          :id="`${uid}-name`"
          v-model="form.name"
          placeholder="例如：辦公室租金"
          maxlength="50"
          autofocus
          aria-required="true"
          :invalid="!!errors.name"
          :aria-describedby="errors.name ? `${uid}-name-err` : undefined"
          @input="errors.name = ''"
        />
        <span class="dlg-note">會帶入產生紀錄的說明。</span>
        <span v-if="errors.name" :id="`${uid}-name-err`" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.name }}
        </span>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :id="`${uid}-category-label`" :for="`${uid}-category`">類別 <span class="req">*</span></label>
          <Select
            v-model="form.categoryId"
            :input-id="`${uid}-category`"
            :options="categoryOptions"
            option-label="label"
            option-value="value"
            placeholder="請選擇類別"
            :loading="categoriesLoading"
            :aria-labelledby="`${uid}-category-label`"
            :invalid="!!errors.categoryId"
            :pt="{ label: { 'aria-required': 'true', 'aria-describedby': errors.categoryId ? `${uid}-category-err` : undefined } }"
            empty-message="沒有可用的類別"
            fluid
            @update:model-value="errors.categoryId = ''"
          />
          <span v-if="errors.categoryId" :id="`${uid}-category-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.categoryId }}
          </span>
        </div>
        <div class="q-field">
          <label :id="`${uid}-account-label`" :for="`${uid}-account`">帳戶 <span class="req">*</span></label>
          <AccountSelect
            v-model="form.accountId"
            :input-id="`${uid}-account`"
            :labelled-by="`${uid}-account-label`"
            :options="accountOptions"
            :loading="accountsLoading"
            :invalid="!!errors.accountId"
            :error-id="errors.accountId ? `${uid}-account-err` : undefined"
            @update:model-value="errors.accountId = ''"
          />
          <span v-if="errors.accountId" :id="`${uid}-account-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.accountId }}
          </span>
        </div>
      </div>

      <div class="q-field">
        <span :id="`${uid}-doc-label`" class="q-label">文件類型</span>
        <div class="choice-cards doc-type-cards" role="radiogroup" :aria-labelledby="`${uid}-doc-label`">
          <label v-for="opt in DOCUMENT_TYPE_OPTIONS" :key="opt.value" :for="`${uid}-doc-${opt.value}`">
            <input
              :id="`${uid}-doc-${opt.value}`"
              :checked="form.documentType === opt.value"
              :value="opt.value"
              type="radio"
              :name="`${uid}-doc`"
              @change="setDocumentType(opt.value)"
            />
            <span>
              {{ opt.label }}
              <small>{{ opt.value === 'invoice' ? '統一發票，含發票號碼與營業稅額' : '收據或免用發票收據，無發票號碼與稅額' }}</small>
            </span>
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :for="`${uid}-counterparty`">{{ counterpartyLabel }} <span class="req">*</span></label>
          <InputText
            :id="`${uid}-counterparty`"
            v-model="form.counterparty"
            maxlength="100"
            aria-required="true"
            :invalid="!!errors.counterparty"
            :aria-describedby="errors.counterparty ? `${uid}-counterparty-err` : undefined"
            @input="errors.counterparty = ''"
          />
          <span v-if="errors.counterparty" :id="`${uid}-counterparty-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.counterparty }}
          </span>
        </div>
        <div class="q-field">
          <label :for="`${uid}-tax-id`">統一編號 <span v-if="taxIdRequired" class="req">*</span></label>
          <InputText
            :id="`${uid}-tax-id`"
            v-model="form.taxId"
            maxlength="8"
            inputmode="numeric"
            :aria-required="taxIdRequired"
            :invalid="!!errors.taxId"
            :aria-describedby="errors.taxId ? `${uid}-tax-id-err` : undefined"
            @input="errors.taxId = ''"
          />
          <span v-if="errors.taxId" :id="`${uid}-tax-id-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.taxId }}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :for="`${uid}-amount`">金額（含稅） <span class="req">*</span></label>
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
        <div v-if="isInvoice" class="q-field">
          <label :id="`${uid}-tax-rate-label`" :for="`${uid}-tax-rate`">稅別</label>
          <Select
            v-model="form.taxRate"
            :input-id="`${uid}-tax-rate`"
            :options="TAX_RATE_OPTIONS"
            option-label="label"
            option-value="value"
            :aria-labelledby="`${uid}-tax-rate-label`"
            fluid
          />
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4" :class="form.frequency === 'yearly' ? 'sm:grid-cols-3' : 'sm:grid-cols-2'">
        <div class="q-field">
          <label :id="`${uid}-frequency-label`" :for="`${uid}-frequency`">週期 <span class="req">*</span></label>
          <Select
            v-model="form.frequency"
            :input-id="`${uid}-frequency`"
            :options="FREQUENCY_OPTIONS"
            option-label="label"
            option-value="value"
            :aria-labelledby="`${uid}-frequency-label`"
            fluid
            @update:model-value="errors.monthOfYear = ''"
          />
        </div>
        <div v-if="form.frequency === 'yearly'" class="q-field">
          <label :id="`${uid}-month-label`" :for="`${uid}-month`">月份 <span class="req">*</span></label>
          <Select
            v-model="form.monthOfYear"
            :input-id="`${uid}-month`"
            :options="MONTH_OPTIONS"
            option-label="label"
            option-value="value"
            placeholder="請選擇"
            :aria-labelledby="`${uid}-month-label`"
            :invalid="!!errors.monthOfYear"
            :pt="{ label: { 'aria-required': 'true', 'aria-describedby': errors.monthOfYear ? `${uid}-month-err` : undefined } }"
            fluid
            @update:model-value="errors.monthOfYear = ''"
          />
          <span v-if="errors.monthOfYear" :id="`${uid}-month-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.monthOfYear }}
          </span>
        </div>
        <div class="q-field">
          <label :id="`${uid}-day-label`" :for="`${uid}-day`">日期 <span class="req">*</span></label>
          <Select
            v-model="form.dayOfMonth"
            :input-id="`${uid}-day`"
            :options="DAY_OPTIONS"
            option-label="label"
            option-value="value"
            placeholder="請選擇"
            :aria-labelledby="`${uid}-day-label`"
            :invalid="!!errors.dayOfMonth"
            :pt="{ label: { 'aria-required': 'true', 'aria-describedby': errors.dayOfMonth ? `${uid}-day-err` : undefined } }"
            fluid
            @update:model-value="errors.dayOfMonth = ''"
          />
          <span v-if="errors.dayOfMonth" :id="`${uid}-day-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.dayOfMonth }}
          </span>
        </div>
      </div>
      <p class="dlg-note">月份沒有這一天時，產生在當月最後一天。</p>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div class="q-field">
          <label :for="`${uid}-start`">開始月份 <span class="req">*</span></label>
          <DatePicker
            v-model="form.startMonth"
            :input-id="`${uid}-start`"
            view="month"
            date-format="yy/mm"
            :min-date="MIN_MONTH"
            :manual-input="false"
            :disabled="startLocked"
            placeholder="請選擇開始月份"
            show-icon
            icon-display="input"
            aria-required="true"
            :invalid="!!errors.startMonth"
            :aria-describedby="errors.startMonth ? `${uid}-start-err` : undefined"
            fluid
            @update:model-value="errors.startMonth = ''"
            @date-select="returnFocusToMonth('start')"
          />
          <span v-if="startLocked" class="dlg-note">已產生過紀錄，開始月份不可修改。</span>
          <span v-if="errors.startMonth" :id="`${uid}-start-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.startMonth }}
          </span>
        </div>
        <div class="q-field">
          <label :for="`${uid}-end`">結束月份</label>
          <DatePicker
            v-model="form.endMonth"
            :input-id="`${uid}-end`"
            view="month"
            date-format="yy/mm"
            :min-date="form.startMonth ?? MIN_MONTH"
            :manual-input="false"
            show-clear
            placeholder="持續產生"
            :invalid="!!errors.endMonth"
            :aria-describedby="errors.endMonth ? `${uid}-end-err` : undefined"
            fluid
            @update:model-value="errors.endMonth = ''"
            @date-select="returnFocusToMonth('end')"
          />
          <span v-if="blockedHint" class="dlg-note">{{ blockedHint }}</span>
          <span v-if="errors.endMonth" :id="`${uid}-end-err`" class="q-error">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ errors.endMonth }}
          </span>
        </div>
      </div>
      <button type="submit" class="hidden" />
    </form>
    <template #footer>
      <Button label="取消" outlined :disabled="submitting" @click="visible = false" />
      <Button :id="`${uid}-save`" label="儲存" :loading="submitting" @click="onSubmit" />
    </template>
  </Dialog>
</template>
