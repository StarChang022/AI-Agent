<script setup lang="ts">
/** 請款單動作對話框：駁回、核准（自動建立支出）、作廢、取消作廢。狀態由 useReimbursementActions 提供。 */
import { computed } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import Textarea from 'primevue/textarea'
import { PAY_MODE_META, type ReimbursementActions } from '@/composables/useReimbursementActions'
import ApproveWithExpenseDialog from '@/components/ApproveWithExpenseDialog.vue'
import ReimbursementSummary from '@/components/admin/ReimbursementSummary.vue'

const props = defineProps<{ ctx: ReimbursementActions }>()
const s = computed(() => props.ctx.state)

const payMeta = computed(() => (s.value.payMode ? PAY_MODE_META[s.value.payMode] : null))
const payNote = computed(() => {
  switch (s.value.payMode) {
    case 'void': return '作廢後不會發放，申請人會收到通知。'
    case 'revert-void': return '恢復為「已核銷」，之後可再發放。'
    default: return ''
  }
})
</script>

<template>
  <Dialog
    :visible="s.rejectTargets.length > 0"
    modal
    :header="s.rejectTargets.length > 1 ? `批次退回 ${s.rejectTargets.length} 筆` : '退回請款'"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="ctx.cancelReject()"
  >
    <div class="flex flex-col gap-4">
      <ReimbursementSummary :targets="s.rejectTargets" />
      <div class="q-field">
        <label for="rj-reason">退回原因 <span class="req">*</span></label>
        <Textarea auto-resize id="rj-reason" v-model="s.rejectComment" rows="3" placeholder="請說明為什麼退回，方便申請人補件" :invalid="!!s.rejectError" autofocus @input="s.rejectError = ''" />
        <span v-if="s.rejectError" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ s.rejectError }}</span>
      </div>
    </div>
    <template #footer>
      <Button label="取消" outlined :disabled="s.submitting" @click="ctx.cancelReject()" />
      <Button label="確認退回" severity="danger" outlined :loading="s.submitting" @click="ctx.submitReject()" />
    </template>
  </Dialog>

  <ApproveWithExpenseDialog
    :visible="s.approveTarget !== null"
    :reimbursement="s.approveTarget"
    :employee-name="ctx.nameOf(s.approveTarget)"
    :submitting="s.submitting"
    @close="ctx.closeApprove()"
    @confirmed="ctx.onApproveConfirmed"
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
