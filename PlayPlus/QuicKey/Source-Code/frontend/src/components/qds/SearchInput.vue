<script setup lang="ts">
/** 工具列搜尋框（search-sm，高 44px）。見 design-system/design-layout-list.html */
defineProps<{ placeholder?: string; label?: string }>()
const model = defineModel<string>({ default: '' })
</script>

<template>
  <label class="search-sm">
    <i class="pi pi-search" aria-hidden="true" />
    <input v-model="model" type="search" :placeholder="placeholder" :aria-label="label ?? placeholder" />
  </label>
</template>
