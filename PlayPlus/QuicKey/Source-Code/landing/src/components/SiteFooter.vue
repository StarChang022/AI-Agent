<script setup lang="ts">
import { RouterLink } from 'vue-router'
import { CONTACT_EMAIL, LINE_ID, LINE_URL } from '../config'
</script>

<template>
  <footer class="site-footer">
    <div class="container-page footer-grid">
      <div class="footer-main">
        <RouterLink to="/" class="footer-brand" aria-label="QUICKEY 首頁">
          <img src="/brand/logo-horizontal.svg" alt="QUICKEY" class="footer-logo" />
        </RouterLink>
        <p class="footer-sub">讓收支紀錄更簡單，讓財務管理更輕鬆。</p>

        <nav class="footer-nav" aria-label="頁尾導覽">
          <div>
            <p class="footer-nav-title">探索</p>
            <ul>
              <li><RouterLink to="/about">關於我們</RouterLink></li>
              <li><RouterLink to="/pricing">方案價格</RouterLink></li>
              <li><RouterLink to="/faq">常見問題</RouterLink></li>
              <li><RouterLink to="/blog">部落格</RouterLink></li>
            </ul>
          </div>
          <div>
            <p class="footer-nav-title">支援</p>
            <ul>
              <li><RouterLink to="/contact">聯絡我們</RouterLink></li>
              <li><RouterLink to="/privacy">隱私權政策</RouterLink></li>
              <li><RouterLink to="/terms">服務條款</RouterLink></li>
            </ul>
          </div>
        </nav>
      </div>

      <div class="footer-aside">
        <ul class="footer-contact">
          <li><a :href="LINE_URL" target="_blank" rel="noopener">LINE {{ LINE_ID }}</a></li>
          <li><a :href="`mailto:${CONTACT_EMAIL}`">{{ CONTACT_EMAIL }}</a></li>
        </ul>
        <p class="footer-copy">© 2026 QUICKEY. All rights reserved.</p>
      </div>
    </div>
  </footer>
</template>
