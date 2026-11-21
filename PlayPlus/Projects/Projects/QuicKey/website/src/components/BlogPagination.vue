<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{ current: number; total: number }>()
const emit = defineEmits<{ change: [page: number] }>()

type Item = { type: 'page'; n: number; main: boolean } | { type: 'gap'; key: string }

// 頁碼清單：永遠顯示第 1 頁與最後一頁，目前頁前後各 1 頁，中間以省略號代替
const items = computed<Item[]>(() => {
  const t = props.total
  const c = props.current
  const nums = [...new Set([1, t, c - 1, c, c + 1])]
    .filter((n) => n >= 1 && n <= t)
    .sort((a, b) => a - b)
  const out: Item[] = []
  let prev = 0
  for (const n of nums) {
    if (n - prev > 1) out.push({ type: 'gap', key: `gap-${n}` })
    // 手機版只保留「第 1 頁、目前頁、最後一頁」，其餘頁碼隱藏
    out.push({ type: 'page', n, main: n === c || n === 1 || n === t })
    prev = n
  }
  return out
})

function go(page: number) {
  if (page < 1 || page > props.total || page === props.current) return
  emit('change', page)
}
</script>

<template>
  <nav class="pager" aria-label="文章分頁">
    <button type="button" class="pager-btn pager-nav" :disabled="current <= 1" @click="go(current - 1)">
      上一頁
    </button>
    <ul class="pager-list">
      <li v-for="it in items" :key="it.type === 'page' ? it.n : it.key" :class="{ 'pg-extra': it.type === 'page' && !it.main }">
        <span v-if="it.type === 'gap'" class="pager-gap" aria-hidden="true">…</span>
        <button
          v-else
          type="button"
          class="pager-btn pager-num"
          :aria-current="it.n === current ? 'page' : undefined"
          :aria-label="`第 ${it.n} 頁`"
          @click="go(it.n)"
        >
          {{ it.n }}
        </button>
      </li>
    </ul>
    <button type="button" class="pager-btn pager-nav" :disabled="current >= total" @click="go(current + 1)">
      下一頁
    </button>
  </nav>
</template>

<style scoped>
.pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 56px;
}
.pager-list {
  display: flex;
  align-items: center;
  gap: 4px;
  list-style: none;
  margin: 0;
  padding: 0;
}
.pager-gap {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 40px;
  min-height: 40px;
  color: var(--color-muted);
}
.pager-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 40px;
  min-height: 40px;
  padding: 0 12px;
  font: inherit;
  font-size: 14px;
  color: var(--color-ink);
  background: var(--color-canvas);
  border: 1px solid var(--color-hairline);
  border-radius: 10000px;
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;
}
.pager-btn:hover:not(:disabled) {
  border-color: var(--color-primary-500);
}
.pager-btn:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}
.pager-btn:disabled {
  color: var(--color-muted);
  background: var(--color-surface);
  cursor: not-allowed;
  opacity: 0.6;
}
.pager-num[aria-current='page'] {
  color: var(--color-canvas);
  background: var(--color-primary-700);
  border-color: var(--color-primary-700);
  font-weight: 600;
}
@media (max-width: 639.98px) {
  .pager {
    gap: 4px;
    margin-top: 40px;
  }
  .pager-list li.pg-extra {
    display: none;
  }
  .pager-btn,
  .pager-gap {
    min-height: 44px;
  }
  .pager-btn {
    min-width: 44px;
  }
  .pager-nav {
    padding: 0 14px;
  }
}
</style>
