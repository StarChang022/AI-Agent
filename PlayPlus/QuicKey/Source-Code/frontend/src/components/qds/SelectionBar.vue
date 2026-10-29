<script setup lang="ts">
/** 批次操作列：左邊已選數量＋取消選取，右邊批次動作（主要動作最右）。見 design-system/design-layout-list.html */
defineProps<{ count: number; summary?: string }>()
defineEmits<{ clear: [] }>()
</script>

<template>
  <div class="selection-bar" role="region" aria-label="批次操作">
    <span class="sel-count">已選 {{ count }} 筆{{ summary ? '，' + summary : '' }}</span>
    <button type="button" class="link-btn sel-clear" @click="$emit('clear')">取消選取</button>
    <!-- 動作一律靠右，主要動作放最右邊 -->
    <span class="sel-actions"><slot /></span>
  </div>
</template>
