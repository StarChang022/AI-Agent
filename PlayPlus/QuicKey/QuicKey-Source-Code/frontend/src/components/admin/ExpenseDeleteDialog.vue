<script setup lang="ts">
/**
 * 支出「移至垃圾桶」與「永久刪除」的確認對話框；列表 ⋯ 選單、詳情抽屜、垃圾桶共用。
 * 來源是代墊款且還能作廢時（見 PRD 規則 12）：
 * - 移至垃圾桶：可勾選同時作廢來源代墊款，勾選時作廢原因必填
 * - 永久刪除：一律同時作廢，不提供不作廢的選項，作廢原因必填
 * 呼叫 API 與提示由這裡處理；成功後 emit done，列表怎麼更新交給頁面。
 */
import { computed, ref, watch } from 'vue'
import { useToast } from 'primevue/usetoast'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import type { Reimbursement, ReimbursementStatus } from '@/types/domain'
import { deleteExpense, purgeExpense, type ExpenseSummary } from '@/api/expenses'
import { getReimbursement } from '@/api/reimbursements'
import { useReviewCount } from '@/composables/useReviewCount'
import { expenseSourceLabel } from '@/constants/expense'
import { formatCurrency } from '@/utils/format'
import { userErrorToast } from '@/utils/userFeedback'

const props = defineProps<{
  target: ExpenseSummary | null
  /** trash：移至垃圾桶；purge：從垃圾桶永久刪除 */
  mode: 'trash' | 'purge'
}>()
const emit = defineEmits<{ close: []; done: [id: string] }>()

const toast = useToast()
const { refresh: refreshReviewCount } = useReviewCount()

// 與後端 Reimbursement::VOIDABLE_STATUSES 一致；已作廢、已發放都不再詢問
const VOIDABLE: ReimbursementStatus[] = ['in_review', 'rejected', 'approved']

const withVoid = ref(false)
const voidComment = ref('')
const voidError = ref('')
const submitting = ref(false)
const linked = ref<Reimbursement | null>(null)

const canVoid = computed(() => {
  const t = props.target
  return !!t && t.source === 'reimbursement' && !!t.sourceReimbursementStatus && VOIDABLE.includes(t.sourceReimbursementStatus)
})

// 永久刪除不能留下沒有支出的已核准代墊款，所以一定連帶作廢
const mustVoid = computed(() => props.mode === 'purge' && canVoid.value)
const showComment = computed(() => mustVoid.value || (canVoid.value && withVoid.value))

const header = computed(() => (props.mode === 'trash' ? '移至垃圾桶' : '永久刪除支出'))
const message = computed(() => {
  const t = props.target
  if (!t) return ''
  const name = `「${t.vendor || (t.source === 'transfer_fee' ? expenseSourceLabel(t) : '未填廠商')}」${formatCurrency(t.amount)}`
  return props.mode === 'trash'
    ? `確定要把${name} 這筆支出移至垃圾桶嗎？之後可在垃圾桶還原。`
    : `確定要永久刪除${name} 這筆支出嗎？刪除後無法還原。`
})
// 讓使用者認得是哪一張請款單；撈不到就只顯示勾選文字
const linkedLabel = computed(() => (linked.value ? `${linked.value.employee.name}・${linked.value.description}` : ''))

watch(
  () => props.target,
  async (t) => {
    withVoid.value = false
    voidComment.value = ''
    voidError.value = ''
    linked.value = null
    if (!t || !canVoid.value || !t.sourceRefId) return
    try {
      const r = await getReimbursement(t.sourceRefId)
      if (props.target?.id === t.id) linked.value = r
    } catch {
      /* 只影響說明文字，不打擾使用者 */
    }
  },
)

function close() {
  if (!submitting.value) emit('close')
}

async function submit() {
  const t = props.target
  if (!t) return
  const voided = showComment.value
  const comment = voidComment.value.trim()
  if (voided && !comment) {
    voidError.value = '請填寫作廢原因'
    return
  }
  const options = voided ? { voidReimbursement: true, voidComment: comment } : undefined
  submitting.value = true
  try {
    if (props.mode === 'trash') await deleteExpense(t.id, options)
    else await purgeExpense(t.id, options)
    toast.add({ severity: 'success', ...successToast(voided), life: 3000 })
    if (voided) void refreshReviewCount()
    emit('done', t.id)
    emit('close')
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, props.mode === 'trash' ? '刪除失敗' : '永久刪除失敗'), life: 3000 })
  } finally {
    submitting.value = false
  }
}

function successToast(voided: boolean): { summary: string; detail?: string } {
  if (props.mode === 'trash') {
    return voided
      ? { summary: '已移至垃圾桶，來源代墊款也已作廢', detail: '要還原請到請款記錄取消作廢，支出會一起還原。' }
      : { summary: '已移至垃圾桶', detail: '可從垃圾桶還原' }
  }
  return { summary: voided ? '已永久刪除，來源代墊款也已作廢' : '已永久刪除' }
}
</script>

<template>
  <Dialog
    :visible="target !== null"
    modal
    :header="header"
    :closable="!submitting"
    :close-on-escape="!submitting"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="close"
  >
    <div class="flex flex-col gap-4">
      <p class="m-0">{{ message }}</p>
      <template v-if="canVoid">
        <p v-if="mustVoid" class="m-0">
          永久刪除會同時作廢來源代墊款
          <span v-if="linkedLabel" class="ed-linked">{{ linkedLabel }}</span>
        </p>
        <div v-else class="ed-check">
          <Checkbox v-model="withVoid" input-id="ed-void" :binary="true" :disabled="submitting" @update:model-value="voidError = ''" />
          <label for="ed-void">
            同時作廢來源代墊款
            <span v-if="linkedLabel" class="ed-linked">{{ linkedLabel }}</span>
          </label>
        </div>
        <div v-if="showComment" class="q-field">
          <label for="ed-void-comment">作廢原因 <span class="req">*</span></label>
          <Textarea
            id="ed-void-comment"
            v-model="voidComment"
            auto-resize
            rows="2"
            placeholder="例如：重複請款、申請人撤回"
            :invalid="!!voidError"
            :aria-invalid="!!voidError"
            :aria-describedby="voidError ? 'ed-void-err' : undefined"
            autofocus
            @input="voidError = ''"
          />
          <span v-if="voidError" id="ed-void-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ voidError }}</span>
          <p v-if="mode === 'trash'" class="dlg-note">之後要還原這筆支出，需先到請款記錄取消作廢。</p>
        </div>
      </template>
    </div>
    <template #footer>
      <!-- 永久刪除預設停在取消；要填作廢原因時焦點留給輸入框 -->
      <Button label="取消" outlined :disabled="submitting" :autofocus="mode === 'purge' && !showComment" @click="close" />
      <Button :label="mode === 'trash' ? '移至垃圾桶' : '永久刪除'" severity="danger" :loading="submitting" @click="submit" />
    </template>
  </Dialog>
</template>

<style scoped>
.ed-check { display: flex; align-items: flex-start; gap: 8px; }
.ed-check label { cursor: pointer; line-height: 1.5; color: var(--ink); }
.ed-linked { display: block; font-size: 14px; color: var(--muted); }

@media (max-width: 639.98px) {
  .ed-check label,
  .q-field > label { font-size: 14px; }
}
</style>
