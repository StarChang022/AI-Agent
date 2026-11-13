<script setup lang="ts">
/**
 * 稽核歷程 inline 列表（詳情抽屜內用）。
 * 定位：取代原本的「紀錄」區塊，顯示該筆目標的完整歷程（建立 / 更新 / 狀態切換 /
 * 刪除 / 還原 / 作廢 等）。
 *
 * UI：預設收合（低頻資訊，點標題展開）；展開時 fetch。載入後保留在記憶體，
 * 關閉抽屜後下次重開會重新 fetch（component 隨 Drawer 重新 mount）。
 */
import { onMounted, ref } from 'vue'
import { listAuditLogHistory, type AuditLogEntry, type AuditTargetType } from '@/api/audit-logs'
import AuditDiffList from '@/components/admin/AuditDiffList.vue'
import { actionIcon, auditDiffRows, entryActionLabel } from '@/constants/auditLog'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  targetType: AuditTargetType
  targetId: string
  /** 開啟時就展開（用於只顯示歷程的 Dialog） */
  defaultOpen?: boolean
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
    logs.value = await listAuditLogHistory(props.targetType, props.targetId)
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

onMounted(() => {
  if (props.defaultOpen) toggle()
})
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
            <span class="log-action">{{ entryActionLabel(entry) }}</span>
            <span class="log-sep" aria-hidden="true">·</span>
            <span class="log-actor">{{ entry.actorName || '系統' }}</span>
            <span class="log-time tabular-nums">{{ formatDateTime(entry.createdAt) }}</span>
          </div>
          <AuditDiffList
            v-if="auditDiffRows(entry, targetType).length"
            :rows="auditDiffRows(entry, targetType)"
            class="log-entry-diff"
          />
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
.log-entry-diff { margin: 6px 0 0 26px; font-size: 12px; }
</style>
