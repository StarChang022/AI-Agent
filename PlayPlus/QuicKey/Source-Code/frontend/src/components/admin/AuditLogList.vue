<script setup lang="ts">
/**
 * 稽核歷程 inline 列表（詳情抽屜內用）。
 * 定位：取代原本的「紀錄」區塊，顯示該筆目標的完整歷程（建立 / 更新 / 狀態切換 /
 * 刪除 / 還原 / 作廢 等）。
 *
 * UI：預設收合（低頻資訊，點標題展開）；展開時 fetch。載入後保留在記憶體，
 * 關閉抽屜後下次重開會重新 fetch（component 隨 Drawer 重新 mount）。
 */
import { ref } from 'vue'
import { listAuditLogs, type AuditLogEntry, type AuditTargetType } from '@/api/audit-logs'
import { actionIcon, actionLabel, fieldLabel, formatValue } from '@/constants/auditLog'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  targetType: AuditTargetType
  targetId: string
}>()

const open = ref(false)
const loaded = ref(false)
const loading = ref(false)
const error = ref<string | null>(null)
const logs = ref<AuditLogEntry[]>([])

async function fetchIfNeeded() {
  if (loaded.value || loading.value) return
  loading.value = true
  error.value = null
  try {
    logs.value = await listAuditLogs(props.targetType, props.targetId)
    loaded.value = true
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

function toggle() {
  open.value = !open.value
  if (open.value) void fetchIfNeeded()
}

/**
 * 把 before / after 轉成 diff 條目：
 * - create（before 為 null）：顯示 after 的全部欄位，value 單值呈現
 * - update / status_change：取 before ∪ after 的 key，value 為 old → new
 * - delete / restore / purge / void 等（after 為 null 或值極少）：
 *   有 before 就顯示 before 的欄位當上下文（例如 void 的 prev_status / comment）
 */
interface DiffRow {
  key: string
  label: string
  before?: string
  after?: string
  single?: string
}
function diffRows(entry: AuditLogEntry): DiffRow[] {
  const b = entry.before ?? {}
  const a = entry.after ?? {}
  const keys = Array.from(new Set([...Object.keys(b), ...Object.keys(a)]))
  // create：單值；其他動作也在 before 為空時走單值分支
  if (!entry.before) {
    return keys.map((k) => ({ key: k, label: fieldLabel(k), single: formatValue(k, a[k]) }))
  }
  // delete / purge：只有 before 的資料
  if (!entry.after) {
    return keys.map((k) => ({ key: k, label: fieldLabel(k), single: formatValue(k, b[k]) }))
  }
  return keys.map((k) => ({
    key: k,
    label: fieldLabel(k),
    before: formatValue(k, b[k]),
    after:  formatValue(k, a[k]),
  }))
}
</script>

<template>
  <section class="dt-section dt-collapsible">
    <h3 class="dt-section-title">
      <button
        type="button"
        class="dt-collapse-head"
        :aria-expanded="open"
        aria-controls="audit-log-body"
        @click="toggle"
      >
        歷程紀錄
        <i class="pi pi-chevron-down" :class="{ 'is-open': open }" aria-hidden="true" />
      </button>
    </h3>
    <div v-show="open" id="audit-log-body">
      <div v-if="loading" class="log-note">載入中…</div>
      <div v-else-if="error" class="log-note log-error">載入失敗：{{ error }}</div>
      <div v-else-if="!logs.length" class="log-note">尚無紀錄</div>
      <ol v-else class="log-timeline" aria-label="歷程紀錄">
        <li v-for="entry in logs" :key="entry.id" class="log-entry">
          <div class="log-head">
            <span class="log-icon" :aria-hidden="true"><i class="pi" :class="actionIcon(entry.action)" /></span>
            <span class="log-action">{{ actionLabel(entry.action) }}</span>
            <span class="log-sep" aria-hidden="true">·</span>
            <span class="log-actor">{{ entry.actorName || '系統' }}</span>
            <span class="log-time tabular-nums">{{ formatDateTime(entry.createdAt) }}</span>
          </div>
          <ul v-if="diffRows(entry).length" class="log-diff">
            <li v-for="row in diffRows(entry)" :key="row.key">
              <span class="log-field">{{ row.label }}</span>
              <span v-if="row.single !== undefined" class="log-val">{{ row.single }}</span>
              <template v-else>
                <span class="log-val log-old">{{ row.before }}</span>
                <i class="pi pi-arrow-right log-arrow" aria-hidden="true" />
                <span class="log-val log-new">{{ row.after }}</span>
              </template>
            </li>
          </ul>
        </li>
      </ol>
    </div>
  </section>
</template>

<style scoped>
.log-note { padding: 8px 0; font-size: 13px; color: var(--color-muted); }
.log-error { color: var(--color-status-rejected); }
.log-timeline { list-style: none; padding: 4px 0 0; margin: 0; }
.log-entry { position: relative; padding: 10px 0 10px 0; border-top: 1px solid var(--color-hairline); }
.log-entry:first-child { border-top: none; padding-top: 4px; }
.log-head { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; font-size: 13px; }
.log-icon { display: inline-flex; align-items: center; justify-content: center; width: 20px; height: 20px; border-radius: 999px; background: var(--color-primary-50); color: var(--color-primary); font-size: 11px; flex: none; }
.log-action { font-weight: 600; color: var(--color-ink); }
.log-sep { color: var(--color-muted); }
.log-actor { color: var(--color-slate); }
.log-time { margin-left: auto; color: var(--color-muted); font-size: 12px; }
.log-diff { list-style: none; margin: 6px 0 0 26px; padding: 0; font-size: 12px; color: var(--color-slate); }
.log-diff li { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; line-height: 1.6; }
.log-field { color: var(--color-muted); min-width: 72px; }
.log-val { color: var(--color-ink); }
.log-old { color: var(--color-muted); text-decoration: line-through; text-decoration-color: color-mix(in oklab, var(--color-muted), transparent 50%); }
.log-new { color: var(--color-ink); font-weight: 500; }
.log-arrow { font-size: 10px; color: var(--color-muted); }
</style>
