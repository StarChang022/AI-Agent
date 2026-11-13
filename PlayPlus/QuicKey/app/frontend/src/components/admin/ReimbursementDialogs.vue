<script setup lang="ts">
/** 請款單動作對話框：駁回、核准（自動建立支出）、作廢、取消作廢。狀態由 useReimbursementActions 提供。 */
import { computed, nextTick } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import { PAY_MODE_META, type ReimbursementActions } from '@/composables/useReimbursementActions'
import ApproveWithExpenseDialog from '@/components/ApproveWithExpenseDialog.vue'
import BatchApproveDialog from '@/components/admin/BatchApproveDialog.vue'
import ReimbursementSummary from '@/components/admin/ReimbursementSummary.vue'
import { formatCurrency, reimbursementLabel } from '@/utils/format'

const props = defineProps<{ ctx: ReimbursementActions }>()
const s = computed(() => props.ctx.state)

// ─── 駁回：每筆各自一個原因欄（單筆時只有一欄，外觀同以往）───
const rejectInputId = (id: string) => `rj-reason-${id}`
const rejectErrId = (id: string) => `rj-err-${id}`
function onRejectInput(id: string) {
  s.value.rejectErrors[id] = ''
}
async function confirmReject() {
  await props.ctx.submitReject()
  // 未填或送出失敗的筆數會帶錯誤訊息：捲到並聚焦第一筆
  const first = s.value.rejectTargets.find((t) => s.value.rejectErrors[t.id])
  if (!first) return
  await nextTick()
  document.getElementById(rejectInputId(first.id))?.focus()
}

const payMeta = computed(() => (s.value.payMode ? PAY_MODE_META[s.value.payMode] : null))
const payNote = computed(() => {
  switch (s.value.payMode) {
    case 'void':
      return s.value.payTargets.some((t) => t.status === 'approved')
        ? '作廢後不會發放。已核准的單會一併把對應支出移至垃圾桶。'
        : '作廢後不會發放。'
    case 'revert-void': return '恢復為作廢前的狀態；若原本已核准，對應支出會從垃圾桶一併還原。'
    default: return ''
  }
})
</script>

