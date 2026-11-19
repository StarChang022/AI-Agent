<script setup lang="ts">
/**
 * 表單內的憑證欄位（支出、收入、資金移轉、前台請款共用）：縮圖格、選檔或拖放、預覽、移除。
 * 上傳、刪除、網址重撈交給父層的 useAttachmentUploads；這裡只負責畫面。
 * - 沒有憑證時顯示整塊上傳區（drop-extra slot 可放「拍照」等按鈕）；有憑證後改成縮圖格 +「加入」小格
 * - cell-extra slot 放在每格縮圖上（OCR 勾選框）
 */
import { computed, ref } from 'vue'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import AttachmentThumb from '@/components/AttachmentThumb.vue'
import { MAX_ATTACHMENTS, MAX_ATTACHMENT_MB, fileUrl } from '@/api/attachments'
import type { FormAttachment } from '@/types/expense-form'
import { isImageMime } from '@/utils/attachment'

const props = withDefaults(
  defineProps<{
    attachments: FormAttachment[]
    /** 刪除中的已存圖檔（key） */
    deletingKeys?: Set<string>
    /** 處理中（例如前台壓縮圖片）：暫停加入檔案 */
    busy?: boolean
    accept?: string
    /** 上傳區的說明文字 */
    hint?: string
    /** PDF 縮圖點了直接下載，不開預覽（前台） */
    pdfDownload?: boolean
    /** 縮圖變淡（例如沒勾選辨識的補充資料） */
    isOff?: (att: FormAttachment) => boolean
    /** 放在對話框內：上傳區較矮 */
    compact?: boolean
    /** 已儲存的圖檔按移除會立即永久刪除（編輯頁）；false 時只從畫面拿掉、儲存才生效（代墊款） */
    savedDeletesNow?: boolean
  }>(),
  {
    deletingKeys: () => new Set<string>(),
    busy: false,
    accept: 'image/jpeg,image/png,application/pdf,.pdf',
    hint: `JPG、PNG 或 PDF，可一次選多張（最多 ${MAX_ATTACHMENTS} 張），單檔 ${MAX_ATTACHMENT_MB}MB 以內`,
    pdfDownload: false,
    isOff: undefined,
    compact: false,
    savedDeletesNow: true,
  },
)
const emit = defineEmits<{
  add: [files: File[]]
  remove: [att: FormAttachment]
  /** 縮圖或預覽讀不到（簽章網址失效）；父層重撈新網址 */
  expired: [att: FormAttachment]
}>()
/** 預覽開著；放在 Dialog 內使用時，外層要據此停用 Esc 關閉 */
const previewing = defineModel<boolean>('previewing', { default: false })

const isDragging = ref(false)
const dropInput = ref<HTMLInputElement | null>(null)
const previewAtt = ref<FormAttachment | null>(null)
const canAdd = computed(() => props.attachments.length < MAX_ATTACHMENTS)

function openPreview(att: FormAttachment) {
  previewAtt.value = att
  previewing.value = true
}
function closePreview() {
  previewAtt.value = null
  previewing.value = false
}

function onChange(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''
  if (files.length) emit('add', files)
}

function onDrop(event: DragEvent) {
  isDragging.value = false
  if (props.busy) return
  const files = Array.from(event.dataTransfer?.files ?? [])
  if (files.length) emit('add', files)
}

/** 滑鼠點整塊上傳區開選檔；裡面的按鈕（上傳憑證、拍照等）自己處理 */
function onDropZoneClick(e: MouseEvent) {
  if ((e.target as HTMLElement).closest('button, label, a')) return
  if (!props.busy) dropInput.value?.click()
}
function openPicker() {
  if (!props.busy) dropInput.value?.click()
}
</script>

