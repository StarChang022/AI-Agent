<script setup lang="ts">
/**
 * 頁首「匯出」下拉選單（PRD 第 24 條）：支出、收入、代墊款全部紀錄列表共用。
 * 兩個選項，選了交給頁面開確認視窗（DataExportConfirmDialog）：
 * - 已選項目（N 筆）：沒有勾選時不可選
 * - 全部支出／全部收入／全部請款：依目前分頁標籤與篩選，列表 0 筆時不可選
 */
import { computed, ref, useId, useTemplateRef } from 'vue'
import Button from 'primevue/button'
import Menu from 'primevue/menu'
import type { MenuItem } from 'primevue/menuitem'

const props = defineProps<{
  /** 例：「全部支出」 */
  allLabel: string
  selectedCount: number
  /** 列表目前符合條件的筆數 */
  total: number
}>()
const emit = defineEmits<{ export: [scope: 'selected' | 'filtered'] }>()

const menuId = useId()
const menu = useTemplateRef<InstanceType<typeof Menu>>('menu')
const open = ref(false)

const items = computed<MenuItem[]>(() => [
  {
    label: `已選項目（${props.selectedCount} 筆）`,
    disabled: !props.selectedCount,
    command: () => emit('export', 'selected'),
  },
  {
    label: props.allLabel,
    disabled: !props.total,
    command: () => emit('export', 'filtered'),
  },
])
</script>

<template>
  <Button outlined aria-haspopup="menu" :aria-expanded="open" :aria-controls="menuId" @click="menu?.toggle($event)">
    <i class="pi pi-download" aria-hidden="true" />
    <span>匯出</span>
    <i class="pi pi-chevron-down export-chev" aria-hidden="true" />
  </Button>
  <Menu :id="menuId" ref="menu" :model="items" popup @show="open = true" @hide="open = false" />
</template>

<style scoped>
.export-chev { font-size: 11px; }
</style>
