<script setup lang="ts">
/**
 * 唯讀的憑證縮圖列 + 放大預覽（後台詳情抽屜、前台請款詳情共用）。
 * 沒有憑證時不顯示，空狀態文字由使用處自己決定。
 * 簽章網址失效時用 refetch 重撈這筆紀錄拿新網址（同一張只重撈一次）。
 */
import { computed, ref } from 'vue'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import AttachmentThumb from '@/components/AttachmentThumb.vue'
import { useAttachmentUrlRefresh } from '@/composables/useAttachmentUrlRefresh'
import type { Attachment } from '@/types/domain'

const props = withDefaults(
  defineProps<{
    attachments: Attachment[]
    /** 重撈這筆紀錄的圖檔（網址失效時拿新網址） */
    refetch?: () => Promise<Attachment[]>
    /** drawer：抽屜固定 4 欄；page：頁面內，寬螢幕固定格寬 */
    layout?: 'drawer' | 'page'
  }>(),
  { refetch: undefined, layout: 'drawer' },
)

/** 重撈拿到的新網址（id → url）；props 不直接改 */
const freshUrls = ref(new Map<string, string>())
const urlRefresh = useAttachmentUrlRefresh()
const items = computed(() => props.attachments.map((a) => ({ ...a, url: freshUrls.value.get(a.id) ?? a.url })))

async function onExpired(att: Attachment) {
  if (!props.refetch) return
  const fresh = await urlRefresh.refresh(att.url, 'record', props.refetch)
  if (!fresh) return
  const next = new Map(freshUrls.value)
  for (const a of fresh) next.set(a.id, a.url)
  freshUrls.value = next
}

const previewId = ref<string | null>(null)
const previewAtt = computed(() => items.value.find((a) => a.id === previewId.value) ?? null)

const tileClass =
  'aspect-square rounded-md border border-[var(--color-hairline)] overflow-hidden bg-[var(--color-surface)] flex items-center justify-center hover:border-[var(--color-primary-700)] transition-colors'
</script>

<template>
  <div
    v-if="attachments.length"
    :class="layout === 'drawer' ? 'dt-thumbs' : 'grid grid-cols-4 gap-2 lg:grid-cols-[repeat(auto-fill,minmax(0,110px))] lg:gap-3'"
  >
    <template v-for="att in items" :key="att.id">
      <button
        type="button"
        :class="tileClass"
        :aria-label="`預覽 ${att.filename}`"
        @click="previewId = att.id"
      >
        <AttachmentThumb
          :filename="att.filename"
          :mime-type="att.mimeType"
          :url="att.url"
          pdf-label="filename"
          @expired="onExpired(att)"
        />
      </button>
    </template>
  </div>
  <AttachmentPreviewDialog
    :file="previewAtt"
    @close="previewId = null"
    @expired="previewAtt && onExpired(previewAtt)"
  />
</template>
