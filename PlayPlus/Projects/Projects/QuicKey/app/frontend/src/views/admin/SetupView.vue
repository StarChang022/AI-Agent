<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useAuthStore } from '@/stores/auth'
import { updateMe } from '@/api/users'
import { HttpError } from '@/api/service'
import AuthShell from '@/components/AuthShell.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'

/**
 * 歡迎設定頁（`/admin/setup`，需登入、不套 AdminLayout）。
 *
 * 註冊時已一次填齊 Email / 密碼 / 公司資訊，驗證信連結點完後 router 導來這裡；
 * 本頁只收管理員姓名（必填）。完成後進儀表板，接著自動開始新手導覽。
 */

const router = useRouter()
const auth = useAuthStore()
const toast = useToast()

const form = reactive({
  name: auth.currentUser?.name ?? '',
})
const errors = reactive<{ name?: string }>({})
const submitting = ref(false)

function errorMessage(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { error?: string; details?: Record<string, string[]> } | undefined
    const first = body?.details && Object.values(body.details)[0]?.[0]
    return first ?? body?.error ?? err.message
  }
  return err instanceof Error ? err.message : String(err)
}

async function submit() {
  errors.name = form.name.trim() ? undefined : '請輸入姓名'
  if (errors.name) {
    document.getElementById('setup-name')?.focus()
    return
  }
  if (!auth.currentUser || submitting.value) return
  submitting.value = true
  try {
    await updateMe({ name: form.name.trim() })
    router.replace({ name: 'admin-dashboard' })
  } catch (err) {
    toast.add({
      severity: 'error',
      summary: '儲存失敗',
      detail: errorMessage(err),
      life: 3000,
    })
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthShell panel-label="歡迎設定">
    <div class="auth-brand">
      <h1 class="auth-title">歡迎使用 Quickey</h1>
      <p class="auth-caption">再填一項就能開始</p>
    </div>

    <form class="auth-form" novalidate @submit.prevent="submit">
      <div class="q-field">
        <label for="setup-name">你的姓名 <span class="req">*</span></label>
        <InputText
          id="setup-name"
          v-model="form.name"
          class="w-full"
          autocomplete="name"
          :invalid="!!errors.name"
          :aria-invalid="!!errors.name"
          aria-describedby="setup-name-msg"
          @input="errors.name = undefined"
        />
        <span
          v-if="errors.name"
          id="setup-name-msg"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.name
          }}
        </span>
        <span v-else id="setup-name-msg" class="q-help">
          會顯示在審核紀錄與員工收到的邀請中
        </span>
      </div>

      <Button
        type="submit"
        label="開始使用"
        class="w-full"
        :loading="submitting"
      />
    </form>
  </AuthShell>
</template>
