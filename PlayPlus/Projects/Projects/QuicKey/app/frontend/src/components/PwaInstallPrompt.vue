<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref, shallowRef } from 'vue'

const DISMISS_KEY = 'quickey.pwa-prompt.dismissed-at'
const DISMISS_DAYS = 7
const SHOW_DELAY_MS = 1500

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

const ua = navigator.userAgent
const isIOS = /iPad|iPhone|iPod/.test(ua)
const isInAppBrowser = /Line|FBAN|FBAV|Instagram|MicroMessenger/i.test(ua)
const isIOSSafari =
  isIOS &&
  !isInAppBrowser &&
  /Safari/.test(ua) &&
  !/CriOS|FxiOS|EdgiOS/.test(ua)

const isStandalone =
  window.matchMedia('(display-mode: standalone)').matches ||
  (window.navigator as unknown as { standalone?: boolean }).standalone === true

const dismissed = ref(false)
const ready = ref(false)
const installEvent = shallowRef<BeforeInstallPromptEvent | null>(null)

const canInstall = computed(() => {
  if (!ready.value || dismissed.value || isStandalone) return false
  if (isIOSSafari) return true
  if (installEvent.value) return true
  return false
})

function handleBeforeInstallPrompt(e: Event) {
  e.preventDefault()
  installEvent.value = e as BeforeInstallPromptEvent
}

function handleAppInstalled() {
  installEvent.value = null
  dismissed.value = true
}

async function triggerInstall() {
  const evt = installEvent.value
  if (!evt) return
  await evt.prompt()
  const { outcome } = await evt.userChoice
  if (outcome === 'accepted') {
    installEvent.value = null
  } else {
    dismiss()
  }
}

function dismiss() {
  dismissed.value = true
  try {
    localStorage.setItem(DISMISS_KEY, new Date().toISOString())
  } catch {
    // Storage 不可用（無痕模式等）就算了，關掉一次也沒差
  }
}

let showTimer: number | undefined

onMounted(() => {
  try {
    const at = localStorage.getItem(DISMISS_KEY)
    if (at) {
      const ms = Date.now() - new Date(at).getTime()
      if (ms < DISMISS_DAYS * 24 * 60 * 60 * 1000) {
        dismissed.value = true
      }
    }
  } catch {
    // 讀不到就當沒關過
  }

  window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
  window.addEventListener('appinstalled', handleAppInstalled)

  showTimer = window.setTimeout(() => {
    ready.value = true
  }, SHOW_DELAY_MS)
})

onBeforeUnmount(() => {
  window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
  window.removeEventListener('appinstalled', handleAppInstalled)
  if (showTimer !== undefined) window.clearTimeout(showTimer)
})
</script>

<template>
  <Transition name="pwa-prompt">
    <div
      v-if="canInstall"
      class="fixed left-4 right-4 bottom-24 lg:left-auto lg:right-6 lg:bottom-6 lg:max-w-sm z-30 mx-auto max-w-md"
      role="dialog"
      aria-labelledby="pwa-prompt-title"
    >
      <div
        class="card p-4 shadow-lg flex gap-3 items-start"
      >
        <div
          class="flex-shrink-0 w-10 h-10 rounded-xl bg-primary-50 flex items-center justify-center"
          aria-hidden="true"
        >
          <i class="pi pi-mobile text-primary-700 text-lg" />
        </div>

        <div class="flex-1 min-w-0">
          <p
            id="pwa-prompt-title"
            class="font-medium text-sm text-[var(--color-text)] mb-0.5"
          >
            加到主畫面
          </p>
          <p class="text-xs text-[var(--color-muted)] leading-snug">
            <template v-if="isIOSSafari">
              點下方
              <i class="pi pi-upload text-[11px] mx-0.5" aria-label="分享" />
              分享按鈕 →「加入主畫面」，登入不會被系統清空。
            </template>
            <template v-else>
              安裝 Quickey 到手機，開啟更快、登入更穩。
            </template>
          </p>
          <div v-if="!isIOSSafari && installEvent" class="mt-2">
            <button
              type="button"
              class="inline-flex items-center gap-1.5 px-3 py-1 bg-primary-700 text-white text-xs font-medium rounded-full hover:bg-primary-800 transition-colors"
              @click="triggerInstall"
            >
              <i class="pi pi-download text-[11px]" />
              安裝
            </button>
          </div>
        </div>

        <button
          type="button"
          class="flex-shrink-0 p-1 -m-1 text-[var(--color-muted)] hover:text-[var(--color-text)] transition-colors"
          aria-label="關閉提示"
          @click="dismiss"
        >
          <i class="pi pi-times text-sm" />
        </button>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.pwa-prompt-enter-active,
.pwa-prompt-leave-active {
  transition:
    opacity 220ms ease,
    transform 220ms ease;
}
.pwa-prompt-enter-from,
.pwa-prompt-leave-to {
  opacity: 0;
  transform: translateY(12px);
}
</style>
