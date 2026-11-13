<script setup lang="ts">
/**
 * 批次匯入憑證（支出／收入）。對應 docs/資料模型.md §5.5、docs/批次匯入規格.md 第二節。
 *
 * 先找張數、確認後才逐張辨識並扣次：
 *   ① 上傳 PDF／圖片 → ② 找出每頁有幾張憑證（還不辨識內容、不扣次）
 *   → ③ 確認（次數不夠時依頁勾選）→ 後端逐張辨識，辨識出內容的一張扣一次 → 暫存後導到新增頁逐筆核對。
 * 取消或關閉視窗一律呼叫 DELETE 釋放暫存，不扣次。
 */
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  batchRecognize,
  cancelBatch,
  confirmBatch,
  getQuota,
  type OcrBatchErrorCode,
  type OcrBatchPageAttachment,
  type OcrBatchPage,
  type OcrBatchResponse,
  type OcrQuotaSnapshot,
} from '@/api/ocr'
import { HttpError } from '@/api/service'
import { stagedExpensePages, stagedIncomePages } from '@/composables/useStagedImport'
import { ocrToExpensePage, ocrToIncomePage } from '@/utils/ocrForm'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import Dialog from 'primevue/dialog'
import Message from 'primevue/message'
import ProgressBar from 'primevue/progressbar'
import { useToast } from 'primevue/usetoast'

const props = defineProps<{ visible: boolean; kind: 'expense' | 'income' }>()
const emit = defineEmits<{ 'update:visible': [boolean] }>()

const router = useRouter()
const toast = useToast()

const MAX_FILES = 5
const MAX_FILE_MB = 20
const MAX_PAGES = 5

const formName = computed(() => (props.kind === 'income' ? '新增收入頁' : '新增支出頁'))

type Step = 'upload' | 'recognizing' | 'confirm'
const step = ref<Step>('upload')
const files = ref<File[]>([])
const isDragging = ref(false)
/** 上傳步驟的錯誤（格式／大小／張數不符、辨識失敗） */
const uploadError = ref('')
/** 確認步驟的錯誤（次數不足等） */
const confirmError = ref('')
const quota = ref<OcrQuotaSnapshot | null>(null)
const batch = ref<OcrBatchResponse | null>(null)
const selected = ref<Set<string>>(new Set())
const confirming = ref(false)
/** 辨識請求序號：辨識中關閉視窗後，晚到的結果直接釋放暫存 */
let recognizeSeq = 0

// ─── 開關 ─────────────────────────────────────────
function reset() {
  recognizeSeq += 1
  step.value = 'upload'
  files.value = []
  isDragging.value = false
  uploadError.value = ''
  confirmError.value = ''
  batch.value = null
  selected.value = new Set()
  confirming.value = false
}

watch(
  () => props.visible,
  (v) => {
    if (v) loadQuota()
    else reset()
  },
)

// 父層卸載（例如換頁離開）時也釋放暫存；辨識中的請求晚到時由序號比對後釋放
onBeforeUnmount(() => {
  recognizeSeq += 1
  releaseBatch()
})

// 切換步驟時焦點移到新步驟的標題，避免按鈕被移除後焦點掉回頁面最上方
watch(step, async (s) => {
  await nextTick()
  const target =
    s === 'upload' ? (document.getElementById('br-upload-err') ?? document.getElementById('br-file-input')) : document.getElementById(`br-step-${s}`)
  target?.focus()
})

async function loadQuota() {
  try {
    const q = await getQuota()
    quota.value = { monthlyRemaining: q.monthlyRemaining, purchasedRemaining: q.purchasedRemaining }
  } catch {
    // 查不到就不顯示剩餘次數，次數不足時由後端擋下
    quota.value = null
  }
}

/** 取消或關閉：還有未確認的暫存就釋放，不扣次 */
function releaseBatch() {
  const token = batch.value?.token
  batch.value = null
  if (token) cancelBatch(token).catch(() => {})
}

function close() {
  if (confirming.value) return
  releaseBatch()
  emit('update:visible', false)
}

// ─── 剩餘次數 ──────────────────────────────────────
const remaining = computed(() =>
  quota.value ? quota.value.monthlyRemaining + quota.value.purchasedRemaining : null,
)
const quotaText = computed(() => {
  const q = quota.value
  if (!q) return ''
  return q.purchasedRemaining > 0
    ? `本月剩餘 ${q.monthlyRemaining} 次 / 加購 ${q.purchasedRemaining} 次`
    : `本月剩餘 ${q.monthlyRemaining} 次`
})
const quotaExhausted = computed(() => remaining.value === 0)

