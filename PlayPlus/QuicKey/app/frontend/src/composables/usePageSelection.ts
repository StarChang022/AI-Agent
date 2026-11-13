import { computed, ref, watch, type Ref, type WatchSource } from 'vue'

/**
 * 列表「只選本頁」的勾選狀態（PRD 第 18 條垃圾桶批次操作）：表頭勾選框是本頁全選，
 * resetOn 任一項變動（換頁、每頁筆數、篩選、關鍵字）就清空選取。
 * 本頁重新載入後，已不在本頁的紀錄自動移出選取。
 */
export function usePageSelection<T extends { id: string }>(pageRows: Ref<T[]>, resetOn: WatchSource[]) {
  const selectedIds = ref<Set<string>>(new Set())

  const selectedRows = computed(() => pageRows.value.filter((r) => selectedIds.value.has(r.id)))
  const count = computed(() => selectedRows.value.length)
  const allSelected = computed(() => pageRows.value.length > 0 && count.value === pageRows.value.length)
  const partiallySelected = computed(() => count.value > 0 && !allSelected.value)

  function isSelected(row: T): boolean {
    return selectedIds.value.has(row.id)
  }
  function toggle(row: T, checked: boolean) {
    const next = new Set(selectedIds.value)
    if (checked) next.add(row.id)
    else next.delete(row.id)
    selectedIds.value = next
  }
  function toggleAll(checked: boolean) {
    selectedIds.value = checked ? new Set(pageRows.value.map((r) => r.id)) : new Set()
  }
  function clear() {
    selectedIds.value = new Set()
  }

  watch(resetOn, clear)
  watch(pageRows, (rows) => {
    if (!selectedIds.value.size) return
    const ids = new Set(rows.map((r) => r.id))
    selectedIds.value = new Set([...selectedIds.value].filter((id) => ids.has(id)))
  })

  return { selectedRows, count, allSelected, partiallySelected, isSelected, toggle, toggleAll, clear }
}
