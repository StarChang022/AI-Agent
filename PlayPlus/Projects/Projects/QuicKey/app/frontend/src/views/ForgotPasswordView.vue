<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { forgotPassword } from '@/api/auth'
import LogoMark from '@/components/LogoMark.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'

const email = ref('')
const submitted = ref(false)
const submitting = ref(false)
/** Email 欄位下方的錯誤（查無此帳號） */
const emailError = ref('')
/** 表單層級的錯誤（帳號已停用、其他失敗） */
const errorMsg = ref('')

async function handleSubmit() {
  if (submitting.value || submitted.value) return
  emailError.value = ''
  errorMsg.value = ''
  submitting.value = true
  const result = await forgotPassword(email.value.trim())
  submitting.value = false

  if (result.ok) {
    submitted.value = true
    return
  }
  if (result.error === 'NOT_FOUND') {
    emailError.value = '查無此帳號，請確認 Email 是否正確'
    await nextTick()
    document.getElementById('forgot-email')?.focus()
  } else if (result.error === 'SUSPENDED') {
    errorMsg.value = '此帳號已停用，請聯絡公司管理員'
  } else {
    errorMsg.value = '送出失敗，請稍後再試'
  }
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
            忘記密碼
          </h1>
          <p class="text-sm text-[var(--color-muted)]">
            輸入註冊 Email，我們會寄送重設密碼連結。
          </p>
        </div>

        <template v-if="!submitted">
          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div>
              <label
                for="forgot-email"
                class="text-sm text-[var(--color-ink)] mb-1 block"
              >
                Email
              </label>
              <InputText
                id="forgot-email"
                v-model="email"
                type="email"
                class="w-full"
                placeholder="you@example.com"
                required
                autocomplete="email"
                :invalid="!!emailError"
                :aria-invalid="!!emailError"
                :aria-describedby="emailError ? 'forgot-email-error' : undefined"
              />
              <p
                v-if="emailError"
                id="forgot-email-error"
                class="text-sm text-[var(--color-danger)] mt-1"
                role="alert"
              >
                {{ emailError }}
              </p>
            </div>
            <Message v-if="errorMsg" severity="error" :closable="false">
              {{ errorMsg }}
            </Message>
            <Button
              type="submit"
              label="送出"
              class="w-full"
              :loading="submitting"
              :disabled="!email.trim()"
            />
          </form>
        </template>

        <template v-else>
          <Message severity="success" :closable="false">
            重設密碼信已寄出，請至信箱查看。連結 30 分鐘內有效。
          </Message>
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
