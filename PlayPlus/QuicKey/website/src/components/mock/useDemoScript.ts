import { onBeforeUnmount, onMounted, ref, type Ref } from 'vue'

/**
 * 服務區塊示意畫面的自動示範腳本
 * - 進入視窗時，假游標依序移到 data-demo 元素並「點擊」，觸發示意畫面的狀態變化
 * - 離開視窗即停止；使用者自行點擊後永久停止自動示範，改由使用者操作
 * - 減少動態效果時不自動播放，維持初始狀態，仍可手動操作
 */

export interface DemoStep {
  /** data-demo 屬性值；有值時游標會先移過去並點擊 */
  target?: string
  /** 點擊後執行的狀態變化 */
  run?: () => void
  /** 此步驟結束後等待的毫秒數 */
  wait?: number
}

export interface DemoCursor {
  x: number
  y: number
  visible: boolean
  pressed: boolean
}

interface DemoOptions {
  root: Ref<HTMLElement | null>
  steps: DemoStep[]
  reset: () => void
}

const HIDDEN_CURSOR: DemoCursor = { x: 0, y: 0, visible: false, pressed: false }

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

export function useDemoScript({ root, steps, reset }: DemoOptions) {
  const cursor = ref<DemoCursor>({ ...HIDDEN_CURSOR })
  /** 示意畫面是否在視窗內（供進度條等微動畫使用） */
  const inView = ref(false)

  let token = 0
  let running = false
  let interacted = false
  let observer: IntersectionObserver | undefined
  const pending = new Set<{ timer: number; resolve: (ok: boolean) => void }>()

  function wait(ms: number, t: number): Promise<boolean> {
    return new Promise((resolve) => {
      const entry = { timer: 0, resolve }
      entry.timer = window.setTimeout(() => {
        pending.delete(entry)
        resolve(t === token)
      }, ms)
      pending.add(entry)
    })
  }

  function cancelAll() {
    for (const entry of pending) {
      window.clearTimeout(entry.timer)
      entry.resolve(false)
    }
    pending.clear()
  }

  function pointOf(target: string): { x: number; y: number } | null {
    const host = root.value
    const el = host?.querySelector<HTMLElement>(`[data-demo="${target}"]`)
    if (!host || !el) return null
    const a = el.getBoundingClientRect()
    const b = host.getBoundingClientRect()
    return { x: a.left - b.left + a.width / 2, y: a.top - b.top + a.height / 2 }
  }

  async function loop(t: number) {
    while (t === token) {
      reset()
      if (!(await wait(500, t))) return
      for (const step of steps) {
        if (step.target) {
          const p = pointOf(step.target)
          if (p) {
            cursor.value = { x: p.x, y: p.y, visible: true, pressed: false }
            if (!(await wait(700, t))) return
            cursor.value = { ...cursor.value, pressed: true }
            if (!(await wait(140, t))) return
            cursor.value = { ...cursor.value, pressed: false }
          }
        }
        step.run?.()
        if (!(await wait(step.wait ?? 600, t))) return
      }
      cursor.value = { ...cursor.value, visible: false }
      if (!(await wait(2400, t))) return
    }
  }

  function start() {
    if (running || interacted || prefersReducedMotion()) return
    running = true
    const t = ++token
    void loop(t)
  }

  function stop() {
    if (!running) return
    running = false
    token++
    cancelAll()
    cursor.value = { ...HIDDEN_CURSOR }
    reset()
  }

  function onUserPointerDown() {
    interacted = true
    stop()
  }

  onMounted(() => {
    const host = root.value
    if (!host) return
    if (prefersReducedMotion()) {
      inView.value = true
      return
    }
    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          inView.value = entry.isIntersecting
          if (entry.isIntersecting) start()
          else stop()
        }
      },
      { threshold: 0.5 },
    )
    observer.observe(host)
    host.addEventListener('pointerdown', onUserPointerDown, true)
  })

  onBeforeUnmount(() => {
    observer?.disconnect()
    cancelAll()
    running = false
    token++
    root.value?.removeEventListener('pointerdown', onUserPointerDown, true)
  })

  return { cursor, inView }
}
