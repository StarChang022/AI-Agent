<script setup lang="ts">
/**
 * 憑證放大預覽：圖片直接顯示；PDF 用 vue-pdf-embed（底層 pdf.js）render 到 canvas，
 * 全平台一致（含 Android Chrome，原本 <iframe> 在 Android 空白）。
 * 圖檔網址是後端簽章網址（不需登入標頭），「另開分頁」「下載」直接用網址。
 * 讀不到時發出 expired，使用處重撈新網址後 file.url 換掉就會重新載入；重撈過仍讀不到才顯示錯誤。
 */
import { computed, defineAsyncComponent, ref, watch } from 'vue'
import Dialog from 'primevue/dialog'
import { fileUrl } from '@/api/attachments'
import { isImageMime, isPdfAttachment } from '@/utils/attachment'

// vue-pdf-embed 連 pdf.js engine 約 2.5MB，純憑證預覽才需要 → async chunk 懶載，
// 不要撐爆 PWA 初始 precache（workbox 預設 2MB 上限）。
const VuePdfEmbed = defineAsyncComponent(() => import('vue-pdf-embed'))

interface PreviewFile {
  filename: string
  mimeType: string
  /** 後端簽章網址；上傳中為 null */
  url: string | null
  /** 上傳中的本機預覽 */
  localUrl?: string | null
}

const props = defineProps<{ file: PreviewFile | null }>()
const emit = defineEmits<{ close: []; expired: [] }>()

const src = computed(() => {
  const f = props.file
  if (!f) return null
  return f.localUrl ?? (f.url ? fileUrl(f.url) : null)
})
const filename = computed(() => props.file?.filename)
const downloadUrl = computed(() => (props.file?.url ? fileUrl(props.file.url, { download: true }) : null))

const kind = computed<'image' | 'pdf' | 'other'>(() => {
  const f = props.file
  if (!f) return 'other'
  if (isImageMime(f.mimeType)) return 'image'
  return isPdfAttachment(f) ? 'pdf' : 'other'
})

// PDF.js 載入狀態；src 切換時 reset
const pdfLoading = ref(false)
const pdfError = ref<Error | null>(null)
const imageError = ref(false)
function onPdfRendered() {
  pdfLoading.value = false
}
function onPdfError(e: Error) {
  pdfLoading.value = false
  pdfError.value = e
  if (!props.file?.localUrl) emit('expired')
}
function onImageError() {
  imageError.value = true
  if (!props.file?.localUrl) emit('expired')
}

watch(
  src,
  (v) => {
    pdfError.value = null
    imageError.value = false
    pdfLoading.value = kind.value === 'pdf' && !!v
  },
  { immediate: true },
)
</script>

<template>
  <Dialog
    :visible="file !== null"
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
        <a v-if="src" :href="src" target="_blank" rel="noopener" class="dash-panel-link inline-flex items-center gap-1">
          <i class="pi pi-external-link text-xs" aria-hidden="true" />另開分頁
        </a>
        <a v-if="downloadUrl" :href="downloadUrl" class="dash-panel-link inline-flex items-center gap-1">
          <i class="pi pi-download text-xs" aria-hidden="true" />下載
        </a>
      </div>
      <button
        type="button"
        class="absolute top-2 right-2 z-10 w-9 h-9 rounded-full flex items-center justify-center"
        :class="kind === 'image' ? 'bg-black/60 text-white hover:bg-black/80' : 'text-[var(--color-muted)] hover:bg-[var(--color-surface-soft)]'"
        aria-label="關閉預覽"
        @click="emit('close')"
      >
        <i class="pi pi-times" aria-hidden="true" />
      </button>
      <img
        v-if="kind === 'image' && src && !imageError"
        :src="src"
        :alt="filename ? `${filename} 放大檢視` : '憑證放大檢視'"
        class="w-full max-h-[80vh] object-contain"
        @error="onImageError"
      />
      <div v-else-if="kind === 'image'" class="p-10 text-center text-sm text-white">
        <i class="pi pi-image text-4xl mb-2 block" aria-hidden="true" />
        圖檔無法顯示
      </div>
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
          <a v-if="src" :href="src" target="_blank" rel="noopener" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[var(--color-primary)] text-white text-sm">
            <i class="pi pi-external-link" aria-hidden="true" />開啟 PDF
          </a>
        </div>
      </div>
      <div v-else class="p-10 text-center text-sm text-[var(--color-muted)]">
        <i class="pi pi-file text-4xl mb-2 block" aria-hidden="true" />
        這個檔案無法在此預覽{{ src ? '，請另開分頁檢視' : '' }}
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
