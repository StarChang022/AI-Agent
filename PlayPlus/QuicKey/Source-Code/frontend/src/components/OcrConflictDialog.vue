<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { OcrFieldKey, OcrFields, OcrInvoiceConflict, OcrItem, OcrRole } from '@/api/ocr'
import type {
  OcrConflictChoice,
  OcrConflictState,
  OcrFieldQuestion,
  OcrInvoiceCandidate,
} from '@/composables/useOcrRecognize'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import { formatCurrency } from '@/utils/format'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'

/**
 * 多張憑證辨識結果不一致時，讓使用者逐一挑選要保留的值（規格 §6：不自動選信心度最高的）。
 * - 多張發票：同一個檔案解出多張不同號碼的發票時，先問要用哪一張，整張帶入欄位與品項（規格 §3.2）
 * - 欄位衝突：每個欄位挑一個候選值；發票字軌與數字合成一題「發票號碼」，選一張就整組帶入
 * - 品項衝突：同一品項（名稱 + 單價相同）但數量 / 小計不同，挑一筆保留
 * 沒挑完就關掉 → 衝突欄位維持空白，由使用者自行輸入。
 */
interface Props {
  conflict: OcrConflictState | null
  role: OcrRole
}

const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'confirm', choice: OcrConflictChoice): void
  (e: 'close'): void
}>()

/** 欄位名稱與各表單一致；對方在收入表單是客戶（買方） */
const FIELD_LABELS = computed<Record<OcrFieldKey, string>>(() => {
  const isIncome = props.role === 'income'
  return {
    documentType: '憑證類型',
    incurredAt: isIncome ? '開立日期' : '交易日期',
    ourTaxId: '我方統編',
    ourName: '我方名稱',
    counterpartyTaxId: isIncome ? '買方統編' : '賣方統編',
    counterpartyName: isIncome ? '客戶名稱' : '賣方名稱',
    // 字軌與數字在彈窗裡合成一題，不會單獨出現
    invoicePrefix: '發票號碼',
    invoiceDigits: '發票號碼',
    taxRate: '稅率',
    preTaxAmt: '未稅金額',
    taxAmt: '稅額',
    amount: '含稅金額',
  }
})

const AMOUNT_FIELDS: ReadonlySet<OcrFieldKey> = new Set(['preTaxAmt', 'taxAmt', 'amount'])

function formatValue(field: OcrFieldKey, value: OcrFields[OcrFieldKey]): string {
  if (value === null || value === '') return '（未辨識）'
  if (field === 'documentType') return DOCUMENT_TYPE_OPTIONS.find((o) => o.value === value)?.label ?? String(value)
  if (field === 'taxRate') return TAX_RATE_OPTIONS.find((o) => o.value === value)?.label ?? String(value)
  if (AMOUNT_FIELDS.has(field) && typeof value === 'number') return formatCurrency(value)
  return String(value)
}

/** 完整發票號碼，例如 FV-63156693；某一半沒讀到時標示未辨識 */
function formatInvoiceNo(c: OcrInvoiceCandidate): string {
  if (!c.invoicePrefix && !c.invoiceDigits) return '（未辨識）'
  return `${c.invoicePrefix ?? '（未辨識）'}-${c.invoiceDigits ?? '（未辨識）'}`
}

function questionLabel(q: OcrFieldQuestion): string {
  return q.kind === 'invoice' ? '發票號碼' : FIELD_LABELS.value[q.field]
}

function candidateText(q: OcrFieldQuestion, j: number): string {
  return q.kind === 'invoice' ? formatInvoiceNo(q.candidates[j]) : formatValue(q.field, q.candidates[j].value)
}

function sourceLabel(index: number): string {
  return props.conflict?.sourceLabels[index] ?? `憑證 ${index + 1}`
}

function invoiceTitle(inv: OcrInvoiceConflict): string {
  return `${sourceLabel(inv.sourceIndex)} 的第 ${inv.invoiceIndex} 張發票`
}

/** 號碼、日期、金額，讓使用者對照紙本認出是哪一張 */
function invoiceSummary(inv: OcrInvoiceConflict): string {
  const f = inv.fields
  return [
    `號碼 ${formatInvoiceNo({ invoicePrefix: f.invoicePrefix ?? null, invoiceDigits: f.invoiceDigits ?? null, sourceIndex: inv.sourceIndex })}`,
    `日期 ${formatValue('incurredAt', f.incurredAt ?? null)}`,
    `金額 ${formatValue('amount', f.amount ?? null)}`,
  ].join('・')
}

function itemTitle(item: OcrItem): string {
  return `${item.name}（單價 ${formatCurrency(item.unitPrice)}）`
}

/** 各衝突目前挑的候選 index；null = 還沒挑 */
const invoicePick = ref<number | null>(null)
const fieldPicks = ref<(number | null)[]>([])
const itemPicks = ref<(number | null)[]>([])

watch(
  () => props.conflict,
  (c) => {
    invoicePick.value = null
    fieldPicks.value = c ? c.fields.map(() => null) : []
    itemPicks.value = c ? c.items.map(() => null) : []
  },
  { immediate: true },
)

const remaining = computed(
  () =>
    (props.conflict?.invoices.length && invoicePick.value === null ? 1 : 0) +
    fieldPicks.value.filter((p) => p === null).length +
    itemPicks.value.filter((p) => p === null).length,
)

