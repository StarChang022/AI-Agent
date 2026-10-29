<script setup lang="ts">
import SiteHeader from './components/SiteHeader.vue'
import SiteFooter from './components/SiteFooter.vue'
</script>

<template>
  <a href="#main" class="skip-link">跳到主要內容</a>
  <SiteHeader />
  <main id="main" tabindex="-1" class="min-h-[60vh]">
    <RouterView />
  </main>
  <SiteFooter />
</template>
