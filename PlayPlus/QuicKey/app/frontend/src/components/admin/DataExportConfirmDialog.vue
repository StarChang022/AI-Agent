<script setup lang="ts">
/**
 * 匯出確認視窗（PRD 第 24 條）：支出、收入、代墊款全部紀錄列表共用，勾選、全部、單筆（明細、每列選單）都先跳這裡。
 * 寫明這次要匯出哪個列表、幾筆；「全部」另列會套用的篩選條件。按「匯出」才送出，按「取消」不匯出。
 * 頁面把要匯出的內容放進 v-model:pending 就會開啟，關閉時清回 null。
 */
import { computed } from 'vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import { useDataExport, type DataExportConfirm } from '@/composables/useDataExport'

const props = defineProps<{
  /** 列表名稱，用在句子裡：支出／收入／請款 */
  noun: string
}>()
const pending = defineModel<DataExportConfirm | null>('pending', { required: true })

const { exporting, runExport } = useDataExport()

const visible = computed({
  get: () => pending.value !== null,
  set: (v) => {
    if (!v && !exporting.value) pending.value = null
  },
})

const message = computed(() => {
  const p = pending.value
  if (!p) return ''
  if (p.req.scope === 'filtered') return `匯出全部${props.noun}，共 ${p.count} 筆`
  // 勾選與單筆同一句：單筆寫成「匯出選取的 1 筆收入」
  return `匯出選取的 ${p.count} 筆${props.noun}`
})
const filterNote = computed(() => {
  const p = pending.value
  if (!p || p.req.scope !== 'filtered') return ''
  return p.filters?.length
    ? `會套用目前的篩選條件：${p.filters.join('、')}`
    : '目前沒有篩選，會匯出這個列表的全部紀錄'
})

async function confirm() {
  const p = pending.value
  if (!p) return
  if (await runExport(p.req)) pending.value = null
}
</script>

<template>
  <Dialog
    v-model:visible="visible"
    modal
    header="確認匯出"
    :style="{ width: 'min(92vw, 440px)' }"
    :closable="!exporting"
    :close-on-escape="!exporting"
  >
    <p class="export-confirm-msg">{{ message }}</p>
    <p v-if="filterNote" class="export-confirm-note">{{ filterNote }}</p>
    <template #footer>
      <Button label="取消" outlined :disabled="exporting" @click="visible = false" />
      <Button label="匯出" icon="pi pi-download" :loading="exporting" autofocus @click="confirm" />
    </template>
  </Dialog>
</template>

<style scoped>
.export-confirm-msg { margin: 0; font-size: 14px; color: var(--color-ink); }
.export-confirm-note { margin: 8px 0 0; font-size: 13px; color: var(--color-muted); line-height: 1.6; }
</style>
