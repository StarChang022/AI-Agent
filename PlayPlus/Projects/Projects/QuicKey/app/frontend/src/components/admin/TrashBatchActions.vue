<script setup lang="ts">
/**
 * 支出、收入垃圾桶的批次還原與永久刪除（PRD 第 18 條「批次還原與永久刪除」）。
 * 包含批次操作列、還原與永久刪除共用的確認視窗、有失敗時的結果視窗；呼叫 API 與提示在這裡處理，
 * 完成後 emit done，重新載入與換頁交給頁面。勾選狀態由頁面用 usePageSelection 管理。
 */
import { computed, ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import SelectionBar from '@/components/qds/SelectionBar.vue'
import {
  batchPurgeExpenses,
  batchRestoreExpenses,
  type BatchActionResult,
  type ExpenseSummary,
} from '@/api/expenses'
import { batchPurgeIncomes, batchRestoreIncomes, type Income } from '@/api/incomes'
import { useReviewCount } from '@/composables/useReviewCount'
import { canVoidSourceReimbursement } from '@/constants/expense'
import { formatCurrency, formatDate } from '@/utils/format'
import { batchFailureReason, userErrorToast } from '@/utils/userFeedback'

type Row = ExpenseSummary | Income

const props = defineProps<{
  kind: 'expense' | 'income'
  /** 本頁已勾選的紀錄 */
  rows: Row[]
}>()
const emit = defineEmits<{ clear: []; done: [succeeded: string[]] }>()

const toast = useToast()
const { refresh: refreshReviewCount } = useReviewCount()

const noun = computed(() => (props.kind === 'expense' ? '支出' : '收入'))
const submitting = ref<'restore' | 'purge' | null>(null)

/** 失敗清單用：讓使用者認得是哪一筆 */
function describe(row: Row): string {
  const name =
    props.kind === 'expense'
      ? (row as ExpenseSummary).vendor || ((row as ExpenseSummary).source === 'transfer_fee' ? '移轉手續費' : '未填廠商')
      : (row as Income).customer || '未填客戶'
  return `${name}・${formatCurrency(row.amount)}・${formatDate(row.date)}`
}

/** 永久刪除時會一起作廢來源代墊款的紀錄（只有支出；不可永久刪除的不算） */
function voidable(rows: Row[]): Row[] {
  if (props.kind !== 'expense') return []
  return (rows as ExpenseSummary[]).filter((r) => r.purgeable && canVoidSourceReimbursement(r))
}

// ─── 結果 ─────────────────────────────────────────
interface FailedItem {
  id: string
  label: string
  reason: string
}
const result = ref<{ action: 'restore' | 'purge'; succeeded: number; failed: FailedItem[] } | null>(null)

function report(action: 'restore' | 'purge', snapshot: Row[], res: BatchActionResult) {
  const byId = new Map(snapshot.map((r) => [r.id, r]))
  const verb = action === 'restore' ? '還原' : '永久刪除'
  if (action === 'purge' && voidable(snapshot.filter((r) => res.succeeded.includes(r.id))).length) {
    void refreshReviewCount()
  }
  if (!res.failed.length) {
    const voided = action === 'purge' ? voidable(snapshot.filter((r) => res.succeeded.includes(r.id))).length : 0
    toast.add({
      severity: 'success',
      summary: `已${verb} ${res.succeeded.length} 筆${noun.value}`,
      detail: voided ? `其中 ${voided} 筆的來源代墊款已同時作廢` : undefined,
      life: 3000,
    })
    return
  }
  result.value = {
    action,
    succeeded: res.succeeded.length,
    failed: res.failed.map((f) => {
      const row = byId.get(f.id)
      return { id: f.id, label: row ? describe(row) : `${noun.value}（已不在本頁）`, reason: batchFailureReason(f) }
    }),
  }
}

async function run(action: 'restore' | 'purge', snapshot: Row[], comment?: string) {
  const ids = snapshot.map((r) => r.id)
  if (!ids.length || submitting.value) return
  submitting.value = action
  try {
    let res: BatchActionResult
    if (props.kind === 'expense') {
      res = action === 'restore' ? await batchRestoreExpenses(ids) : await batchPurgeExpenses(ids, comment)
    } else {
      res = action === 'restore' ? await batchRestoreIncomes(ids) : await batchPurgeIncomes(ids)
    }
    pending.value = null
    report(action, snapshot, res)
    emit('done', res.succeeded)
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, action === 'restore' ? '還原失敗' : '永久刪除失敗'), life: 3500 })
  } finally {
    submitting.value = null
  }
}

// ─── 確認視窗（還原、永久刪除共用） ───────────────
// 開視窗時固定要處理的紀錄與筆數，處理中換頁也不影響視窗內容
const pending = ref<{ action: 'restore' | 'purge'; rows: Row[]; voidCount: number } | null>(null)
const voidComment = ref('')
const voidError = ref('')

