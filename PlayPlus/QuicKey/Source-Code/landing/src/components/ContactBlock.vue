<script setup lang="ts">
import { CONTACT_EMAIL, LINE_ID, LINE_URL } from '../config'
</script>

<template>
  <section id="contact" class="section section-alt">
    <div class="container-page contact-split">
      <div>
        <p class="eyebrow">聯絡我們</p>
        <h2 class="section-title" style="margin-top: 8px">有問題，隨時找我們聊聊</h2>
        <p class="lead" style="margin-top: 16px">透過 LINE 或 Email 都可以，我們會盡快回覆你。</p>
      </div>

      <div>
        <div class="contact-row">
          <div>
            <h3>LINE 官方帳號</h3>
            <p>ID：{{ LINE_ID }}</p>
          </div>
          <a :href="LINE_URL" class="btn-primary btn-sm" target="_blank" rel="noopener">加入 LINE</a>
        </div>
        <div class="contact-row">
          <div>
            <h3>Email</h3>
            <p>{{ CONTACT_EMAIL }}</p>
          </div>
          <a :href="`mailto:${CONTACT_EMAIL}`" class="btn-ghost btn-sm">寄信給我們</a>
        </div>
      </div>
    </div>
  </section>
</template>