// ─── 上傳 ─────────────────────────────────────────
/** 與後端一致：JPG、PNG、WEBP、HEIC、PDF（有些系統的 HEIC／PDF 沒有 MIME type，用副檔名判斷） */
const ACCEPTED_EXT = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.pdf']
const ACCEPTED_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
const ACCEPT_ATTR = [...ACCEPTED_EXT, ...ACCEPTED_MIME].join(',')

function isAccepted(f: File): boolean {
  const name = f.name.toLowerCase()
  return ACCEPTED_MIME.includes(f.type) || ACCEPTED_EXT.some((ext) => name.endsWith(ext))
}

function addFiles(list: FileList | File[] | undefined | null) {
  if (!list) return
  uploadError.value = ''
  for (const f of Array.from(list)) {
    if (files.value.length >= MAX_FILES) {
      uploadError.value = `一次最多 ${MAX_FILES} 個檔案，多的請分批匯入。`
      break
    }
    if (!isAccepted(f)) {
      uploadError.value = `「${f.name}」格式不支援，僅支援 JPG、PNG、WebP、HEIC 圖片與 PDF。`
      continue
    }
    if (f.size > MAX_FILE_MB * 1024 * 1024) {
      uploadError.value = `「${f.name}」超過 ${MAX_FILE_MB}MB，請壓縮或拆檔後再上傳。`
      continue
    }
    files.value = [...files.value, f]
  }
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  addFiles(target.files)
  target.value = ''
}

function onDrop(event: DragEvent) {
  isDragging.value = false
  addFiles(event.dataTransfer?.files)
}

function removeFile(index: number) {
  files.value = files.value.filter((_, i) => i !== index)
  uploadError.value = ''
}

function sizeText(f: File): string {
  const kb = f.size / 1024
  return kb < 1024 ? `${kb.toFixed(1)} KB` : `${(kb / 1024).toFixed(1)} MB`
}

// ─── 錯誤說明 ──────────────────────────────────────
type BatchErrorBody = { code?: OcrBatchErrorCode; message?: string; quota?: OcrQuotaSnapshot; required?: number }

const EXHAUSTED_TEXT = '本月 OCR 辨識次數已用完，可以先改用手動輸入，下個月 1 日會重新計算。'

const ERROR_TEXT: Partial<Record<OcrBatchErrorCode, string>> = {
  invalid_file_type: '有檔案格式不支援，僅支援 JPG、PNG、WebP、HEIC 圖片與 PDF，請移除後重新上傳。',
  too_many_files: `一次最多 ${MAX_FILES} 個檔案，請移除部分檔案後再試。`,
  file_too_large: `單檔不得超過 ${MAX_FILE_MB}MB，請壓縮或拆檔後再上傳。`,
  too_many_pages: `合計超過 ${MAX_PAGES} 頁，請分批匯入。`,
  quota_exhausted: EXHAUSTED_TEXT,
  ocr_unavailable: '辨識服務暫時無法使用，請稍後再試，或改用手動輸入。',
  ocr_no_result: '沒有找到任何憑證，未扣次。請換清楚一點的檔案再試，或改用手動輸入。',
  batch_expired: '辨識結果已失效（超過 30 分鐘、已帶出過，或系統暫存已清除），請重新上傳。',
  invalid_page_ids: '勾選的頁有誤或都沒有憑證，請重新勾選。',
  batch_in_progress: '上一批憑證還在辨識中，請稍後再試。',
}

function errorBody(err: unknown): BatchErrorBody | undefined {
  return err instanceof HttpError ? (err.body as BatchErrorBody | undefined) : undefined
}

function errorText(err: unknown): string {
  if (err instanceof TypeError) return '無法連線，請確認網路後再試一次。'
  const body = errorBody(err)
  const known = body?.code ? ERROR_TEXT[body.code] : undefined
  if (known) return known
  // 沒有代碼的 413／504／524 來自 proxy（整批超過上傳上限、等太久）
  if (err instanceof HttpError && err.status === 413) return `檔案太大，合計不得超過 ${MAX_FILES * MAX_FILE_MB}MB，請分批匯入。`
  if (err instanceof HttpError && (err.status === 504 || err.status === 524)) return '等待辨識太久沒有回應，檔案較多時請分批上傳。'
  if (body?.message && /[一-鿿]/.test(body.message)) return body.message
  return '辨識失敗，請稍後再試。'
}

