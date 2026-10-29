<script setup lang="ts">
import { ref } from 'vue'
import { forgotPassword } from '@/api/auth'
import LogoMark from '@/components/LogoMark.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'

const email = ref('')
const submitted = ref(false)
const submitting = ref(false)

async function handleSubmit() {
  if (submitting.value || submitted.value) return
  submitting.value = true
  try {
    await forgotPassword(email.value.trim())
    submitted.value = true
  } finally {
    submitting.value = false
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
              />
            </div>
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
            若該 Email 已註冊，則會收到重設連結Email，請至信箱查看。
            連結 30 分鐘內有效。
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
