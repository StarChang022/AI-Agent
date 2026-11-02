<script setup lang="ts">
import LogoHorizontal from '@/components/LogoHorizontal.vue'

/**
 * 後台驗證類頁面共用外框（登入、註冊公司帳號、Email 驗證）。
 * 左側品牌視覺、右側表單區；表單區內容由 default slot 提供。
 */
defineProps<{
  /** 右側表單區的 aria-label */
  panelLabel: string
}>()
</script>

<template>
  <div class="auth-shell">
    <main class="auth-card">
      <section class="auth-visual" aria-label="Quickey 後台介紹">
        <div class="auth-visual-brand">
          <LogoHorizontal :height="34" tone="light" />
        </div>
        <div class="auth-visual-message">
          <div class="auth-visual-tag">你的收支管理專家</div>
          <h2 class="auth-visual-title">快速建立中小企業收支帳簿</h2>
          <p class="auth-visual-copy">
            掌握錢花到哪裡、誰花的、有沒有超預算，讓審核進度不再卡住。
          </p>
        </div>
      </section>

      <section class="auth-form-panel" :aria-label="panelLabel">
        <div class="auth-form-inner">
          <slot />
        </div>
      </section>
    </main>
  </div>
</template>
