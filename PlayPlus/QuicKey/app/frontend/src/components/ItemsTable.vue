<script setup lang="ts">
/**
 * 品項明細唯讀表（支出 / 收入 / 代墊款詳情共用）。沒有品項時不顯示。
 */
import { computed } from 'vue'
import type { ExpenseItem } from '@/types/domain'
import { formatCurrency } from '@/utils/format'

const props = defineProps<{ items: ExpenseItem[] }>()

const total = computed(() => props.items.reduce((acc, it) => acc + it.subtotal, 0))
</script>

<template>
  <!-- 手機窄螢幕時表格自己橫向捲動，不撐寬整頁 -->
  <div v-if="items.length" class="overflow-x-auto">
    <table class="w-full text-sm">
      <caption class="sr-only">品項明細</caption>
      <thead>
        <tr class="bg-[var(--color-surface)] text-[var(--color-slate)]">
          <th scope="col" class="text-left font-semibold py-2 px-2">品項</th>
          <th scope="col" class="text-right font-semibold py-2 px-2">數量</th>
          <th scope="col" class="text-right font-semibold py-2 px-2">單價</th>
          <th scope="col" class="text-right font-semibold py-2 px-2">小計</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(it, i) in items" :key="i" class="border-t border-[var(--color-hairline)]">
          <td class="py-2 px-2">{{ it.name }}</td>
          <td class="py-2 px-2 text-right tabular-nums">{{ it.quantity }}</td>
          <td class="py-2 px-2 text-right tabular-nums">{{ formatCurrency(it.unitPrice) }}</td>
          <td class="py-2 px-2 text-right tabular-nums">{{ formatCurrency(it.subtotal) }}</td>
        </tr>
        <tr class="border-t border-[var(--color-hairline)]">
          <td colspan="3" class="py-2 px-2 text-right text-[var(--color-muted)]">品項合計</td>
          <td class="py-2 px-2 text-right tabular-nums font-semibold">{{ formatCurrency(total) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
