<script setup lang="ts">
/**
 * 憑證縮圖內容（外層按鈕由使用處提供）：圖片顯示縮圖、PDF 顯示圖示；
 * 上傳中蓋一層 loading；讀不到時顯示「無法顯示」並發出 expired，讓使用處重撈新網址（網址換了會重新載入）。
 */
import { computed, ref, watch } from 'vue'
import { fileUrl } from '@/api/attachments'
import { isImageMime } from '@/utils/attachment'

const props = withDefaults(
  defineProps<{
    filename: string
    mimeType: string
    /** 後端簽章網址；上傳中為 null */
    url: string | null
    /** 上傳中的本機預覽，優先使用 */
    localUrl?: string | null
    uploading?: boolean
    /** PDF 圖示下的文字：表單顯示「PDF」，詳情顯示檔名 */
    pdfLabel?: 'type' | 'filename'
  }>(),
  { localUrl: null, uploading: false, pdfLabel: 'type' },
)
const emit = defineEmits<{ expired: [] }>()

const isImage = computed(() => isImageMime(props.mimeType))
const src = computed(() => props.localUrl ?? (props.url ? fileUrl(props.url) : null))
const failed = ref(false)
watch(src, () => (failed.value = false))
function onError() {
  failed.value = true
  // 本機預覽讀不到不是網址失效，不必重撈
  if (!props.localUrl) emit('expired')
}
</script>

<template>
  <span class="relative w-full h-full block">
    <img
      v-if="isImage && src && !failed"
      :src="src"
      :alt="filename"
      class="w-full h-full object-cover"
      loading="lazy"
      @error="onError"
    />
    <span
      v-else-if="isImage"
      class="w-full h-full flex flex-col items-center justify-center gap-1 p-1.5 bg-[var(--color-surface)]"
    >
      <i class="pi pi-image text-2xl text-[var(--color-muted)]" aria-hidden="true" />
      <span v-if="failed" class="w-full truncate text-center text-xs text-[var(--color-muted)]">無法顯示</span>
    </span>
    <span v-else class="w-full h-full flex flex-col items-center justify-center gap-1 p-1.5 bg-[var(--color-surface)]">
      <i class="pi pi-file-pdf text-2xl text-[var(--color-danger)]" aria-hidden="true" />
      <span v-if="pdfLabel === 'filename'" class="w-full truncate text-center text-xs text-[var(--color-muted)]">{{ filename }}</span>
      <span v-else class="text-xs font-semibold text-[var(--color-slate)]">PDF</span>
    </span>
    <span
      v-if="uploading"
      class="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-white/75 text-[var(--color-ink)]"
      role="status"
    >
      <i class="pi pi-spin pi-spinner text-xl" aria-hidden="true" />
      <span class="text-xs">上傳中</span>
    </span>
  </span>
</template>
