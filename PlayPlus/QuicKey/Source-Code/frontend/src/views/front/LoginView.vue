<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { login, logout } from '@/api/auth'
import LogoHorizontal from '@/components/LogoHorizontal.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'
import { useToast } from 'primevue/usetoast'

const email = ref('')
const password = ref('')
const errorMsg = ref('')
const submitting = ref(false)
const auth = useAuthStore()
const router = useRouter()
const toast = useToast()

// 已登入卻走到前台登入頁（例如 PWA 舊 manifest 還把 start_url 指向 /）→ 直接進 app
onMounted(() => {
  if (auth.isLoggedIn && auth.role !== 'admin') {
    router.replace({ name: 'front-home' })
  }
})

async function handleLogin() {
  if (submitting.value) return
  errorMsg.value = ''
  submitting.value = true
  try {
    const user = await login(email.value.trim(), password.value)
    if (!user) {
      errorMsg.value = 'Email 或密碼錯誤'
      return
    }
    if (user.role === 'admin') {
      errorMsg.value = '管理員請至後台登入'
      logout()
      return
    }
    router.push({ name: 'front-home' })
  } catch {
    errorMsg.value = '登入失敗，請稍後再試'
  } finally {
    submitting.value = false
  }
}

function requestRegistration() {
  toast.add({
    severity: 'info',
    summary: '註冊帳號',
    detail: '請向公司管理員索取 Quickey 邀請連結。',
    life: 3500,
  })
}

</script>

<template>
  <div class="auth-shell">
    <main class="auth-card">
      <section class="auth-visual" aria-label="Quickey 產品介紹">
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

      <section class="auth-form-panel" aria-label="人員前台登入">
        <div class="auth-form-inner">
          <div class="auth-brand">
            <h1 class="auth-title">登入 Quickey</h1>
          </div>

          <form class="auth-form" @submit.prevent="handleLogin">
            <div class="q-field">
              <label>Email</label>
              <InputText
                v-model="email"
                type="email"
                class="w-full"
                placeholder="ming@example.com"
                required
              />
            </div>
            <div class="q-field">
              <label>密碼</label>
              <InputText
                v-model="password"
                type="password"
                class="w-full"
                placeholder="password123"
                required
              />
            </div>
            <Message v-if="errorMsg" severity="error" :closable="false">
              {{ errorMsg }}
            </Message>
            <Button type="submit" label="登入" class="w-full" :loading="submitting" />
          </form>

          <div class="auth-links" aria-label="帳號協助">
            <button type="button" class="link-btn" @click="requestRegistration">
              註冊帳號
            </button>
            <span aria-hidden="true">|</span>
            <RouterLink to="/forgot-password" class="link-btn">
              忘記密碼？
            </RouterLink>
          </div>

          <p class="auth-legal">
            繼續操作即表示您同意本站的
            <RouterLink to="/terms">服務條款</RouterLink>
            及
            <RouterLink to="/privacy">隱私權政策</RouterLink>
          </p>

          <div class="auth-demo">
            <div class="mb-1">
              <b> 測試帳號（密碼皆為 <code>password123</code>） </b>
            </div>
            <ul class="space-y-0.5">
              <li>ming@example.com — 一般人員</li>
              <li>zhang@example.com — 一般人員</li>
            </ul>
            <div class="mt-3">
              後台入口
              <RouterLink
                to="/admin/login"
                class="text-primary-700 hover:underline"
              >
                /admin/login
              </RouterLink>
            </div>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>
