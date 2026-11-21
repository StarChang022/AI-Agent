<script setup lang="ts">
/**
 * 詳情抽屜裡的「在垃圾桶中」提示（PRD 第 18 條：垃圾桶內不可編輯）。
 * 支出、收入從垃圾桶列表或網址開啟垃圾桶內的紀錄時顯示，抽屜改為唯讀。
 */
import Message from 'primevue/message'
</script>

<template>
  <Message severity="secondary" :closable="false" class="trashed-notice" :pt="{ root: { role: 'status' } }">
    <template #icon><i class="pi pi-trash" aria-hidden="true" /></template>
    這筆在垃圾桶中，還原後才能編輯或操作
  </Message>
</template>

<style scoped>
.trashed-notice {
  margin-bottom: var(--space-md);
}
</style>
