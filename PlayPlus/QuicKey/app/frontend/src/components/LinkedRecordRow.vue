<script setup lang="ts">
/**
 * 抽屜裡的「關聯紀錄」列（對應支出、對應請款單）：左標籤、中間值、右側「前往… ›」。
 * 是真正的連結：一般點擊在同一分頁跳轉，按上一頁會回到原本的抽屜（抽屜開關與網址 ?open 同步，
 * 見 composables/useOpenQuery）；Cmd／Ctrl／中鍵可另開分頁。樣式同抽屜的 .dt-row，不另加框線。
 */
import type { RouteLocationRaw } from 'vue-router'

defineProps<{ to: RouteLocationRaw; label: string; action: string }>()
</script>

<template>
  <RouterLink :to="to" class="linked-row">
    <span class="linked-row-label">{{ label }}</span>
    <span class="linked-row-value"><slot /></span>
    <span class="linked-row-go">{{ action }}<i class="pi pi-angle-right" aria-hidden="true" /></span>
  </RouterLink>
</template>
