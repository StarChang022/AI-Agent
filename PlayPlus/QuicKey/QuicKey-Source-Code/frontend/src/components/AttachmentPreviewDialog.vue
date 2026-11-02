<script setup lang="ts">
/**
 * 憑證放大預覽：圖片直接顯示；PDF 用 vue-pdf-embed（底層 pdf.js）render 到 canvas，
 * 全平台一致（含 Android Chrome，原本 <iframe> 在 Android 空白）。
 * 「另開分頁」保留為 fallback —— 需要時用 blob URL 跳瀏覽器 PDF viewer。
 */
import { computed, defineAsyncComponent, onBeforeUnmount, ref, watch } from 'vue'
import Dialog from 'primevue/dialog'

// vue-pdf-embed 連 pdf.js engine 約 2.5MB，純憑證預覽才需要 → async chunk 懶載，
// 不要撐爆 PWA 初始 precache（workbox 預設 2MB 上限）。
const VuePdfEmbed = defineAsyncComponent(() => import('vue-pdf-embed'))

const props = defineProps<{
  src: string | null
  filename?: string
  mimeType?: string
}>()
const emit = defineEmits<{ close: [] }>()

const kind = computed<'image' | 'pdf' | 'other'>(() => {
  const src = props.src ?? ''
  const type = props.mimeType || src.slice(5, src.indexOf(';'))
  if (type.startsWith('image/')) return 'image'
  if (type === 'application/pdf' || props.filename?.toLowerCase().endsWith('.pdf')) return 'pdf'
  return 'other'
})

// 保留 blob URL：給「另開分頁」用（瀏覽器不允許直接開 data:application/pdf）。
// vue-pdf-embed 自己能吃 data URL，不需要經過 blob URL。
const blobUrl = ref<string | null>(null)
function revoke() {
  if (blobUrl.value) URL.revokeObjectURL(blobUrl.value)
  blobUrl.value = null
}
function toBlobUrl(dataUrl: string, type: string): string {
  const [meta, data] = dataUrl.split(',')
  const isBase64 = meta.includes(';base64')
  const bytes = isBase64 ? Uint8Array.from(atob(data), (c) => c.charCodeAt(0)) : new TextEncoder().encode(decodeURIComponent(data))
  return URL.createObjectURL(new Blob([bytes], { type }))
}
const openUrl = computed(() => blobUrl.value ?? (props.src && !props.src.startsWith('data:') ? props.src : null))

// 手機瀏覽器開 blob URL 新分頁一律失效（Android Chrome / iOS Safari 都失去 opener
// document context → 新 tab 空白）。vue-pdf-embed 已在 dialog 內渲染完整 PDF，手機
// 直接隱藏「另開分頁」避免點了沒反應；桌機維持原本能走的路徑。
const isMobile = typeof window !== 'undefined' && window.matchMedia('(hover: none) and (pointer: coarse)').matches

// PDF.js 載入狀態；src 切換時 reset
const pdfLoading = ref(false)
const pdfError = ref<Error | null>(null)
function onPdfRendered() {
  pdfLoading.value = false
}
function onPdfError(e: Error) {
  pdfLoading.value = false
  pdfError.value = e
}

watch(
  () => props.src,
  (src) => {
    revoke()
    pdfError.value = null
    pdfLoading.value = kind.value === 'pdf' && !!src
    if (!src || kind.value === 'image') return
    if (!src.startsWith('data:')) {
      blobUrl.value = null
      return
    }
    try {
      blobUrl.value = toBlobUrl(src, kind.value === 'pdf' ? 'application/pdf' : props.mimeType || 'application/octet-stream')
    } catch {
      blobUrl.value = null
    }
  },
  { immediate: true },
)
onBeforeUnmount(revoke)
</script>

<template>
  <Dialog
    :visible="src !== null"
    modal
    dismissable-mask
    :show-header="false"
    :style="{ width: kind === 'pdf' ? 'min(94vw, 900px)' : 'min(92vw, 720px)' }"
    content-class="!p-0"
    @update:visible="emit('close')"
  >
    <div class="relative" :class="kind === 'image' ? 'bg-black' : 'bg-[var(--color-surface)]'">
      <div v-if="kind !== 'image'" class="flex items-center gap-3 px-4 py-3 pr-14 border-b border-[var(--color-hairline)] bg-white">
        <i class="pi pi-file-pdf text-lg text-[var(--color-danger)]" aria-hidden="true" />
        <span class="flex-1 min-w-0 truncate text-sm font-semibold text-[var(--color-ink)]">{{ filename || '憑證檔案' }}</span>
        <a v-if="openUrl && !isMobile" :href="openUrl" target="_blank" rel="noopener" class="dash-panel-link inline-flex items-center gap-1">
          <i class="pi pi-external-link text-xs" aria-hidden="true" />另開分頁
        </a>
      </div>
      <button
        type="button"
        class="absolute top-2 right-2 z-10 w-9 h-9 rounded-full flex items-center justify-center"
        :class="kind === 'image' ? 'bg-black/60 text-white hover:bg-black/80' : 'text-[var(--color-muted)] hover:bg-[var(--color-surface-soft)]'"
        aria-label="關閉預覽"
        @click="emit('close')"
      >
        <i class="pi pi-times" />
      </button>
      <img v-if="kind === 'image' && src" :src="src" :alt="filename ? `${filename} 放大檢視` : '憑證放大檢視'" class="w-full max-h-[80vh] object-contain" />
      <div v-else-if="kind === 'pdf' && src" class="pdf-canvas-wrap">
        <VuePdfEmbed
          :source="src"
          class="pdf-canvas"
          @rendered="onPdfRendered"
          @loading-failed="onPdfError"
          @rendering-failed="onPdfError"
        />
        <div v-if="pdfLoading" class="pdf-loading" role="status" aria-live="polite">
          <i class="pi pi-spin pi-spinner text-2xl" aria-hidden="true" />
          <span>PDF 載入中…</span>
        </div>
        <div v-else-if="pdfError" class="pdf-error">
          <i class="pi pi-exclamation-triangle text-3xl mb-2 block" aria-hidden="true" />
          <p class="mb-3">PDF 無法在此預覽</p>
          <a v-if="openUrl && !isMobile" :href="openUrl" target="_blank" rel="noopener" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[var(--color-primary)] text-white text-sm">
            <i class="pi pi-external-link" aria-hidden="true" />開啟 PDF
          </a>
        </div>
      </div>
      <div v-else class="p-10 text-center text-sm text-[var(--color-muted)]">
        <i class="pi pi-file text-4xl mb-2 block" aria-hidden="true" />
        這個檔案無法在此預覽{{ openUrl && !isMobile ? '，請另開分頁檢視' : '' }}
      </div>
    </div>
  </Dialog>
</template>

<style scoped>
.pdf-canvas-wrap {
  position: relative;
  max-height: 75vh;
  overflow-y: auto;
  background: var(--color-surface);
}
.pdf-canvas :deep(.vue-pdf-embed__page) {
  margin: 8px auto;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
  background: #fff;
}
.pdf-canvas :deep(canvas) {
  max-width: 100%;
  height: auto !important;
  display: block;
}
.pdf-loading,
.pdf-error {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  background: var(--color-surface);
  color: var(--color-muted);
  font-size: 14px;
}
.pdf-error {
  color: var(--color-ink);
}
</style>
