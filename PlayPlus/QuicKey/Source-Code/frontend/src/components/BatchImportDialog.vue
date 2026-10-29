<script setup lang="ts">
/**
 * 批次匯入 Dialog（PDF + Excel 統一入口）。
 *
 * 對應 openspec/changes/add-general-expense-module/design.md Decision 5
 * 與 tasks.md §7。流程：
 *
 *   1. 使用者從支出列表 header 右上「匯入」按鈕開此 Dialog
 *   2. 選擇 PDF 或 xlsx（單檔）→ 顯示檔案卡片
 *   3. 點「開始辨識」→ 1.5s stub loading → 直接 stage 3 筆固定假資料
 *      → 關閉 Dialog → 導向 /admin/expenses/new（新增支出頁）
 *   4. 新增支出頁 onMounted 讀 `takeImportedPages()`，初始化 pages 陣列
 *      → 分頁元件顯示（見 ExpenseFormPagination）
 *
 * 現階段完全不真的解析 PDF/xlsx；「示範用途、實際解析由後端整合」由 Message 標明。
 * Dialog 內不再顯示預覽 DataTable（2026-09-08 改動：使用者要求開始辨識後直接
 * 跳轉到表單頁）；預覽改由表單頁的分頁 UI 讓使用者逐筆核對。
 */
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import type { FormPageData } from '@/types/expense-form'
import { stageImportedPages } from '@/composables/useStagedExpenseImport'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Message from 'primevue/message'

const props = defineProps<{ visible: boolean }>()
const emit = defineEmits<{ 'update:visible': [boolean] }>()

const router = useRouter()

const file = ref<File | null>(null)
const isRecognizing = ref(false)

const fileSizeText = computed(() => {
  if (!file.value) return ''
  const kb = file.value.size / 1024
  return kb < 1024
    ? `${kb.toFixed(1)} KB`
    : `${(kb / 1024).toFixed(2)} MB`
})

function reset() {
  file.value = null
  isRecognizing.value = false
}

watch(
  () => props.visible,
  (v) => {
    if (!v) reset()
  },
)

function fileIcon(f: File): string {
  const name = f.name.toLowerCase()
  if (name.endsWith('.pdf')) return 'pi-file-pdf'
  if (name.endsWith('.xlsx') || name.endsWith('.xls')) return 'pi-file-excel'
  return 'pi-file'
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  const f = target.files?.[0]
  target.value = ''
  if (!f) return
  file.value = f
}

function removeFile() {
  file.value = null
}

/**
 * 產生 3 筆固定假資料（PDF 與 Excel 共用；見 tasks.md §7.4）。
 * 三筆涵蓋交通費 / 伙食費 / 文具用品三個常用會計科目，每筆補上統編、
 * 發票號碼與品項讓表單頁能直接通過必填驗證（付款狀態除外）。
 */
function makeStubDrafts(): FormPageData[] {
  const today = new Date()
  return [
    {
      documentType: 'invoice',
      incurredAt: today,
      taxId: '03795302',
      vendor: '台北大車隊',
      invoiceNo: 'MA-88776655',
      taxRate: 'business_5',
      preTaxAmt: 333,
      taxAmt: 17,
      amount: 350,
      items: [
        { name: '計程車車資（信義區→內湖）', quantity: 1, unitPrice: 350, subtotal: 350 },
      ],
      categoryId: null,
      payoutStatus: null,
      note: '',
    },
    {
      documentType: 'invoice',
      incurredAt: today,
      taxId: '80072795',
      vendor: 'Starbucks 統一星巴克',
      invoiceNo: 'SB-11223344',
      taxRate: 'business_5',
      preTaxAmt: 210,
      taxAmt: 10,
      amount: 220,
      items: [
        { name: '拿鐵 Grande', quantity: 1, unitPrice: 150, subtotal: 150 },
        { name: '肉桂捲', quantity: 1, unitPrice: 70, subtotal: 70 },
      ],
      categoryId: null,
      payoutStatus: null,
      note: '',
    },
    {
      documentType: 'invoice',
      incurredAt: today,
      taxId: '12345678',
      vendor: '金石堂書局',
      invoiceNo: 'AB-98765432',
      taxRate: 'business_5',
      preTaxAmt: 848,
      taxAmt: 42,
      amount: 890,
      items: [
        { name: 'A4 影印紙 5 包', quantity: 5, unitPrice: 100, subtotal: 500 },
        { name: '原子筆 30 支', quantity: 30, unitPrice: 13, subtotal: 390 },
      ],
      categoryId: null,
      payoutStatus: null,
      note: '',
    },
  ]
}

