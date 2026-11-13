<script setup lang="ts">
/**
 * 資料匯出下載頁（PRD 第 24 條、docs/dev/data-export-api.md）。
 * 背景產生完成的通知信與站內通知連到這裡；需以同公司管理員登入（路由守衛處理未登入導向）。
 * 狀態：產生中（自動重新查詢）、失敗、已失效、可下載；當下下載的匯出沒有存檔，另外說明。
 */
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useRoute, useRouter, type RouteLocationRaw } from 'vue-router'
import Button from 'primevue/button'
import { useToast } from 'primevue/usetoast'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import {
  getDataExport,
  getDataExportFileUrl,
  type DataExport,
  type DataExportFile,
  type DataExportFileKey,
  type DataExportKind,
} from '@/api/data-exports'
import { HttpError } from '@/api/service'
import { logout } from '@/api/auth'
import { formatBytes, formatDateTime } from '@/utils/format'
import { userErrorToast } from '@/utils/userFeedback'

const route = useRoute()
const router = useRouter()
const toast = useToast()

const id = computed(() => String(route.params.id ?? ''))
const record = ref<DataExport | null>(null)
const loading = ref(true)
/** 讀取失敗的原因：not_found = 找不到或不是這家公司的匯出；unauthorized = 登入已過期 */
const loadError = ref<'not_found' | 'unauthorized' | 'other' | null>(null)

const POLL_MS = 5000
let pollTimer: number | null = null
function stopPolling() {
  if (pollTimer !== null) window.clearTimeout(pollTimer)
  pollTimer = null
}

let seq = 0
async function load(showSpinner = true) {
  const mySeq = ++seq
  stopPolling()
  if (showSpinner) loading.value = true
  try {
    const data = await getDataExport(id.value)
    if (mySeq !== seq) return
    record.value = data
    loadError.value = null
    // 產生中：定時重新查詢，完成後畫面自動換成下載按鈕
    if (data.status === 'queued' || data.status === 'processing') {
      pollTimer = window.setTimeout(() => void load(false), POLL_MS)
    }
  } catch (err) {
    if (mySeq !== seq) return
    // 產生中的自動更新失敗（例如網路瞬斷）：保留目前畫面，下一輪再試；登入過期才換畫面
    const unauthorized = err instanceof HttpError && err.status === 401
    if (!showSpinner && record.value && !unauthorized) {
      pollTimer = window.setTimeout(() => void load(false), POLL_MS)
      return
    }
    record.value = null
    if (err instanceof HttpError && (err.status === 404 || err.status === 403)) loadError.value = 'not_found'
    else if (err instanceof HttpError && err.status === 401) loadError.value = 'unauthorized'
    else loadError.value = 'other'
  } finally {
    if (mySeq === seq) loading.value = false
  }
}
watch(id, () => void load(), { immediate: true })
onBeforeUnmount(stopPolling)

type ViewState = 'loading' | 'error' | 'pending' | 'failed' | 'expired' | 'instant' | 'ready'
const state = computed<ViewState>(() => {
  if (loading.value) return 'loading'
  const r = record.value
  if (!r) return 'error'
  if (r.status === 'queued' || r.status === 'processing') return 'pending'
  if (r.status === 'failed') return 'failed'
  if (!r.background) return 'instant'
  if (r.expired) return 'expired'
  return 'ready'
})

const liveText = computed(() => {
  switch (state.value) {
    case 'pending': return '匯出檔產生中'
    case 'ready': return '匯出檔已完成，可以下載'
    case 'failed': return '匯出失敗，請重新匯出'
    case 'expired': return '下載連結已失效，請重新匯出'
    default: return ''
  }
})

/** 重新匯出的去處：依匯出類型回到對應列表 */
const LIST_TARGETS: Record<DataExportKind, { route: RouteLocationRaw; label: string }> = {
  expense: { route: { name: 'admin-expenses' }, label: '前往支出列表' },
  income: { route: { name: 'admin-incomes' }, label: '前往收入列表' },
  reimbursement: { route: { name: 'admin-records' }, label: '前往請款記錄' },
}
const listTarget = computed(() => LIST_TARGETS[record.value?.kind ?? 'expense'] ?? LIST_TARGETS.expense)
const listRoute = computed(() => listTarget.value.route)
const listLabel = computed(() => listTarget.value.label)

