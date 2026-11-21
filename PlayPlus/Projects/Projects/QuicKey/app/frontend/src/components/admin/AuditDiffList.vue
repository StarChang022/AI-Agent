<script setup lang="ts">
/** 稽核紀錄的變更內容：詳情抽屜的歷程與稽核日誌頁明細共用。字級與外距由父層決定 */
import type { AuditDiffRow } from '@/constants/auditLog'

defineProps<{ rows: AuditDiffRow[] }>()
</script>

<template>
  <ul v-if="rows.length" class="log-diff">
    <li v-for="row in rows" :key="row.key">
      <span class="log-field">{{ row.label }}</span>
      <span v-if="row.single !== undefined" class="log-val">{{ row.single }}</span>
      <template v-else>
        <span class="log-val log-old">{{ row.before }}</span>
        <i class="pi pi-arrow-right log-arrow" aria-hidden="true" />
        <span class="log-val log-new">{{ row.after }}</span>
      </template>
    </li>
  </ul>
</template>

<style scoped>
.log-diff { list-style: none; padding: 0; color: var(--color-slate); }
.log-diff li { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; line-height: 1.6; }
.log-field { color: var(--color-muted); min-width: 72px; }
.log-val { color: var(--color-ink); }
.log-old { color: var(--color-muted); text-decoration: line-through; text-decoration-color: color-mix(in oklab, var(--color-muted), transparent 50%); }
.log-new { color: var(--color-ink); font-weight: 500; }
.log-arrow { font-size: 10px; color: var(--color-muted); }
</style>
