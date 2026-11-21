<script setup lang="ts">
import type { DemoCursor } from './useDemoScript'

defineProps<{ cursor: DemoCursor }>()
</script>

<template>
  <div
    class="mk-cursor"
    :class="{ 'is-pressed': cursor.pressed }"
    :style="{ transform: `translate(${cursor.x}px, ${cursor.y}px)`, opacity: cursor.visible ? 1 : 0 }"
    aria-hidden="true"
  >
    <svg viewBox="0 0 24 24" width="22" height="22">
      <path d="M5 3l14 8.5-6.2 1.6L9.6 19 5 3z" fill="#1a1f29" stroke="#ffffff" stroke-width="1.5" stroke-linejoin="round" />
    </svg>
    <span class="mk-ripple" />
  </div>
</template>