function updateQuota(next: OcrQuotaSnapshot | undefined) {
  if (next) quota.value = { monthlyRemaining: next.monthlyRemaining, purchasedRemaining: next.purchasedRemaining }
}

// ─── 辨識 ─────────────────────────────────────────
const canRecognize = computed(() => files.value.length > 0 && !quotaExhausted.value)

async function startRecognize() {
  if (!canRecognize.value) return
  const seq = ++recognizeSeq
  step.value = 'recognizing'
  uploadError.value = ''
  try {
    const res = await batchRecognize(files.value, props.kind)
    if (seq !== recognizeSeq) {
      // 辨識中已關閉視窗或重來：直接釋放，不扣次
      cancelBatch(res.token).catch(() => {})
      return
    }
    batch.value = res
    updateQuota(res.quota)
    confirmError.value = ''
    // 次數夠時預設全選；不夠時讓使用者自己挑
    const all = res.pages.filter((p) => p.receiptCount > 0)
    const total = all.reduce((sum, p) => sum + p.receiptCount, 0)
    selected.value = remaining.value === null || total <= remaining.value ? new Set(all.map((p) => p.pageId)) : new Set()
    step.value = 'confirm'
  } catch (err) {
    if (seq !== recognizeSeq) return
    updateQuota(errorBody(err)?.quota)
    uploadError.value = errorText(err)
    step.value = 'upload'
  }
}

/** 回到上傳步驟（保留檔案）；釋放目前的暫存 */
function backToUpload() {
  releaseBatch()
  selected.value = new Set()
  confirmError.value = ''
  step.value = 'upload'
}

// ─── 確認扣次 ──────────────────────────────────────
const pages = computed(() => batch.value?.pages ?? [])
const totalReceipts = computed(() => batch.value?.receiptCount ?? 0)
const selectedCount = computed(() =>
  pages.value.filter((p) => selected.value.has(p.pageId)).reduce((sum, p) => sum + p.receiptCount, 0),
)
const insufficient = computed(() => remaining.value !== null && totalReceipts.value > remaining.value)
const overLimit = computed(() => remaining.value !== null && selectedCount.value > remaining.value)
const canConfirm = computed(() => selectedCount.value > 0 && !overLimit.value && !confirming.value)

function pageLabel(p: OcrBatchPage): string {
  return `${p.filename} 第 ${p.pageNumber} 頁`
}

function togglePage(p: OcrBatchPage, checked: boolean) {
  const next = new Set(selected.value)
  if (checked) next.add(p.pageId)
  else next.delete(p.pageId)
  selected.value = next
}

/** 確認送出時勾選的張數；辨識完和實際帶出的張數比對 */
const requestedCount = ref(0)

async function focusById(id: string) {
  await nextTick()
  document.getElementById(id)?.focus()
}

/** 暫存已用掉（或已失效）時退回上傳步驟，保留檔案 */
function restartUpload(message: string) {
  releaseBatch()
  selected.value = new Set()
  uploadError.value = message
  step.value = 'upload'
}