const confirmText = computed(() => {
  const p = pending.value
  if (!p) return { header: '', message: '', button: '' }
  const n = `${p.rows.length} 筆${noun.value}`
  return p.action === 'restore'
    ? { header: `還原 ${n}`, message: `確定要還原選取的 ${n}嗎？`, button: '還原' }
    : { header: `永久刪除 ${n}`, message: `確定要永久刪除選取的 ${n}嗎？刪除後無法還原。`, button: '永久刪除' }
})

function openConfirm(action: 'restore' | 'purge') {
  const rows = [...props.rows]
  if (!rows.length || submitting.value) return
  voidComment.value = ''
  voidError.value = ''
  pending.value = { action, rows, voidCount: action === 'purge' ? voidable(rows).length : 0 }
}
/** 取消、Esc、關閉：不處理，選取保留 */
function closeConfirm() {
  if (!submitting.value) pending.value = null
}
function submitConfirm() {
  const p = pending.value
  if (!p) return
  if (p.action === 'restore') {
    void run('restore', p.rows)
    return
  }
  const comment = voidComment.value.trim()
  if (p.voidCount && !comment) {
    voidError.value = '請填寫作廢原因'
    return
  }
  void run('purge', p.rows, p.voidCount ? comment : undefined)
}
</script>

<template>
  <SelectionBar v-if="rows.length" class="list-selection" :count="rows.length" :label="`已選取本頁 ${rows.length} 筆`" @clear="emit('clear')">
    <Button label="還原" icon="pi pi-undo" size="small" outlined :disabled="!!submitting" @click="openConfirm('restore')" />
    <Button label="永久刪除" icon="pi pi-trash" size="small" severity="danger" :disabled="!!submitting" @click="openConfirm('purge')" />
  </SelectionBar>

  <Dialog
    :visible="pending !== null"
    modal
    :header="confirmText.header"
    :closable="!submitting"
    :close-on-escape="!submitting"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="(v: boolean) => !v && closeConfirm()"
  >
    <div class="flex flex-col gap-4">
      <p class="m-0">{{ confirmText.message }}</p>
      <div v-if="pending?.voidCount" class="q-field">
        <p class="m-0 tb-void-hint">其中 {{ pending.voidCount }} 筆的來源代墊款會同時作廢，共用以下作廢原因。</p>
        <label for="tb-void-comment">作廢原因 <span class="req">*</span></label>
        <Textarea
          id="tb-void-comment"
          v-model="voidComment"
          auto-resize
          rows="2"
          placeholder="例如：重複請款、申請人撤回"
          :disabled="!!submitting"
          :invalid="!!voidError"
          :aria-invalid="!!voidError"
          :aria-describedby="voidError ? 'tb-void-err' : undefined"
          autofocus
          @input="voidError = ''"
        />
        <span v-if="voidError" id="tb-void-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ voidError }}</span>
      </div>
    </div>
    <template #footer>
      <!-- 預設停在取消；要填作廢原因時焦點留給輸入框 -->
      <Button label="取消" outlined :disabled="!!submitting" :autofocus="!pending?.voidCount" @click="closeConfirm" />
      <Button
        :label="confirmText.button"
        :severity="pending?.action === 'purge' ? 'danger' : undefined"
        :loading="!!submitting"
        :disabled="!!submitting"
        @click="submitConfirm"
      />
    </template>
  </Dialog>

  <Dialog
    :visible="result !== null"
    modal
    :header="result?.action === 'restore' ? '還原結果' : '永久刪除結果'"
    :style="{ width: 'min(92vw, 480px)' }"
    @update:visible="(v: boolean) => !v && (result = null)"
  >
    <template v-if="result">
      <p class="m-0">
        成功 {{ result.succeeded }} 筆、失敗 {{ result.failed.length }} 筆，失敗的{{ noun }}仍留在垃圾桶。
      </p>
      <ul class="tb-failed" aria-label="失敗項目">
        <li v-for="f in result.failed" :key="f.id">
          <span class="tb-failed-label">{{ f.label }}</span>
          <span class="tb-failed-reason">{{ f.reason }}</span>
        </li>
      </ul>
    </template>
    <template #footer>
      <Button label="知道了" autofocus @click="result = null" />
    </template>
  </Dialog>
</template>

<style scoped>
.tb-void-hint { color: var(--ink); }
.tb-failed {
  list-style: none;
  margin: var(--space-md) 0 0;
  padding: 0;
  max-height: 50vh;
  overflow-y: auto;
  border-top: 1px solid var(--hairline);
}
.tb-failed li {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 10px 0;
  border-bottom: 1px solid var(--hairline);
}
.tb-failed-label { font-weight: 600; color: var(--ink); font-variant-numeric: tabular-nums; }
.tb-failed-reason { font-size: 14px; color: var(--danger-text); }

@media (max-width: 639.98px) {
  .tb-failed-label,
  .q-field > label { font-size: 14px; }
}
</style>
