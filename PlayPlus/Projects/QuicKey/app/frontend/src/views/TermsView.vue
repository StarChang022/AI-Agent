<script setup lang="ts">
import LogoHorizontal from '@/components/LogoHorizontal.vue'
</script>

<template>
  <main class="legal-page">
    <RouterLink to="/login" class="legal-brand" aria-label="回到登入頁">
      <LogoHorizontal :height="32" tone="dark" />
    </RouterLink>

    <article class="legal-panel">
      <p class="legal-kicker">Quickey</p>
      <h1>服務條款</h1>
      <p class="legal-lead">
        歡迎使用 Quickey。本服務協助企業整理日常收支、預算控管與審核流程，
        使用本服務即表示您同意以下條款。
      </p>

      <section>
        <h2>服務範圍</h2>
        <p>
          Quickey 提供支出紀錄、審核狀態、預算提醒與管理報表等工具，協助中小企業掌握日常資金流向。
          本服務不取代專業會計、稅務或法律顧問服務。
        </p>
      </section>

      <section>
        <h2>帳號與資料</h2>
        <p>
          您應妥善保管登入資訊，並確保輸入的資料正確、合法且已取得必要授權。
          若發現帳號遭未授權使用，請立即通知管理者。
        </p>
      </section>

      <section>
        <h2>使用限制</h2>
        <p>
          您不得以本服務從事非法用途、侵害他人權益、干擾系統運作，或嘗試未經授權存取其他帳號與資料。
        </p>
      </section>

      <section>
        <h2>條款更新</h2>
        <p>
          Quickey 可能依產品與法規需求調整本條款。重大更新將以適當方式通知，更新後繼續使用即表示您接受新版條款。
        </p>
      </section>

      <RouterLink to="/login" class="dash-back">
        <i class="pi pi-angle-left" aria-hidden="true"></i>
        <span>回到登入頁</span>
      </RouterLink>
    </article>
  </main>
</template>