<template>
  <div class="flex flex-col gap-3">
    <ul v-if="attachments.length" class="att-grid">
      <li
        v-for="att in attachments"
        :key="att.key"
        class="att-cell"
        :class="{ 'is-off': isOff?.(att) }"
      >
        <div class="relative aspect-square">
          <a
            v-if="pdfDownload && !isImageMime(att.mimeType) && att.url"
            :href="fileUrl(att.url, { download: true })"
            class="att-thumb absolute inset-0 w-full h-full rounded-chip border border-[var(--color-hairline)] bg-[var(--color-surface)] overflow-hidden block"
            :aria-label="`下載 ${att.filename}`"
          >
            <AttachmentThumb :filename="att.filename" :mime-type="att.mimeType" :url="att.url" />
          </a>
          <button
            v-else
            type="button"
            class="att-thumb absolute inset-0 w-full h-full rounded-chip border border-[var(--color-hairline)] bg-white overflow-hidden cursor-pointer block"
            :aria-label="`預覽 ${att.filename}`"
            @click="openPreview(att)"
          >
            <AttachmentThumb
              :filename="att.filename"
              :mime-type="att.mimeType"
              :url="att.url"
              :local-url="att.localUrl"
              :uploading="att.uploading"
              @expired="emit('expired', att)"
            />
          </button>
          <slot name="cell-extra" :att="att" />
          <button
            type="button"
            class="absolute -top-1.5 -right-1.5 z-10 w-6 h-6 rounded-full bg-[var(--color-ink)] text-white flex items-center justify-center hover:opacity-90 disabled:opacity-60"
            :aria-label="att.saved && savedDeletesNow ? `刪除 ${att.filename}` : `移除 ${att.filename}`"
            :disabled="deletingKeys.has(att.key)"
            @click="emit('remove', att)"
          >
            <i :class="deletingKeys.has(att.key) ? 'pi pi-spin pi-spinner' : 'pi pi-times'" class="text-xs" aria-hidden="true" />
          </button>
        </div>
        <span class="att-name" :title="att.filename">{{ att.filename }}</span>
      </li>
      <!-- 繼續加入（長收據可分段拍） -->
      <li v-if="canAdd">
        <label
          class="att-add aspect-square"
          :class="{ 'is-drag': isDragging, 'opacity-60 pointer-events-none': busy }"
          @dragover.prevent="isDragging = true"
          @dragleave="isDragging = false"
          @drop.prevent="onDrop"
        >
          <i :class="busy ? 'pi pi-spin pi-spinner' : 'pi pi-plus'" aria-hidden="true" />
          <span>加入</span>
          <small>JPG／PNG／PDF</small>
          <input type="file" :accept="accept" multiple class="sr-only" aria-label="加入憑證" :disabled="busy" @change="onChange" />
        </label>
      </li>
    </ul>

    <!--
      外層只負責滑鼠點擊與拖放，不當按鈕：裡面的「拍照／選擇檔案」（drop-extra）才能各自被螢幕閱讀器讀到、各自操作。
      鍵盤與螢幕閱讀器用下面的「上傳憑證」按鈕（視覺隱藏，聚焦時整塊上傳區顯示外框）。
    -->
    <div
      v-else
      class="upload-drop"
      :class="{ 'is-drag': isDragging, 'att-drop-compact': compact }"
      @click="onDropZoneClick"
      @dragover.prevent="isDragging = true"
      @dragleave="isDragging = false"
      @drop.prevent="onDrop"
    >
      <input ref="dropInput" type="file" :accept="accept" multiple class="hidden" tabindex="-1" aria-hidden="true" :disabled="busy" @change="onChange" />
      <button type="button" class="sr-only" :disabled="busy" @click="openPicker">上傳憑證</button>
      <i v-if="!compact || busy" :class="[busy ? 'pi pi-spin pi-spinner' : 'pi pi-cloud-upload', 'upload-drop-icon']" aria-hidden="true" />
      <b>{{ busy ? '處理中…' : '拖放檔案，或點擊上傳' }}</b>
      <span>{{ hint }}</span>
      <slot name="drop-extra" />
    </div>

    <AttachmentPreviewDialog
      :file="previewAtt"
      @close="closePreview"
      @expired="previewAtt && emit('expired', previewAtt)"
    />
  </div>
</template>

<style scoped>
.att-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: var(--space-xs);
  align-items: start;
  margin: 0;
  padding: 6px 6px 0 0;
  list-style: none;
}
.att-add { width: 100%; }
.att-drop-compact { padding: 16px; }
@media (max-width: 639.98px) {
  .att-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); }
}
</style>
