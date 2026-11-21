<script setup lang="ts">
/**
 * Cloudflare Turnstile 機器人驗證（明確 render 模式）。
 * - 驗證通過時透過 v-model:token 回傳 token；過期、失敗時回傳空字串
 * - token 只能用一次：送出失敗後由父層呼叫 reset() 重新驗證
 * - 預渲染（無頭瀏覽器）時不載入，避免把驗證元件寫進靜態 HTML
 */
import { onBeforeUnmount, onMounted, ref } from 'vue'

interface TurnstileRenderOptions {
  sitekey: string
  language?: string
  theme?: 'light' | 'dark' | 'auto'
  size?: 'normal' | 'flexible' | 'compact'
  'refresh-expired'?: 'auto' | 'manual' | 'never'
  callback?: (token: string) => void
  'expired-callback'?: () => void
  'timeout-callback'?: () => void
  'error-callback'?: (code: string) => boolean | void
}

interface TurnstileApi {
  render: (el: HTMLElement, options: TurnstileRenderOptions) => string
  reset: (widgetId: string) => void
  remove: (widgetId: string) => void
}

declare global {
  interface Window {
    turnstile?: TurnstileApi
  }
}

const SCRIPT_SRC = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
let scriptPromise: Promise<TurnstileApi> | null = null

// 注意：頁面上若有 id="turnstile" 的元素，瀏覽器也會把它放在 window.turnstile，所以要檢查 render 是不是函式
function readyApi(): TurnstileApi | null {
  return typeof window.turnstile?.render === 'function' ? window.turnstile : null
}

function loadTurnstile(): Promise<TurnstileApi> {
  const ready = readyApi()
  if (ready) return Promise.resolve(ready)
  if (scriptPromise) return scriptPromise
  scriptPromise = new Promise<TurnstileApi>((resolve, reject) => {
    const script = document.createElement('script')
    script.src = SCRIPT_SRC
    script.async = true
    script.onload = () => {
      const api = readyApi()
      if (api) resolve(api)
      else reject(new Error('turnstile 未初始化'))
    }
    script.onerror = () => {
      scriptPromise = null
      script.remove()
      reject(new Error('turnstile 載入失敗'))
    }
    document.head.appendChild(script)
  })
  return scriptPromise
}

const props = defineProps<{
  /** 外層容器 id，驗證未完成時可以把 focus 移到這裡 */
  id: string
  siteKey: string
}>()

const token = defineModel<string>('token', { default: '' })

const container = ref<HTMLElement>()
const loadFailed = ref(false)
let api: TurnstileApi | null = null
let widgetId: string | null = null
let unmounted = false

function reset() {
  token.value = ''
  if (api && widgetId) api.reset(widgetId)
}

onMounted(async () => {
  if (navigator.webdriver) return
  if (!props.siteKey) {
    console.warn('未設定 VITE_TURNSTILE_SITE_KEY，機器人驗證無法顯示')
    loadFailed.value = true
    return
  }
  try {
    api = await loadTurnstile()
  } catch {
    loadFailed.value = true
    return
  }
  if (unmounted || !container.value) return
  try {
    widgetId = api.render(container.value, {
      sitekey: props.siteKey,
      language: 'zh-tw',
      theme: 'light',
      size: 'flexible',
      'refresh-expired': 'never',
      callback: (t) => {
        token.value = t
      },
      'expired-callback': reset,
      'timeout-callback': reset,
      'error-callback': () => {
        token.value = ''
      },
    })
  } catch {
    loadFailed.value = true
  }
})

onBeforeUnmount(() => {
  unmounted = true
  if (api && widgetId) api.remove(widgetId)
  widgetId = null
})

defineExpose({ reset })
</script>

<template>
  <div :id="id" class="turnstile" tabindex="-1">
    <div ref="container" />
    <p v-if="loadFailed" class="turnstile-failed">
      機器人驗證載入失敗，請重新整理頁面再試一次。
    </p>
  </div>
</template>

<style scoped>
.turnstile {
  min-height: 65px;
}
.turnstile:focus {
  outline: none;
}
.turnstile:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 4px;
  border-radius: 8px;
}
.turnstile-failed {
  margin: 0;
  font-size: 14px;
  color: var(--color-slate);
}
</style>