/**
 * 開始辨識：stub loading 1.5s → 直接 stage + 關閉 Dialog + 導頁。
 * 不再於 Dialog 內顯示預覽；預覽動線由表單頁的分頁 UI 承擔。
 */
async function startRecognize() {
  if (!file.value || isRecognizing.value) return
  isRecognizing.value = true
  await new Promise((r) => setTimeout(r, 1500))
  const drafts = makeStubDrafts()
  stageImportedPages(drafts)
  isRecognizing.value = false
  emit('update:visible', false)
  router.push({ name: 'admin-expense-new' })
}

function close() {
  emit('update:visible', false)
}
</script>

<template>
  <Dialog
    :visible="visible"
    modal
    :closable="true"
    dismissable-mask
    header="批次匯入 PDF / Excel"
    :style="{ width: 'min(92vw, 560px)' }"
    :breakpoints="{ '640px': '96vw' }"
    @update:visible="emit('update:visible', $event)"
  >
    <div class="flex flex-col gap-4">
      <Message severity="info" :closable="false">
        示範用途，實際解析由後端整合。上傳 PDF 或 xlsx 後點「開始辨識」，系統會產生 3 筆固定假資料並帶入新增支出頁的分頁表單。
      </Message>

      <div>
        <label
          v-if="!file"
          class="flex flex-col items-center justify-center gap-2 px-4 py-8 rounded-xl border-2 border-dashed border-[var(--color-hairline)] bg-[var(--color-surface)] cursor-pointer hover:bg-white text-sm text-center"
        >
          <i
            class="pi pi-cloud-upload text-2xl text-[var(--color-muted)]"
            aria-hidden="true"
          />
          <div>
            點擊上傳 <strong>PDF 或 Excel</strong>
          </div>
          <div class="text-[11px] text-[var(--color-muted)]">
            單檔上限 10 MB；支援 .pdf / .xlsx / .xls
          </div>
          <input
            type="file"
            accept=".pdf,.xlsx,.xls,application/pdf,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            class="hidden"
            aria-label="上傳 PDF 或 Excel"
            @change="onFileChange"
          />
        </label>

        <div
          v-else
          class="flex items-center gap-3 p-3 rounded-xl border border-[var(--color-hairline)] bg-white"
        >
          <i
            :class="['pi', fileIcon(file), 'text-2xl text-[var(--color-primary)]']"
            aria-hidden="true"
          />
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium truncate">{{ file.name }}</div>
            <div class="text-xs text-[var(--color-muted)] tabular-nums">
              {{ fileSizeText }}
            </div>
          </div>
          <Button
            type="button"
            severity="secondary"
            text
            rounded
            icon="pi pi-times"
            :aria-label="`移除 ${file.name}`"
            :disabled="isRecognizing"
            @click="removeFile"
          />
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          label="取消"
          outlined
          :disabled="isRecognizing"
          @click="close"
        />
        <Button
          :label="isRecognizing ? '辨識中…' : '開始辨識'"
          :icon="isRecognizing ? 'pi pi-spin pi-spinner' : 'pi pi-sparkles'"
          :disabled="!file || isRecognizing"
          :aria-busy="isRecognizing"
          @click="startRecognize"
        />
      </div>
    </template>
  </Dialog>
</template>
