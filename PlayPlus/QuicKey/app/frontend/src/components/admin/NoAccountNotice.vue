<script setup lang="ts">
/**
 * 帳戶不足時的入口提示（PRD 第 20 條）：說明為何不能操作，附前往帳戶設定的連結。
 * 收支、固定收支、匯入、簽核通過用預設文案；資金移轉傳入「至少需要兩個帳戶」。
 */
import { RouterLink } from 'vue-router'
import Message from 'primevue/message'

withDefaults(defineProps<{ title?: string; detail?: string }>(), {
  title: '請先建立帳戶',
  detail: '每筆收支都要指定收付帳戶，公司建立帳戶後才能新增。',
})
</script>

<template>
  <Message
    severity="warn"
    :closable="false"
    :pt="{ root: { role: 'status', 'aria-live': 'polite' } }"
  >
    <div class="no-account-notice">
      <span><b>{{ title }}</b>：{{ detail }}</span>
      <RouterLink :to="{ name: 'admin-accounts' }" class="link-btn">前往帳戶設定</RouterLink>
    </div>
  </Message>
</template>

<style scoped>
.no-account-notice {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-xs) var(--space-md);
}
.no-account-notice b {
  font-weight: 600;
}
.no-account-notice .link-btn {
  font-size: inherit;
}
</style>
