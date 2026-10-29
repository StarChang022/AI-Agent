<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { LOGIN_URL, SIGNUP_URL } from '../config'

const open = ref(false)
// 向下捲動時隱藏，向上捲動時顯示；頂部、選單開啟或焦點在導覽列內時一律顯示
const hidden = ref(false)
let lastY = 0
const HIDE_AFTER = 80

function onScroll() {
  const y = window.scrollY
  if (open.value || y <= HIDE_AFTER) {
    hidden.value = false
  } else if (y > lastY) {
    hidden.value = true
  } else if (y < lastY) {
    hidden.value = false
  }
  lastY = y
}
function showHeader() {
  hidden.value = false
}
onMounted(() => {
  lastY = window.scrollY
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))
const toggleLabel = computed(() => (open.value ? '關閉選單' : '開啟選單'))
const links = [
  { to: '/about', label: '關於我們' },
  { to: '/pricing', label: '方案價格' },
  { to: '/faq', label: '常見問題' },
  { to: '/blog', label: '部落格' },
  { to: '/contact', label: '聯絡我們' },
]
</script>

<template>
  <header :class="['site-header', { 'is-hidden': hidden }]" @focusin="showHeader">
    <div class="container-page">
      <RouterLink to="/" class="brand" aria-label="QUICKEY 首頁">
        <img src="/brand/logo-horizontal.svg" alt="QUICKEY" class="brand-logo" />
      </RouterLink>

      <button
        type="button"
        class="menu-toggle"
        :aria-label="toggleLabel"
        :aria-expanded="open"
        aria-controls="site-nav"
        @click="open = !open; showHeader()"
      >
        <span aria-hidden="true">{{ open ? '✕' : '☰' }}</span>
      </button>

      <nav id="site-nav" aria-label="主選單" :class="['site-nav', { 'is-open': open }]" @click="open = false">
        <RouterLink v-for="link in links" :key="link.to" :to="link.to" class="nav-link">
          {{ link.label }}
        </RouterLink>
        <div class="auth-actions">
          <a :href="LOGIN_URL" class="btn-ghost btn-sm">登入</a>
          <a :href="SIGNUP_URL" class="btn-primary btn-sm">註冊</a>
        </div>
      </nav>
    </div>
  </header>
</template>

<style scoped>
/* 右上角：登入（次要）與註冊（主要）*/
.auth-actions {
  display: flex;
  gap: 8px;
}
.auth-actions a {
  white-space: nowrap;
}
.auth-actions .btn-ghost,
.auth-actions .btn-primary {
  min-height: 40px;
  padding: 0 20px;
  font-size: 16px;
}
@media (max-width: 767.98px) {
  .auth-actions {
    width: 100%;
    margin-top: 8px;
  }
  .auth-actions a {
    flex: 1;
    justify-content: center;
  }
}
@media (min-width: 768px) {
  .auth-actions {
    margin-left: 12px;
  }
}
</style>