const FILE_LABELS: Record<DataExportFileKey, string> = {
  expense_csv: '支出清單',
  income_csv: '收入清單',
  reimbursement_csv: '代墊款清單',
  attachments_zip: '圖檔',
}
function fileLabel(f: DataExportFile): string {
  return `${FILE_LABELS[f.key] ?? f.filename}（${f.kind.toUpperCase()}）`
}

const downloadingKey = ref<DataExportFileKey | null>(null)
async function download(f: DataExportFile) {
  if (!record.value || downloadingKey.value) return
  downloadingKey.value = f.key
  try {
    const url = await getDataExportFileUrl(record.value.id, f.key)
    // 短效簽章網址，瀏覽器直接串流下載，不經前端記憶體
    window.location.href = url
  } catch (err) {
    if (err instanceof HttpError && err.status === 401) {
      relogin()
    } else if (err instanceof HttpError && err.status === 410) {
      // 頁面開著期間剛好失效：改顯示已失效畫面
      record.value = { ...record.value, expired: true, files: [] }
      toast.add({ severity: 'warn', summary: '下載連結已失效', detail: '請重新匯出。', life: 3000 })
    } else {
      toast.add({ severity: 'error', ...userErrorToast(err, '取得下載連結失敗'), life: 3500 })
    }
  } finally {
    downloadingKey.value = null
  }
}

