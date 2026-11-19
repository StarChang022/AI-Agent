/**
 * 表格列焦點框：只在鍵盤操作時顯示。
 * 有些瀏覽器在滑鼠點擊可聚焦的表格列（tabindex）後仍套用 :focus-visible，
 * 綠色框線會一直殘留，看起來像卡住。這裡記錄最後一次輸入方式：
 * 滑鼠／觸控 → <html> 加上 .using-pointer（CSS 隱藏表格列焦點框）；按鍵盤 → 移除。
 * 另外在拖曳結束時清掉 PrimeVue 拖曳排序殘留的落點提示線。
 */
export function installInputModality(): void {
  const root = document.documentElement
  window.addEventListener('pointerdown', () => root.classList.add('using-pointer'), true)
  window.addEventListener(
    'keydown',
    (e) => {
      if (e.key === 'Tab' || e.key?.startsWith('Arrow')) root.classList.remove('using-pointer')
    },
    true,
  )
  const clearDragPoints = () => {
    requestAnimationFrame(() => {
      document
        .querySelectorAll('.p-datatable-dragpoint-top, .p-datatable-dragpoint-bottom')
        .forEach((el) => el.classList.remove('p-datatable-dragpoint-top', 'p-datatable-dragpoint-bottom'))
    })
  }
  window.addEventListener('dragend', clearDragPoints, true)
  window.addEventListener('drop', clearDragPoints, true)
}
