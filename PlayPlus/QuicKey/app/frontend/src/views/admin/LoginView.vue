<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { consumeSessionExpiredNotice, isAccountSuspended, login, logout } from '@/api/auth'
import AuthShell from '@/components/AuthShell.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'

const email = ref('')
const password = ref('')
const errorMsg = ref('')
/** 使用中登入失效被導回來時顯示一次 */
const expiredNotice = ref(consumeSessionExpiredNotice())
const submitting = ref(false)
const router = useRouter()
const route = useRoute()

/**
 * 登入前要去的頁面（由路由守衛或登入失效帶入）；只接受站內 /admin/、/app/ 開頭的路徑，避免被導到外站。
 * 管理員可進前台（切換到員工前台），所以 /app/ 也接受。
 */
function redirectTarget(): string | null {
  const r = route.query.redirect
  if (typeof r !== 'string' || !(r.startsWith('/admin/') || r.startsWith('/app/'))) return null
  return r
}

async function handleLogin() {
  if (submitting.value) return
  errorMsg.value = ''
  expiredNotice.value = false
  submitting.value = true
  try {
    const user = await login(email.value.trim(), password.value)
    if (!user) {
      errorMsg.value = 'Email 或密碼錯誤'
      return
    }
    if (user.role === 'employee') {
      errorMsg.value = '一般人員請至前台登入'
      logout()
      return
    }
    const target = redirectTarget()
    if (target) router.replace(target)
    else router.push({ name: 'admin-dashboard' })
  } catch (err) {
    errorMsg.value = isAccountSuspended(err) ? '此帳號已停用，請聯絡公司管理員' : '登入失敗，請稍後再試'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthShell panel-label="後台登入">
    <div class="auth-brand">
      <h1 class="auth-title">後台登入</h1>
    </div>

    <form class="auth-form" @submit.prevent="handleLogin">
      <div class="q-field">
        <label>Email</label>
        <InputText
          v-model="email"
          type="email"
          class="w-full"
          placeholder="zhang@example.com"
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
      <Message v-if="expiredNotice" severity="warn" :closable="false">登入已失效，請重新登入</Message>
      <Message v-if="errorMsg" severity="error" :closable="false">
        {{ errorMsg }}
      </Message>
      <Button type="submit" label="登入" class="w-full" :loading="submitting" />
    </form>

    <div class="auth-links" aria-label="帳號協助">
      <RouterLink :to="{ name: 'admin-signup' }" class="link-btn">
        註冊公司帳號
      </RouterLink>
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
        <li>admin@example.com — 管理員</li>
      </ul>
      <div class="mt-3">
        前台入口
        <RouterLink to="/login" class="text-primary-700 hover:underline">
          /login
        </RouterLink>
      </div>
    </div>
  </AuthShell>
</template>
