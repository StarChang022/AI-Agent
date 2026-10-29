<script setup lang="ts">
import { ref, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { changePassword } from '@/api/auth'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'
import { useToast } from 'primevue/usetoast'

/**
 * 修改密碼 Dialog。由 layout 掛載、header 下拉選單觸發。
 * 見 openspec add-employee-invitation-module design.md Decision 14 / user-profile spec。
 * 舊密碼比對在後端 bcrypt 做（401 → INVALID_OLD）；新密碼長度前端 pre-check，
 * 後端另有防禦性 TOO_SHORT 檢查。
 */

const props = defineProps<{ visible: boolean }>()
const emit = defineEmits<{ (e: 'update:visible', value: boolean): void }>()

const auth = useAuthStore()
const toast = useToast()

const oldPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const oldPasswordError = ref('')
const newPasswordError = ref('')
const confirmPasswordError = ref('')
const formError = ref('')
const submitting = ref(false)

function resetForm() {
  oldPassword.value = ''
  newPassword.value = ''
  confirmPassword.value = ''
  oldPasswordError.value = ''
  newPasswordError.value = ''
  confirmPasswordError.value = ''
  formError.value = ''
}

watch(
  () => props.visible,
  (open) => {
    if (open) resetForm()
  },
)

function close() {
  emit('update:visible', false)
}

function validateOldPassword(): string {
  // 舊密碼實際比對在後端做；這裡只擋空值
  if (!oldPassword.value) return '請輸入舊密碼'
  return ''
}

function validateNewPassword(): string {
  if (!newPassword.value) return '請設定新密碼'
  if (newPassword.value.length < 8) return '新密碼長度至少 8 碼'
  if (newPassword.value === oldPassword.value)
    return '新密碼不可與舊密碼相同'
  return ''
}

function validateConfirmPassword(): string {
  if (!confirmPassword.value) return '請再次輸入新密碼'
  if (newPassword.value !== confirmPassword.value) return '兩次輸入的新密碼不同'
  return ''
}

async function submit() {
  formError.value = ''
  if (!auth.currentUser) {
    formError.value = '尚未登入，無法修改密碼'
    return
  }
  oldPasswordError.value = validateOldPassword()
  newPasswordError.value = validateNewPassword()
  confirmPasswordError.value = validateConfirmPassword()
  if (
    oldPasswordError.value ||
    newPasswordError.value ||
    confirmPasswordError.value
  ) {
    return
  }
  submitting.value = true
  try {
    const result = await changePassword(oldPassword.value, newPassword.value)
    if (!result.ok) {
      switch (result.error) {
        case 'INVALID_OLD':
          oldPasswordError.value = '舊密碼不正確'
          break
        case 'TOO_SHORT':
          newPasswordError.value = '新密碼長度至少 8 碼'
          break
        default:
          formError.value = '更新密碼失敗，請稍後再試'
      }
      return
    }
    toast.add({
      severity: 'success',
      summary: '密碼已更新',
      life: 2500,
    })
    close()
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <Dialog
    :visible="visible"
    header="修改密碼"
    modal
    :dismissable-mask="true"
    :style="{ width: 'min(92vw, 420px)' }"
    @update:visible="close"
  >
    <form class="flex flex-col gap-4" novalidate @submit.prevent="submit">
      <div class="q-field">
        <label
          for="pwd-old"
        >
          舊密碼
        </label>
        <InputText
          id="pwd-old"
          autofocus
          v-model="oldPassword"
          type="password"
          class="w-full"
          autocomplete="current-password"
          :invalid="!!oldPasswordError"
          :aria-invalid="!!oldPasswordError"
          aria-describedby="pwd-old-error"
          @input="oldPasswordError = ''"
        />
        <p
          v-if="oldPasswordError"
          id="pwd-old-error"
          class="q-error"
          role="alert"
        >
          {{ oldPasswordError }}
        </p>
      </div>
      <div class="q-field">
        <label
          for="pwd-new"
        >
          新密碼
        </label>
        <InputText
          id="pwd-new"
          v-model="newPassword"
          type="password"
          class="w-full"
          autocomplete="new-password"
          placeholder="至少 8 碼"
          :invalid="!!newPasswordError"
          :aria-invalid="!!newPasswordError"
          aria-describedby="pwd-new-error"
          @input="newPasswordError = ''"
        />
        <p
          v-if="newPasswordError"
          id="pwd-new-error"
          class="q-error"
          role="alert"
        >
          {{ newPasswordError }}
        </p>
      </div>
      <div class="q-field">
        <label
          for="pwd-confirm"
        >
          再次輸入新密碼
        </label>
        <InputText
          id="pwd-confirm"
          v-model="confirmPassword"
          type="password"
          class="w-full"
          autocomplete="new-password"
          :invalid="!!confirmPasswordError"
          :aria-invalid="!!confirmPasswordError"
          aria-describedby="pwd-confirm-error"
          @input="confirmPasswordError = ''"
        />
        <p
          v-if="confirmPasswordError"
          id="pwd-confirm-error"
          class="q-error"
          role="alert"
        >
          {{ confirmPasswordError }}
        </p>
      </div>
      <Message v-if="formError" severity="error" :closable="false">
        {{ formError }}
      </Message>
      <div class="flex justify-end gap-2 pt-1">
        <Button type="button" label="取消" outlined @click="close" />
        <Button type="submit" label="更新密碼" :loading="submitting" />
      </div>
    </form>
  </Dialog>
</template>
