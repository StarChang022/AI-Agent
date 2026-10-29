<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { resetPassword } from '@/api/auth'
import { useToast } from 'primevue/usetoast'
import LogoMark from '@/components/LogoMark.vue'
import Button from 'primevue/button'
import Password from 'primevue/password'
import Message from 'primevue/message'

const route = useRoute()
const router = useRouter()
const toast = useToast()

// URL query token；缺 token 顯示錯誤畫面。
const rawToken = computed(() => {
  const q = route.query.token
  return typeof q === 'string' ? q : ''
})

const newPassword = ref('')
const confirmPassword = ref('')
const errorMsg = ref('')
const submitting = ref(false)

const isMismatch = computed(
  () => confirmPassword.value.length > 0 && newPassword.value !== confirmPassword.value,
)
const isTooShort = computed(
  () => newPassword.value.length > 0 && newPassword.value.length < 8,
)

async function handleSubmit() {
  if (submitting.value) return
  errorMsg.value = ''

  if (isTooShort.value) {
    errorMsg.value = '密碼長度至少 8 個字元'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    errorMsg.value = '兩次輸入的密碼不一致'
    return
  }

  submitting.value = true
  const result = await resetPassword(rawToken.value, newPassword.value)
  submitting.value = false

  if (!result.ok) {
    errorMsg.value =
      result.error === 'INVALID_OR_EXPIRED'
        ? '連結無效或已過期，請重新申請'
        : result.error === 'TOO_SHORT'
          ? '密碼長度至少 8 個字元'
          : '重設失敗，請稍後再試'
    return
  }

  toast.add({
    severity: 'success',
    summary: '密碼已重設',
    life: 3500,
  })
  router.replace({
    name: result.user.role === 'admin' ? 'admin-dashboard' : 'front-home',
  })
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-[var(--color-surface)]">
    <main class="flex-1 flex justify-center px-4 pt-12 pb-8">
      <div class="w-full max-w-sm">
        <div class="mb-8 text-center flex flex-col items-center">
          <div
            class="w-20 h-20 rounded-2xl bg-primary-500 flex items-center justify-center mb-4"
          >
            <LogoMark :size="56" />
          </div>
          <div class="text-3xl font-bold text-primary-600 tracking-tight">
            Quickey
          </div>
          <h1 class="text-xl font-semibold text-[var(--color-ink)] mt-4 mb-1">
            重設密碼
          </h1>
          <p v-if="rawToken" class="text-sm text-[var(--color-muted)]">
            請設定新的登入密碼（至少 8 個字元）。
          </p>
        </div>

        <template v-if="!rawToken">
          <Message severity="error" :closable="false">
            連結無效或已過期，請至「忘記密碼」重新申請。
          </Message>
          <div class="mt-6 text-center text-xs">
            <RouterLink to="/forgot-password" class="text-primary-600 hover:underline">
              前往忘記密碼
            </RouterLink>
          </div>
        </template>

        <template v-else>
          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div>
              <label
                for="new-password"
                class="text-sm text-[var(--color-ink)] mb-1 block"
              >
                新密碼
              </label>
              <Password
                input-id="new-password"
                v-model="newPassword"
                toggle-mask
                :feedback="false"
                class="w-full"
                input-class="w-full"
                autocomplete="new-password"
                required
              />
              <p
                v-if="isTooShort"
                class="text-xs text-[var(--color-danger)] mt-1"
              >
                至少 8 個字元
              </p>
            </div>
            <div>
              <label
                for="confirm-password"
                class="text-sm text-[var(--color-ink)] mb-1 block"
              >
                確認新密碼
              </label>
              <Password
                input-id="confirm-password"
                v-model="confirmPassword"
                toggle-mask
                :feedback="false"
                class="w-full"
                input-class="w-full"
                autocomplete="new-password"
                required
              />
              <p
                v-if="isMismatch"
                class="text-xs text-[var(--color-danger)] mt-1"
              >
                兩次輸入的密碼不一致
              </p>
            </div>
            <Message v-if="errorMsg" severity="error" :closable="false">
              {{ errorMsg }}
            </Message>
            <Button
              type="submit"
              label="重設密碼"
              class="w-full"
              :loading="submitting"
              :disabled="!newPassword || !confirmPassword"
            />
          </form>
        </template>

        <div
          class="mt-8 pt-6 border-t border-[var(--color-hairline)] text-xs text-[var(--color-muted)] leading-relaxed text-center"
        >
          <RouterLink to="/login" class="text-primary-600 hover:underline">
            返回登入
          </RouterLink>
        </div>
      </div>
    </main>
  </div>
</template>
