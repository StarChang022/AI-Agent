<script setup lang="ts">
/**
 * 表單內的憑證欄位：選檔或拖放、縮圖預覽、移除（資金移轉使用）。
 * 限制對齊後端 ReceiptAttachmentValidation：最多 5 張、單檔 5MB、只收 JPG、PNG、PDF。
 */
import { computed, ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import type { ExpenseAttachment } from '@/types/domain'

const attachments = defineModel<ExpenseAttachment[]>({ required: true })
/** 預覽開著；放在 Dialog 內使用時，外層要據此停用 Esc 關閉 */
const previewing = defineModel<boolean>('previewing', { default: false })

const toast = useToast()

const MAX_ATTACHMENTS = 5
const MAX_ATTACHMENT_MB = 5
const ACCEPT = 'image/jpeg,image/png,application/pdf,.pdf'

const isDragging = ref(false)
const previewAtt = ref<ExpenseAttachment | null>(null)
const canAdd = computed(() => attachments.value.length < MAX_ATTACHMENTS)

function openPreview(att: ExpenseAttachment) {
  previewAtt.value = att
  previewing.value = true
}
function closePreview() {
  previewAtt.value = null
  previewing.value = false
}

function isPdf(file: File): boolean {
  return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')
}

function readAsDataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}

async function addFile(file: File) {
  if (!canAdd.value) {
    toast.add({ severity: 'warn', summary: `最多上傳 ${MAX_ATTACHMENTS} 張憑證`, life: 3000 })
    return
  }
  if (!['image/jpeg', 'image/png'].includes(file.type) && !isPdf(file)) {
    toast.add({ severity: 'warn', summary: `${file.name} 不支援`, detail: '請上傳 JPG、PNG 或 PDF 憑證', life: 3500 })
    return
  }
  if (file.size > MAX_ATTACHMENT_MB * 1024 * 1024) {
    toast.add({ severity: 'warn', summary: `${file.name} 超過 ${MAX_ATTACHMENT_MB}MB`, detail: '請壓縮後再上傳', life: 3500 })
    return
  }
  try {
    const dataUrl = await readAsDataUrl(file)
    // 有些系統選 PDF 時 file.type 會是空字串，用副檔名補上
    attachments.value = [...attachments.value, { dataUrl, filename: file.name, mimeType: file.type || 'application/pdf' }]
  } catch {
    toast.add({ severity: 'error', summary: `${file.name} 讀取失敗`, life: 2500 })
  }
}

async function onChange(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''
  for (const file of files) await addFile(file)
}

async function onDrop(event: DragEvent) {
  isDragging.value = false
  for (const file of Array.from(event.dataTransfer?.files ?? [])) await addFile(file)
}

function remove(index: number) {
  attachments.value = attachments.value.filter((_, i) => i !== index)
}
</script>

<template>
  <div class="flex flex-col gap-2">
    <ul v-if="attachments.length" class="att-list">
      <li v-for="(att, i) in attachments" :key="i" class="att-cell">
        <div class="relative aspect-square">
          <button
            type="button"
            class="att-thumb absolute inset-0 w-full h-full rounded-chip border border-[var(--color-hairline)] bg-white overflow-hidden cursor-pointer block"
            :aria-label="`預覽 ${att.filename}`"
            @click="openPreview(att)"
          >
            <img v-if="att.mimeType.startsWith('image/')" :src="att.dataUrl" :alt="att.filename" class="w-full h-full object-cover" />
            <span v-else class="w-full h-full flex flex-col items-center justify-center gap-1 bg-[var(--color-surface)]">
              <i class="pi pi-file-pdf text-3xl text-[var(--color-danger)]" aria-hidden="true" />
              <span class="text-xs font-semibold text-[var(--color-slate)]">PDF</span>
            </span>
          </button>
          <button
            type="button"
            class="absolute -top-1.5 -right-1.5 z-10 w-6 h-6 rounded-full bg-[var(--color-ink)] text-white flex items-center justify-center hover:opacity-90"
            :aria-label="`移除 ${att.filename}`"
            @click="remove(i)"
          >
            <i class="pi pi-times text-xs" aria-hidden="true" />
          </button>
        </div>
        <span class="att-name" :title="att.filename">{{ att.filename }}</span>
      </li>
    </ul>
    <label
      v-if="canAdd"
      class="upload-drop att-drop"
      :class="{ 'is-drag': isDragging }"
      @dragover.prevent="isDragging = true"
      @dragleave="isDragging = false"
      @drop.prevent="onDrop"
    >
      <b>拖放檔案，或點擊上傳</b>
      <span>JPG、PNG 或 PDF，最多 {{ MAX_ATTACHMENTS }} 張，單檔 {{ MAX_ATTACHMENT_MB }}MB 以內</span>
      <input type="file" :accept="ACCEPT" multiple class="sr-only" aria-label="上傳憑證" @change="onChange" />
    </label>
    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="closePreview"
    />
  </div>
</template>

<style scoped>
.att-list {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: var(--space-xs);
  margin: 0;
  padding: 6px 6px 0 0;
  list-style: none;
}
.att-drop { padding: 16px; }
@media (max-width: 639.98px) {
  .att-list { grid-template-columns: repeat(4, minmax(0, 1fr)); }
}
</style>