async function submitConfirm() {
  if (!canConfirm.value || !batch.value) return
  confirming.value = true
  confirmError.value = ''
  requestedCount.value = selectedCount.value
  // 按鈕停用後焦點會掉，移到等待說明
  focusById('br-confirm-status')
  const pageIds = pages.value.filter((p) => selected.value.has(p.pageId)).map((p) => p.pageId)
  try {
    const res = await confirmBatch(batch.value.token, pageIds)
    // 已確認，暫存由後端消耗；關閉時不需再 DELETE
    batch.value = null
    confirming.value = false
    // receipts 只含辨識出內容的；辨識不出或逾時的不扣次
    const missed = Math.max(requestedCount.value - res.receipts.length, 0)
    if (!res.receipts.length) {
      restartUpload([`選的 ${requestedCount.value} 張都辨識不出內容，未扣次。請換清楚一點的檔案再試，或改用手動輸入。`, ...res.warnings].join(' '))
      return
    }
    // 每頁的圖檔已是暫存檔；同一頁拆出的多張憑證共用同一個 id（檔案共用）
    const attachmentOf = new Map(res.pages.map((p: OcrBatchPageAttachment) => [p.pageId, p.attachment]))
    if (props.kind === 'income') {
      stagedIncomePages.stage(res.receipts.map((r) => ocrToIncomePage(r.result, attachmentOf.get(r.pageId) ?? null)))
    } else {
      stagedExpensePages.stage(res.receipts.map((r) => ocrToExpensePage(r.result, attachmentOf.get(r.pageId) ?? null)))
    }
    emit('update:visible', false)
    await router.push({ name: props.kind === 'income' ? 'admin-income-new' : 'admin-expense-new' })
    // 辨識不出的張數、逾時要重新上傳的頁、超過 5MB 未附上憑證檔等；新增頁的載入提示之後再顯示
    const notes = [...(missed ? [`${missed} 張辨識不出內容，未扣次`] : []), ...res.warnings]
    if (notes.length) {
      toast.add({ severity: 'warn', summary: '匯入提醒', detail: notes.join('；'), life: 8000 })
    }
  } catch (err) {
    confirming.value = false
    const body = errorBody(err)
    updateQuota(body?.quota)
    if (body?.code === 'batch_expired' || body?.code === 'ocr_no_result') {
      restartUpload(
        body.code === 'ocr_no_result'
          ? `選的 ${requestedCount.value} 張都辨識不出內容，未扣次。請換清楚一點的檔案再試，或改用手動輸入。`
          : errorText(err),
      )
      return
    }
    if (body?.code === 'quota_insufficient') {
      const need = body.required ?? selectedCount.value
      confirmError.value = `剩餘次數不足：這次最多要扣 ${need} 次${remaining.value !== null ? `，剩餘 ${remaining.value} 次` : ''}。請減少勾選的頁，或先加購次數。`
    } else if (body?.code === 'ocr_unavailable') {
      // 後端不扣次、暫存保留，同一批可以再確認一次
      confirmError.value = '辨識服務暫時無法使用，這次沒有扣次。請稍後再按一次確認，或改用手動輸入。'
    } else {
      confirmError.value = errorText(err)
    }
    focusById('br-confirm-err')
  }
}

/** 只播報勾選造成的扣次變化；步驟切換、開始辨識由焦點移到標題／等待說明朗讀 */
const liveText = computed(() =>
  step.value === 'confirm' ? `目前勾選 ${selectedCount.value} 張，最多扣 ${selectedCount.value} 次` : '',
)
</script>

