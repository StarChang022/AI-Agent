import type { Directive } from 'vue'

/**
 * Scroll Reveal 共用指令（v-reveal）
 *
 * 用法
 *   v-reveal="'up'"                        單一元素，Fade Up
 *   v-reveal="{ type: 'soft', delay: 120 }" 指定類型與延遲（毫秒）
 *   v-reveal="{ type: 'up', delay: staggerDelay(i) }"  列表 Stagger
 *
 * 類型（動畫數值統一定義在 styles/motion.css 的 :root tokens）
 *   up     Fade Up，主要標題、重要說明
 *   soft   Soft Fade，一般說明文字、表單容器、次要資訊
 *   image  Image Reveal，產品畫面、插圖（較長時長、較小位移）
 *
 * 行為規則
 *   - 只在 JS 執行後才寫入 data-reveal；JS 未執行時內容本來就可見，不會卡透明。
 *   - 元素進入視窗（底部留 8% 緩衝）後加上 .is-revealed，播放一次後即停止觀察，
 *     往返捲動不重播。
 *   - prefers-reduced-motion 或瀏覽器不支援 IntersectionObserver 時，直接顯示、不播放動畫。
 */

export type RevealType = 'up' | 'soft' | 'image'

export interface RevealOptions {
  type?: RevealType
  /** 進場延遲（ms），上限 STAGGER_MAX */
  delay?: number
}

/** Stagger 每一項的間隔與總延遲上限（ms） */
export const STAGGER_STEP = 100
export const STAGGER_MAX = 400

/** 依列表索引計算 Stagger 延遲，超過上限後不再增加，避免長列表等待過久 */
export function staggerDelay(index: number): number {
  return Math.min(index * STAGGER_STEP, STAGGER_MAX)
}

const REVEAL_TYPES: readonly RevealType[] = ['up', 'soft', 'image']

function resolve(value: unknown): Required<RevealOptions> {
  const opts: RevealOptions =
    typeof value === 'string' ? { type: value as RevealType } : ((value as RevealOptions | undefined) ?? {})
  const type = opts.type && REVEAL_TYPES.includes(opts.type) ? opts.type : 'up'
  const delay = Math.max(0, Math.min(opts.delay ?? 0, STAGGER_MAX))
  return { type, delay }
}

const canObserve = typeof window !== 'undefined' && 'IntersectionObserver' in window

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

// 全站共用一個 observer，避免每個元素各自建立
let observer: IntersectionObserver | null = null

function getObserver(): IntersectionObserver {
  if (!observer) {
    observer = new IntersectionObserver(
      (entries, obs) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.classList.add('is-revealed')
          // 只播放一次
          obs.unobserve(entry.target)
        }
      },
      { threshold: 0, rootMargin: '0px 0px -8% 0px' },
    )
  }
  return observer
}

export const vReveal: Directive<HTMLElement, RevealOptions | RevealType | undefined> = {
  // 在元素插入 DOM 前設定狀態，避免先閃出內容再進場
  beforeMount(el, binding) {
    const { type, delay } = resolve(binding.value)
    el.setAttribute('data-reveal', type)
    el.style.setProperty('--reveal-delay', `${delay}ms`)
    if (!canObserve || prefersReducedMotion()) {
      el.classList.add('is-revealed')
    }
  },
  mounted(el) {
    if (!el.classList.contains('is-revealed')) {
      getObserver().observe(el)
    }
  },
  unmounted(el) {
    observer?.unobserve(el)
  },
}