<template>
  <Dialog
    :visible="s.rejectTargets.length > 0"
    modal
    :header="s.rejectTargets.length > 1 ? `批次駁回 ${s.rejectTargets.length} 筆` : '駁回請款'"
    :style="{ width: s.rejectTargets.length > 1 ? 'min(92vw, 560px)' : 'min(92vw, 440px)' }"
    @update:visible="ctx.cancelReject()"
  >
    <div class="flex flex-col gap-4">
      <ReimbursementSummary :targets="s.rejectTargets" />
      <!-- 單筆 -->
      <div v-if="s.rejectTargets.length === 1" class="q-field">
        <label :for="rejectInputId(s.rejectTargets[0].id)">駁回原因 <span class="req">*</span></label>
        <Textarea
          :id="rejectInputId(s.rejectTargets[0].id)"
          v-model="s.rejectComments[s.rejectTargets[0].id]"
          auto-resize
          rows="3"
          placeholder="請說明為什麼駁回，方便申請人補件"
          :invalid="!!s.rejectErrors[s.rejectTargets[0].id]"
          :aria-describedby="s.rejectErrors[s.rejectTargets[0].id] ? rejectErrId(s.rejectTargets[0].id) : undefined"
          autofocus
          @input="onRejectInput(s.rejectTargets[0].id)"
        />
        <span v-if="s.rejectErrors[s.rejectTargets[0].id]" :id="rejectErrId(s.rejectTargets[0].id)" class="q-error">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ s.rejectErrors[s.rejectTargets[0].id] }}
        </span>
      </div>
      <!-- 多筆：逐筆列出，各自填原因 -->
      <ul v-else-if="s.rejectTargets.length > 1" class="rj-list">
        <li v-for="(t, i) in s.rejectTargets" :key="t.id" class="rj-row">
          <div :id="`rj-row-${t.id}`" class="rj-info">
            <b>{{ t.employee.name }}</b>
            <span class="rj-desc" :title="reimbursementLabel(t.description, t.category?.name)">{{ reimbursementLabel(t.description, t.category?.name) || '—' }}</span>
            <span class="rj-amount">{{ formatCurrency(t.amount) }}</span>
          </div>
          <div class="q-field">
            <label :id="`rj-label-${t.id}`" :for="rejectInputId(t.id)">駁回原因 <span class="req">*</span></label>
            <Textarea
              :id="rejectInputId(t.id)"
              v-model="s.rejectComments[t.id]"
              auto-resize
              rows="2"
              placeholder="請說明為什麼駁回，方便申請人補件"
              :invalid="!!s.rejectErrors[t.id]"
              :aria-labelledby="`rj-label-${t.id} rj-row-${t.id}`"
              :aria-describedby="s.rejectErrors[t.id] ? rejectErrId(t.id) : undefined"
              :autofocus="i === 0"
              @input="onRejectInput(t.id)"
            />
            <span v-if="s.rejectErrors[t.id]" :id="rejectErrId(t.id)" class="q-error">
              <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ s.rejectErrors[t.id] }}
            </span>
          </div>
        </li>
      </ul>
    </div>
    <template #footer>
      <Button label="取消" outlined :disabled="s.submitting" @click="ctx.cancelReject()" />
      <Button
        :label="s.rejectTargets.length > 1 ? `駁回 ${s.rejectTargets.length} 筆` : '確認駁回'"
        severity="danger"
        outlined
        :loading="s.submitting"
        @click="confirmReject"
      />
    </template>
  </Dialog>

  <ApproveWithExpenseDialog
    :visible="s.approveTarget !== null"
    :reimbursement="s.approveTarget"
    :employee-name="ctx.nameOf(s.approveTarget)"
    :submitting="s.submitting"
    :stale-account-ids="s.staleAccountIds"
    :accounts="ctx.accounts"
    @close="ctx.closeApprove()"
    @confirmed="ctx.onApproveConfirmed"
  />

  <BatchApproveDialog
    :targets="s.batchApproveTargets"
    :submitting="s.submitting"
    :stale-account-ids="s.staleAccountIds"
    :accounts="ctx.accounts"
    @close="ctx.closeBatchApprove()"
    @confirmed="ctx.onBatchApproveConfirmed"
  />

  <Dialog
    :visible="s.payMode !== null"
    modal
    :header="(payMeta?.header ?? '') + (s.payTargets.length > 1 ? ` ${s.payTargets.length} 筆` : '')"
    :style="{ width: 'min(92vw, 480px)' }"
    @update:visible="ctx.cancelPay()"
  >
    <div class="flex flex-col gap-4">
      <ReimbursementSummary :targets="s.payTargets" />
      <p class="dlg-note">{{ payNote }}</p>
      <div v-if="s.payMode === 'void'" class="q-field">
        <label for="pa-comment">作廢原因 <span class="req">*</span></label>
        <Textarea auto-resize id="pa-comment" v-model="s.payComment" rows="2" placeholder="例如：申請人反悔、重複請款" :invalid="!!s.payError" autofocus @input="s.payError = ''" />
        <span v-if="s.payError" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ s.payError }}</span>
      </div>
    </div>
    <template #footer>
      <Button label="取消" outlined :disabled="s.submitting" @click="ctx.cancelPay()" />
      <Button :label="payMeta?.confirm ?? ''" :severity="payMeta?.severity" :outlined="payMeta?.severity === 'danger'" :loading="s.submitting" @click="ctx.submitPay()" />
    </template>
  </Dialog>
</template>

<style scoped>
.rj-list { display: flex; flex-direction: column; list-style: none; margin: 0; padding: 0; }
.rj-row { display: flex; flex-direction: column; gap: 8px; padding: 12px 0; border-top: 1px solid var(--color-hairline); }
.rj-info { display: flex; align-items: baseline; gap: 8px; min-width: 0; font-size: 14px; }
.rj-info > b { flex-shrink: 0; font-weight: 500; }
.rj-desc { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--muted); }
.rj-amount { flex-shrink: 0; font-variant-numeric: tabular-nums; }
</style>