function onConfirm() {
  const c = props.conflict
  if (!c || remaining.value > 0) return
  // 有多張發票時，挑中那張的欄位與品項整組帶入（代墊款的品項在 composable 已清空）
  const invoice = c.invoices.length > 0 ? c.invoices[invoicePick.value as number] : null
  const fields: Partial<OcrFields> = { ...invoice?.fields }
  c.fields.forEach((q, i) => {
    const pick = fieldPicks.value[i] as number
    if (q.kind === 'invoice') {
      fields.invoicePrefix = q.candidates[pick].invoicePrefix
      fields.invoiceDigits = q.candidates[pick].invoiceDigits
    } else {
      ;(fields as Record<OcrFieldKey, OcrFields[OcrFieldKey]>)[q.field] = q.candidates[pick].value
    }
  })
  const items = [
    ...(invoice?.items ?? []).map((it) => ({ ...it })),
    ...c.items.map((ic, i) => ({ ...ic.candidates[itemPicks.value[i] as number].item })),
  ]
  emit('confirm', { fields, items })
}
</script>

<template>
  <Dialog
    :visible="conflict !== null"
    modal
    :dismissable-mask="false"
    header="辨識結果不一致，請挑選"
    :style="{ width: 'min(92vw, 480px)' }"
    @update:visible="emit('close')"
  >
    <div v-if="conflict" class="flex flex-col gap-5">
      <p class="text-sm text-[var(--color-muted)]">
        辨識結果有不一致的地方，請逐一挑選要保留的內容。沒挑完就關閉的話，這些欄位會留白，可以自行填寫。
      </p>

      <fieldset v-if="conflict.invoices.length > 0" class="min-w-0">
        <legend class="pick-legend">要用哪一張發票？</legend>
        <div class="flex flex-col gap-2">
          <label
            v-for="(inv, j) in conflict.invoices"
            :key="`${inv.sourceIndex}-${inv.invoiceIndex}`"
            :for="`ocr-inv-${j}`"
            class="pick-option"
          >
            <input :id="`ocr-inv-${j}`" v-model="invoicePick" type="radio" name="ocr-inv" :value="j" />
            <span class="flex min-w-0 flex-col gap-0.5">
              <span class="font-medium">{{ invoiceTitle(inv) }}</span>
              <span class="break-words text-xs tabular-nums text-[var(--color-muted)]">{{ invoiceSummary(inv) }}</span>
            </span>
          </label>
        </div>
      </fieldset>

      <fieldset
        v-for="(q, i) in conflict.fields"
        :key="q.kind === 'invoice' ? 'f-invoice' : `f-${q.field}`"
        class="min-w-0"
      >
        <legend class="pick-legend">{{ questionLabel(q) }}</legend>
        <div class="flex flex-col gap-2">
          <label
            v-for="(cand, j) in q.candidates"
            :key="j"
            :for="`ocr-f-${i}-${j}`"
            class="pick-option"
          >
            <input
              :id="`ocr-f-${i}-${j}`"
              v-model="fieldPicks[i]"
              type="radio"
              :name="`ocr-f-${i}`"
              :value="j"
            />
            <span class="min-w-0 break-words">{{ candidateText(q, j) }}</span>
            <small>{{ sourceLabel(cand.sourceIndex) }}</small>
          </label>
        </div>
      </fieldset>

      <fieldset v-for="(ic, i) in conflict.items" :key="`i-${i}`" class="min-w-0">
        <legend class="pick-legend">品項：{{ itemTitle(ic.candidates[0].item) }}</legend>
        <div class="flex flex-col gap-2">
          <label
            v-for="(cand, j) in ic.candidates"
            :key="j"
            :for="`ocr-i-${i}-${j}`"
            class="pick-option"
          >
            <input
              :id="`ocr-i-${i}-${j}`"
              v-model="itemPicks[i]"
              type="radio"
              :name="`ocr-i-${i}`"
              :value="j"
            />
            <span class="min-w-0 tabular-nums">數量 {{ cand.item.quantity }}・小計 {{ formatCurrency(cand.item.subtotal) }}</span>
            <small>{{ sourceLabel(cand.sourceIndex) }}</small>
          </label>
        </div>
      </fieldset>

      <p class="text-sm text-[var(--color-muted)]" aria-live="polite">
        {{ remaining > 0 ? `還有 ${remaining} 項未選` : '都選好了，按「確認」帶入表單' }}
      </p>
    </div>

    <template #footer>
      <Button label="先不選，自行填寫" outlined @click="emit('close')" />
      <Button label="確認" :disabled="remaining > 0" @click="onConfirm" />
    </template>
  </Dialog>
</template>

<style scoped>
.pick-legend {
  margin-bottom: 8px;
  color: var(--color-ink);
  font-size: 14px;
  font-weight: 600;
}
.pick-option {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  padding: 10px 14px;
  border: 1.5px solid var(--hairline);
  border-radius: var(--radius-control);
  font-size: 14px;
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease;
}
.pick-option:hover {
  border-color: var(--primary-solid);
}
.pick-option:has(input:checked) {
  border-color: var(--primary-solid);
  background: var(--primary-50);
}
.pick-option:has(input:focus-visible) {
  box-shadow: 0 0 0 2px var(--primary-solid);
}
.pick-option input {
  flex-shrink: 0;
  accent-color: var(--primary-solid);
}
.pick-option small {
  margin-left: auto;
  flex-shrink: 0;
  color: var(--color-muted);
  font-size: 12px;
}
</style>