<template>
  <Dialog
    :visible="visible"
    modal
    header="批次匯入憑證"
    :closable="!confirming"
    :close-on-escape="!confirming"
    :style="{ width: 'min(92vw, 600px)' }"
    :breakpoints="{ '640px': '96vw' }"
    @update:visible="(v) => !v && close()"
  >
    <p class="sr-only" aria-live="polite">{{ liveText }}</p>

    <!-- ① 上傳 -->
    <div v-if="step === 'upload'" class="br-body">
      <p class="br-intro">
        一次上傳多張發票或收據，系統會先找出有幾張憑證，確認後才逐張辨識，並帶到{{ formName }}讓你逐筆核對。
        <br>辨識出內容的憑證一張扣一次辨識額度。
      </p>

      <Message v-if="quotaExhausted" severity="warn" :closable="false">{{ EXHAUSTED_TEXT }}</Message>

      <label
        class="upload-drop"
        :class="{ 'is-drag': isDragging }"
        @dragover.prevent="isDragging = true"
        @dragleave="isDragging = false"
        @drop.prevent="onDrop"
      >
        <i class="pi pi-cloud-upload upload-drop-icon" aria-hidden="true" />
        <b>拖放檔案，或點擊上傳</b>
        <span>PDF 或 JPG、PNG、WEBP、HEIC 圖片；最多 {{ MAX_FILES }} 個檔案、單檔 {{ MAX_FILE_MB }}MB、合計 {{ MAX_PAGES }} 頁以內</span>
        <input
          type="file"
          id="br-file-input"
          :accept="ACCEPT_ATTR"
          multiple
          class="sr-only"
          aria-label="上傳憑證檔案"
          :aria-describedby="uploadError ? 'br-upload-err' : undefined"
          @change="onFileChange"
        />
      </label>

      <ul v-if="files.length" class="br-files" aria-label="已選擇的檔案">
        <li v-for="(f, i) in files" :key="`${f.name}-${i}`">
          <i :class="['pi', f.type.startsWith('image/') ? 'pi-image' : 'pi-file-pdf']" aria-hidden="true" />
          <span class="br-file-name">{{ f.name }}</span>
          <span class="br-file-size">{{ sizeText(f) }}</span>
          <Button
            icon="pi pi-times"
            text
            rounded
            severity="secondary"
            class="br-icon-btn"
            :aria-label="`移除 ${f.name}`"
            @click="removeFile(i)"
          />
        </li>
      </ul>

      <span v-if="uploadError" id="br-upload-err" class="q-error" role="alert" tabindex="-1">
        <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ uploadError }}
      </span>
      <p v-if="quotaText" class="dlg-note">
        <i class="pi pi-sparkles" aria-hidden="true" /> OCR 辨識{{ quotaText }}
      </p>
    </div>

    <!-- ② 辨識中 -->
    <div v-else-if="step === 'recognizing'" class="br-body br-progress">
      <i class="pi pi-spin pi-spinner" aria-hidden="true" />
      <h3 id="br-step-recognizing" class="br-step-title" tabindex="-1">正在找出憑證…</h3>
      <span>共 {{ files.length }} 個檔案，請稍候。</span>
      <ProgressBar mode="indeterminate" class="br-bar" aria-label="辨識進度" />
      <span class="dlg-note">現在關閉視窗會放棄這次匯入，不扣額度。</span>
    </div>

    <!-- ③ 確認扣次 -->
    <div v-else class="br-body" :aria-busy="confirming">
      <div class="dlg-summary">
        <h3 id="br-step-confirm" class="br-step-title br-summary-title" tabindex="-1">找到 {{ totalReceipts }} 張憑證</h3>
        <span>確認後最多扣 {{ selectedCount }} 次額度<template v-if="remaining !== null">（剩餘 {{ remaining }} 次）</template></span>
        <strong aria-hidden="true">{{ selectedCount }} 次</strong>
      </div>

      <div v-if="confirming" id="br-confirm-status" class="br-confirming" tabindex="-1">
        <div class="br-confirming-text">
          <i class="pi pi-spin pi-spinner" aria-hidden="true" />
          <span>正在逐張辨識 {{ requestedCount }} 張憑證，請勿關閉視窗。</span>
        </div>
        <ProgressBar mode="indeterminate" class="br-bar" aria-hidden="true" />
      </div>

      <Message v-if="insufficient" severity="warn" :closable="false">
        剩餘次數不夠帶出全部 {{ totalReceipts }} 張。請勾選要帶出的頁（合計最多 {{ remaining }} 次），或先加購次數後重新上傳。
      </Message>
      <Message v-for="(w, i) in batch?.warnings ?? []" :key="i" severity="info" :closable="false">{{ w }}</Message>

      <div class="br-pages-head">
        <span id="br-pages-title" class="br-legend">要帶出的頁</span>
        <Button label="重新上傳" icon="pi pi-refresh" text size="small" :disabled="confirming" @click="backToUpload" />
      </div>
      <fieldset class="br-pages" aria-labelledby="br-pages-title">
        <div v-for="p in pages" :key="p.pageId" class="br-page check-row" :class="{ 'is-empty': p.receiptCount === 0 }">
          <Checkbox
            :model-value="selected.has(p.pageId)"
            :input-id="`br-page-${p.pageId}`"
            :binary="true"
            :disabled="p.receiptCount === 0 || confirming"
            @update:model-value="(v: boolean) => togglePage(p, v)"
          />
          <label :for="`br-page-${p.pageId}`">
            <span class="br-page-name">{{ pageLabel(p) }}</span>
            <span class="br-page-count">
              <template v-if="p.receiptCount > 0">{{ p.receiptCount }} 張</template>
              <template v-else>沒有找到憑證，不扣次</template>
            </span>
          </label>
        </div>
      </fieldset>

      <span v-if="overLimit" class="q-error" role="alert">
        <i class="pi pi-exclamation-circle" aria-hidden="true" />勾選的頁共 {{ selectedCount }} 張，最多要扣 {{ selectedCount }} 次，超過剩餘 {{ remaining }} 次，請減少勾選。
      </span>
      <span v-if="confirmError" id="br-confirm-err" class="q-error" role="alert" tabindex="-1">
        <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ confirmError }}
      </span>
      <p class="dlg-note">確認後才逐張辨識，辨識不出內容的不扣額度，實際扣的次數可能比上面少。完成後帶到{{ formName }}，每筆只附上自己那一頁的憑證，請逐筆核對後再建立。</p>
    </div>

    <template #footer>
      <template v-if="step === 'upload'">
        <Button label="取消" outlined @click="close" />
        <Button
          :label="files.length ? `辨識 ${files.length} 個檔案` : '開始辨識'"
          icon="pi pi-sparkles"
          :disabled="!canRecognize"
          @click="startRecognize"
        />
      </template>
      <template v-else-if="step === 'recognizing'">
        <Button label="取消" outlined @click="close" />
      </template>
      <template v-else>
        <Button label="取消" outlined :disabled="confirming" @click="close" />
        <Button
          :label="`確認並辨識 ${selectedCount} 張`"
          icon="pi pi-check"
          :loading="confirming"
          :disabled="!canConfirm"
          @click="submitConfirm"
        />
      </template>
    </template>
  </Dialog>
