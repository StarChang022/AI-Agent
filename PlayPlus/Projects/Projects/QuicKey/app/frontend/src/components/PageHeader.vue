<script setup lang="ts">
/**
 * 頁首。
 * - admin：後台頁首（dash-page-head）— 標題 20/600，右側放主要動作；可加「返回」連結；不放副標題
 * - front：員工前台，與後台同樣式（不再使用 sticky 白條），下方間距較大
 */
import type { RouteLocationRaw } from 'vue-router'

withDefaults(
  defineProps<{
    title: string
    size?: 'front' | 'admin'
    back?: RouteLocationRaw
    backLabel?: string
  }>(),
  {
    size: 'front',
    back: undefined,
    backLabel: '返回列表',
  },
)
</script>

<template>
  <!-- 前台與後台共用同一種頁首：標題放在灰色頁面背景上，右側放動作（設計系統「頁首」） -->
  <div class="dash-page-head" :class="{ 'is-front': size === 'front' }">
    <div class="min-w-0">
      <RouterLink v-if="back" :to="back" class="dash-back">
        <i class="pi pi-chevron-left text-xs" aria-hidden="true" /><span>{{ backLabel }}</span>
      </RouterLink>
      <h1 class="dash-page-title" tabindex="-1">{{ title }}</h1>
    </div>
    <div v-if="$slots.actions" class="dash-page-actions">
      <slot name="actions" />
    </div>
  </div>
</template>
