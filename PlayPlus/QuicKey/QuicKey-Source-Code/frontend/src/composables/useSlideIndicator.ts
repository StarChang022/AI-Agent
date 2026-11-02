import { nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref, type WatchSource } from 'vue'

/**
 * 膠囊選項的滑動底色：量出目前選中那顆的位置與寬度，讓一個共用的底色塊滑過去。
 * container 內要有 position: relative；selector 指向「選中的那顆」。
 * 回傳的 style 綁在底色塊上；第一次定位不播動畫，之後切換才滑動。
 */
export function useSlideIndicator(container: Ref<HTMLElement | null>, selector: string, trigger: WatchSource) {
  const style = ref<Record<string, string>>({ opacity: '0' })
  let ready = false
  let ro: ResizeObserver | null = null

  function update() {
    const root = container.value
    const el = root?.querySelector<HTMLElement>(selector)
    if (!root || !el) {
      style.value = { opacity: '0' }
      return
    }
    const r = root.getBoundingClientRect()
    const e = el.getBoundingClientRect()
    style.value = {
      opacity: '1',
      width: `${e.width}px`,
      height: `${e.height}px`,
      transform: `translate(${e.left - r.left - root.clientLeft}px, ${e.top - r.top - root.clientTop}px)`,
      transition: ready ? '' : 'none',
    }
    ready = true
  }

  watch(trigger, () => nextTick(update))
  onMounted(() => {
    nextTick(update)
    // 字型載入、視窗縮放時重新定位
    if (typeof ResizeObserver !== 'undefined' && container.value) {
      ro = new ResizeObserver(() => {
        const was = ready
        ready = false
        update()
        ready = was
      })
      ro.observe(container.value)
    }
  })
  onBeforeUnmount(() => ro?.disconnect())
  return { style, update }
}
