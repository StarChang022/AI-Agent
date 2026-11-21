<script setup lang="ts">
/**
 * 請款單明細抽屜（右側）；開啟時從 API 取全欄位，底部依狀態與權限顯示動作。
 * 請款記錄、審核兩頁共用；「匯出」只匯出這一筆，先跳確認視窗（PRD 第 24 條）。
 */
import { ref, watch } from 'vue'
import Button from 'primevue/button'
import Drawer from 'primevue/drawer'
import { getReimbursement, type Reimbursement } from '@/api/reimbursements'
import type { ReimbursementActions } from '@/composables/useReimbursementActions'
import ReimbursementDetail from '@/components/admin/ReimbursementDetail.vue'
import NoAccountNotice from '@/components/admin/NoAccountNotice.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import DataExportConfirmDialog from '@/components/admin/DataExportConfirmDialog.vue'
import type { DataExportConfirm } from '@/composables/useDataExport'

const props = defineProps<{ ctx: ReimbursementActions }>()
const id = defineModel<string | null>('id', { required: true })

const detail = ref<Reimbursement | null>(null)
const loading = ref(false)

async function fetchDetail(targetId: string) {
  loading.value = true
  detail.value = null
  try {
    detail.value = await getReimbursement(targetId)
  } catch {
    // 失敗時 detail 保持 null；drawer 關閉或外部 refetch 時再試
  } finally {
    loading.value = false
  }
}

watch(
  id,
  (v) => {
    if (v) fetchDetail(v)
    else detail.value = null
  },
  { immediate: true },
)

// 單筆匯出：草稿不在請款列表，不提供
const pendingExport = ref<DataExportConfirm | null>(null)
function exportOne(r: Reimbursement) {
  pendingExport.value = { req: { kind: 'reimbursement', scope: 'single', ids: [r.id] }, count: 1 }
}

defineExpose({
  /** 父頁面在簽核 / 作廢等動作完成後呼叫，確保抽屜內容同步。 */
  refetch: () => {
    if (id.value) fetchDetail(id.value)
  },
})
</script>

<template>
  <Drawer
    :visible="id !== null"
    position="right"
    class="!w-full sm:!w-[560px]"
    @update:visible="(v: boolean) => { if (!v) id = null }"
  >
    <template #header>
      <div class="q-drawer-head">
        <span>請款單</span>
        <StatusBadge v-if="detail" :status="detail.status" />
      </div>
    </template>
    <div v-if="loading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
    <template v-else-if="detail">
      <NoAccountNotice
        v-if="ctx.can.review(detail) && ctx.noAccounts()"
        class="mb-4"
        detail="通過後會建立對應支出，需要指定付款帳戶；公司建立帳戶後才能通過，駁回不受影響。"
      />
      <ReimbursementDetail :reimbursement="detail" />
    </template>
    <template v-if="detail" #footer>
      <div class="q-drawer-foot flex-wrap">
        <!-- 作廢是次要動作：低調文字按鈕放左側（同支出抽屜「移至垃圾桶」）；簽核決定（駁回/通過）集中在右側 -->
        <Button v-if="ctx.can.void(detail)" label="作廢" severity="danger" text @click="ctx.openPay('void', [detail])" />
        <Button v-if="ctx.can.revertVoid(detail)" label="取消作廢" outlined @click="ctx.openPay('revert-void', [detail])" />
        <span class="q-gap" />
        <Button v-if="detail.status !== 'draft'" label="匯出" icon="pi pi-download" outlined @click="exportOne(detail)" />
        <Button v-if="ctx.can.review(detail)" label="駁回" severity="danger" outlined @click="ctx.openReject([detail])" />
        <Button v-if="ctx.can.review(detail)" label="通過" :disabled="ctx.noAccounts()" @click="ctx.openApprove(detail)" />
        <Button v-else label="關閉" outlined @click="id = null" />
      </div>
    </template>
  </Drawer>
  <DataExportConfirmDialog v-model:pending="pendingExport" noun="請款" />
</template>
