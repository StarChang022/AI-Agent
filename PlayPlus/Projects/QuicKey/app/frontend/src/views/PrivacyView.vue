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
      <h1>隱私權政策</h1>
      <p class="legal-lead">
        Quickey 重視您的資料安全與隱私。本政策說明我們如何處理與保護您在使用服務時提供的資訊。
      </p>

      <section>
        <h2>我們收集的資料</h2>
        <p>
          我們可能收集帳號資料、公司資料、支出紀錄、審核紀錄、操作紀錄，以及提供服務所需的技術資訊。
        </p>
      </section>

      <section>
        <h2>資料使用方式</h2>
        <p>
          資料將用於提供收支管理、預算提醒、審核流程、系統維護、安全防護與產品改善。
          未經授權，我們不會將您的企業資料出售給第三方。
        </p>
      </section>

      <section>
        <h2>資料保護</h2>
        <p>
          我們採取合理的技術與管理措施保護資料安全，並限制只有必要人員或授權使用者能存取相關資訊。
        </p>
      </section>

      <section>
        <h2>您的權利</h2>
        <p>
          您可依公司權限與適用法規，請求查閱、修正或刪除個人資料。若需協助，請聯絡系統管理者。
        </p>
      </section>

      <RouterLink to="/login" class="dash-back">
        <i class="pi pi-angle-left" aria-hidden="true"></i>
        <span>回到登入頁</span>
      </RouterLink>
    </article>
  </main>
</template>