function relogin() {
  logout()
  router.push({ name: 'admin-login', query: { redirect: route.fullPath } })
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="資料匯出" size="admin" />

    <div v-if="state === 'loading'" class="dash-empty" role="status">
      <i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…
    </div>

    <template v-else-if="state === 'error'">
      <EmptyState
        v-if="loadError === 'not_found'"
        icon="pi pi-search"
        title="找不到這次匯出"
        description="連結可能有誤，或這次匯出不屬於目前登入的公司"
      >
        <template #action>
          <RouterLink :to="{ name: 'admin-dashboard' }" class="link-btn">回到總覽</RouterLink>
        </template>
      </EmptyState>
      <EmptyState v-else-if="loadError === 'unauthorized'" icon="pi pi-lock" title="登入已過期" description="請重新登入後再下載">
        <template #action>
          <Button label="重新登入" @click="relogin" />
        </template>
      </EmptyState>
      <EmptyState v-else icon="pi pi-exclamation-circle" title="載入匯出資料失敗" description="請稍後再試">
        <template #action>
          <Button label="重新載入" outlined @click="load()" />
        </template>
      </EmptyState>
    </template>

    <template v-else-if="record">
      <!-- 常駐的狀態播報：產生中 → 完成時畫面區塊會整個替換，讀屏從這裡得知結果 -->
      <p class="sr-only" role="status" aria-live="polite">{{ liveText }}</p>
      <section class="dash-panel export-panel" aria-labelledby="export-scope-title">
        <div class="export-head">
          <h2 id="export-scope-title" class="export-title">匯出檔案</h2>
          <span v-if="state === 'pending'" class="tag-soft tag-neutral">產生中</span>
          <span v-else-if="state === 'failed'" class="tag-soft tag-danger">失敗</span>
          <span v-else-if="state === 'expired'" class="tag-soft tag-neutral">已失效</span>
        </div>

        <dl class="export-meta">
          <div>
            <dt>匯出範圍</dt>
            <dd>{{ record.scopeLabel }}</dd>
          </div>
          <div>
            <dt>筆數</dt>
            <dd class="tabular-nums">{{ record.recordCount }} 筆</dd>
          </div>
          <div>
            <dt>發起時間</dt>
            <dd class="tabular-nums">{{ formatDateTime(record.createdAt) }}<template v-if="record.requestedBy?.name">（{{ record.requestedBy.name }}）</template></dd>
          </div>
          <div v-if="record.completedAt && state !== 'failed'">
            <dt>產生時間</dt>
            <dd class="tabular-nums">{{ formatDateTime(record.completedAt) }}</dd>
          </div>
          <div v-if="record.expiresAt">
            <dt>失效時間</dt>
            <dd class="tabular-nums">{{ formatDateTime(record.expiresAt) }}</dd>
          </div>
        </dl>

        <!-- 可下載 -->
        <div v-if="state === 'ready'" class="export-files">
          <ul class="export-file-list">
            <li v-for="f in record.files" :key="f.key">
              <div class="export-file-info">
                <i :class="['pi', f.kind === 'zip' ? 'pi-images' : 'pi-file']" aria-hidden="true" />
                <span class="export-file-name">{{ fileLabel(f) }}</span>
                <span class="export-file-size">{{ formatBytes(f.byteSize) }}</span>
              </div>
              <Button
                :label="`下載 ${f.kind.toUpperCase()}`"
                icon="pi pi-download"
                size="small"
                outlined
                :loading="downloadingKey === f.key"
                :disabled="!!downloadingKey && downloadingKey !== f.key"
                :aria-label="`下載${fileLabel(f)}`"
                @click="download(f)"
              />
            </li>
          </ul>
        </div>

        <!-- 其他狀態的說明 -->
        <div v-else class="export-status">
          <template v-if="state === 'pending'">
            <i class="pi pi-spin pi-spinner" aria-hidden="true" />
            <p>匯出檔產生中，完成後會寄信通知；這個頁面也會自動更新。</p>
          </template>
          <template v-else-if="state === 'failed'">
            <i class="pi pi-times-circle is-danger" aria-hidden="true" />
            <p>匯出失敗，請重新匯出。</p>
          </template>
          <template v-else-if="state === 'expired'">
            <i class="pi pi-clock" aria-hidden="true" />
            <p>下載連結已失效，請重新匯出。</p>
          </template>
          <template v-else-if="state === 'instant'">
            <i class="pi pi-check-circle" aria-hidden="true" />
            <p>這次匯出沒有圖檔，已在發起時直接下載，系統沒有保留檔案。需要的話請重新匯出。</p>
          </template>
        </div>

        <div v-if="state === 'failed' || state === 'expired' || state === 'instant'" class="export-actions">
          <RouterLink :to="listRoute" class="link-btn">{{ listLabel }}</RouterLink>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.export-panel { gap: var(--space-md); }
.export-head { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.export-title { margin: 0; font-size: 16px; font-weight: 600; color: var(--color-ink); }
.export-meta { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 24px; margin: 0; }
.export-meta dt { font-size: 13px; color: var(--color-muted); }
.export-meta dd { margin: 2px 0 0; font-size: 14px; color: var(--color-ink); word-break: break-word; }
.export-hint { margin: 0 0 8px; font-size: 13px; color: var(--color-muted); }
.export-file-list { display: flex; flex-direction: column; gap: 8px; margin: 0; padding: 0; list-style: none; }
.export-file-list > li {
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  padding: 12px 14px; border: 1px solid var(--color-hairline); border-radius: var(--radius-card);
}
.export-file-info { display: flex; align-items: center; gap: 8px; min-width: 0; flex-wrap: wrap; font-size: 14px; }
.export-file-info > i { color: var(--color-muted); }
.export-file-name { color: var(--color-ink); font-weight: 500; }
.export-file-size { color: var(--color-muted); font-size: 13px; font-variant-numeric: tabular-nums; }
.export-status {
  display: flex; align-items: flex-start; gap: 10px; padding: 14px 16px;
  border-radius: var(--radius-card); background: var(--color-surface); font-size: 14px; color: var(--color-slate);
}
.export-status > p { margin: 0; }
.export-status > i { margin-top: 3px; color: var(--color-muted); }
.export-status > i.is-danger { color: var(--color-status-rejected); }
.export-actions { display: flex; }
@media (max-width: 639.98px) {
  .export-title { font-size: 14px; }
  .export-meta { grid-template-columns: minmax(0, 1fr); }
  .export-file-list > li { flex-direction: column; align-items: stretch; }
  .export-file-list :deep(.p-button) { min-height: 44px; }
}
</style>
