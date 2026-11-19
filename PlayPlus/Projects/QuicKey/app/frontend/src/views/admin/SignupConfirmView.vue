<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { logout as apiLogout, persistSession, signupComplete } from '@/api/auth'
import { HttpError } from '@/api/service'
import AuthShell from '@/components/AuthShell.vue'
import Button from 'primevue/button'
import Message from 'primevue/message'
import ProgressSpinner from 'primevue/progressspinner'
import { useToast } from 'primevue/usetoast'

/**
 * Email 驗證連結落地頁（public route `/admin/signup/confirm?token=`）。
 *
 * 進頁即消耗 token：後端從 SignupToken 讀出密碼與公司資訊，建立 Company + admin User
 * 回 JWT；本頁 persistSession 後自動登入並進入歡迎設定頁補姓名（router guard 保護）。
 * 已登入身分開啟時提示先登出，不自動登出（同邀請接受頁）。
 */

type ConfirmError = 'NO_TOKEN' | 'INVALID_OR_EXPIRED' | 'VALIDATION' | 'UNKNOWN'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const toast = useToast()

const token = computed(() =>
  typeof route.query.token === 'string' ? route.query.token : '',
)

const error = ref<ConfirmError | null>(null)

const MESSAGES: Record<ConfirmError, string> = {
  NO_TOKEN: '驗證連結無效，請確認連結是否完整。',
  INVALID_OR_EXPIRED: '驗證連結已失效或已過期（有效期限 30 分鐘），請回註冊頁重新填寫。',
  VALIDATION: '資料驗證失敗，請回註冊頁重新填寫。',
  UNKNOWN: '註冊失敗，請稍後再試。',
}

async function run() {
  error.value = null
  if (!token.value) {
    error.value = 'NO_TOKEN'
    return
  }
  try {
    const res = await signupComplete({ token: token.value })
    const user = {
      id: res.user.id,
      name: res.user.name,
      email: res.user.email,
      role: res.user.role,
      status: res.user.status,
      createdAt: '',
      onboardingCompletedAt: res.user.onboardingCompletedAt,
    }
    persistSession(res.token, user)
    toast.add({
      severity: 'success',
      summary: '註冊完成',
      detail: '歡迎使用 Quickey',
      life: 3500,
    })
    router.replace({ name: 'admin-setup' })
  } catch (err) {
    if (err instanceof HttpError) {
      if (err.status === 400) error.value = 'INVALID_OR_EXPIRED'
      else if (err.status === 422) error.value = 'VALIDATION'
      else error.value = 'UNKNOWN'
    } else {
      error.value = 'UNKNOWN'
    }
  }
}

onMounted(() => {
  if (!auth.isLoggedIn) run()
})

function handleLogout() {
  apiLogout()
  run()
}
</script>

<template>
  <AuthShell panel-label="Email 驗證">
    <div class="auth-brand">
      <h1 class="auth-title">Email 驗證</h1>
    </div>

    <div v-if="auth.isLoggedIn" class="auth-form">
      <Message severity="warn" :closable="false">
        目前已登入為
        <span class="font-medium">{{ auth.currentUser?.email }}</span>
        ，請先登出再完成新帳號的驗證。
      </Message>
      <Button
        label="登出並繼續驗證"
        severity="secondary"
        outlined
        class="w-full"
        @click="handleLogout"
      />
    </div>

    <div v-else-if="error" class="auth-form">
      <Message severity="error" :closable="false">
        {{ MESSAGES[error] }}
      </Message>
      <RouterLink
        :to="{ name: 'admin-signup' }"
        class="block w-full text-center py-2 px-4 rounded-md bg-primary-700 text-white hover:bg-primary-800 text-sm"
      >
        重新註冊
      </RouterLink>
    </div>

    <div v-else class="flex flex-col items-center gap-3 py-6" role="status">
      <ProgressSpinner style="width:2rem;height:2rem" stroke-width="4" aria-hidden="true" />
      <p class="text-sm text-[var(--color-muted)]">
        驗證中…
      </p>
    </div>
  </AuthShell>
</template>