</template>

<style scoped>
.br-body { display: flex; flex-direction: column; gap: var(--space-md); }
.br-intro { margin: 0; color: var(--ink); line-height: 1.6; }
.br-intro b { font-weight: 600; }

.br-files { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 6px; }
.br-files li { display: flex; align-items: center; gap: 8px; padding: 4px 4px 4px 12px; border: 1px solid var(--hairline); border-radius: var(--radius-card); }
.br-files li > .pi { color: var(--muted); }
.br-file-name { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--ink); }
.br-file-size { font-size: 14px; color: var(--muted); font-variant-numeric: tabular-nums; }
.br-icon-btn.p-button { width: 44px; height: 44px; flex-shrink: 0; }

.br-progress { align-items: center; text-align: center; padding: var(--space-lg) 0; gap: 8px; }
.br-progress > .pi { font-size: 32px; color: var(--primary-text); }
.br-step-title { margin: 0; font-size: 16px; font-weight: 600; color: var(--ink); }
.br-step-title:focus { outline: none; }
.br-step-title:focus-visible { outline: 2px solid var(--primary-solid); outline-offset: 2px; border-radius: 4px; }
/* 摘要卡標題沿用 dlg-summary 的字重（參考資訊，不搶主要動作） */
.br-summary-title { font-weight: 500; }
.br-progress > span { font-size: 14px; color: var(--muted); }
.br-bar { width: 100%; height: 6px; margin: 8px 0; }
.br-confirming { display: flex; flex-direction: column; gap: 4px; }
.br-confirming:focus { outline: none; }
.br-confirming:focus-visible { outline: 2px solid var(--primary-solid); outline-offset: 2px; border-radius: 4px; }
.br-confirming-text { display: flex; align-items: flex-start; gap: 8px; font-size: 14px; color: var(--slate); line-height: 1.5; }
.br-confirming-text > .pi { margin-top: 3px; color: var(--primary-text); }
.br-confirming .br-bar { margin: 4px 0 0; }

.br-pages { margin: 0; padding: 0; border: 0; display: flex; flex-direction: column; gap: 6px; max-height: 320px; overflow-y: auto; }
.br-pages-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: -8px; }
.br-legend { font-size: 16px; font-weight: 600; color: var(--ink); }
.br-page { min-height: 44px; padding: 6px 12px; border: 1px solid var(--hairline); border-radius: var(--radius-card); }
.br-page label { min-width: 0; display: flex; align-items: center; justify-content: space-between; gap: 8px; cursor: pointer; }
.br-page.is-empty label { cursor: default; }
.br-page-name { min-width: 0; overflow-wrap: anywhere; color: var(--ink); }
.br-page-count { flex-shrink: 0; font-size: 14px; font-variant-numeric: tabular-nums; color: var(--slate); }
.br-page.is-empty .br-page-name,
.br-page.is-empty .br-page-count { color: var(--muted); }

@media (max-width: 639.98px) {
  .br-intro,
  .br-file-name,
  .br-step-title,
  .br-legend,
  .br-page,
  .upload-drop > b { font-size: 14px; }
  .br-page label { flex-direction: column; align-items: flex-start; gap: 2px; }
  .dlg-summary,
  .dlg-summary > strong { font-size: 14px; }
}
</style>
