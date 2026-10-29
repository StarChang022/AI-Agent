<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import { useAuthStore } from '@/stores/auth'
import { logout, signupRequest } from '@/api/auth'
import { checkCompanyExists, TAX_ID_RE } from '@/api/company'
import { HttpError } from '@/api/service'
import AuthShell from '@/components/AuthShell.vue'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'
import Select from 'primevue/select'

/**
 * 註冊公司帳號（public route `/admin/signup`）。
 *
 * 一次填齊：Email、密碼（單欄 + 顯示切換）、公司類型、公司名稱、統編（選填）、
 * 同意條款。送出前若填了統編，先打查重 API，命中就跳提示 dialog 讓使用者選擇
 * 返回修改或仍要繼續。驗證信連結點完後 SignupConfirmView 直接完成註冊，使用者
 * 不會再被要求輸入其他資料；姓名於歡迎設定頁補填。
 */

const SIGNUP_PASSWORD_MIN = 8
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

type CompanyType = 'limited' | 'studio'
const COMPANY_TYPE_OPTIONS: { label: string; value: CompanyType }[] = [
  { label: '公司', value: 'limited' },
  { label: '工作室', value: 'studio' },
]

const router = useRouter()
const auth = useAuthStore()
const confirm = useConfirm()
const toast = useToast()

const form = reactive({
  email: '',
  password: '',
  companyType: 'limited' as CompanyType,
  companyName: '',
  taxId: '',
  agreed: false,
})

type Field = 'email' | 'password' | 'companyName' | 'taxId' | 'agreed'
const errors = reactive<Partial<Record<Field, string>>>({})
const submitting = ref(false)
const showPassword = ref(false)

function validate(): Field | null {
  for (const k of Object.keys(errors) as Field[]) delete errors[k]

  const email = form.email.trim()
  if (!email) errors.email = '請輸入 Email'
  else if (!EMAIL_RE.test(email)) errors.email = 'Email 格式不正確'

  if (!form.password) errors.password = '請設定密碼'
  else if (form.password.length < SIGNUP_PASSWORD_MIN)
    errors.password = `密碼長度至少 ${SIGNUP_PASSWORD_MIN} 碼`

  if (!form.companyName.trim()) errors.companyName = '請填公司／工作室名稱'

  const taxId = form.taxId.trim()
  if (taxId && !TAX_ID_RE.test(taxId)) errors.taxId = '統一編號為 8 位數字'

  if (!form.agreed) errors.agreed = '請先同意服務條款與隱私權政策'

  const order: Field[] = ['email', 'password', 'companyName', 'taxId', 'agreed']
  return order.find((k) => errors[k]) ?? null
}

function focusField(field: Field) {
  document.getElementById(`signup-${field}`)?.focus()
}

function clear(field: Field) {
  delete errors[field]
}

const passwordInputType = computed(() => (showPassword.value ? 'text' : 'password'))

async function submit() {
  const bad = validate()
  if (bad) {
    focusField(bad)
    return
  }

  const taxId = form.taxId.trim()
  if (taxId) {
    try {
      const result = await checkCompanyExists(taxId)
      if (result.exists) {
        const confirmed = await askContinueOnDuplicate(result.matchedName)
        if (!confirmed) {
          focusField('taxId')
          return
        }
      }
    } catch (err) {
      toast.add({
        severity: 'error',
        summary: '統編查詢失敗',
        detail: err instanceof Error ? err.message : String(err),
        life: 3000,
      })
      return
    }
  }

  await doRequest()
}

function askContinueOnDuplicate(matchedName: string | null): Promise<boolean> {
  const detail = matchedName
    ? `系統偵測到相同的統一編號（${matchedName}），建議先向公司管理員確認是否已有帳號。`
    : '系統偵測到相同的統一編號，建議先向公司管理員確認是否已有帳號。'
  return new Promise((resolve) => {
    confirm.require({
      header: '統一編號已存在',
      message: `${detail}\n\n若繼續註冊，將建立獨立的帳務空間，原有帳務資料及訂閱方案皆不會共用或自動合併。`,
      icon: 'pi pi-exclamation-circle',
      acceptLabel: '仍要繼續註冊',
      rejectLabel: '返回修改',
      rejectProps: { outlined: true, severity: 'secondary' },
      accept: () => resolve(true),
      reject: () => resolve(false),
      onHide: () => resolve(false),
    })
  })
}

async function doRequest() {
  submitting.value = true
  try {
    await signupRequest({
      email: form.email.trim(),
      password: form.password,
      companyType: form.companyType,
      companyName: form.companyName.trim(),
      taxId: form.taxId.trim() || null,
    })
    router.push({
      name: 'admin-signup-verify',
      query: { email: form.email.trim() },
    })
  } catch (err) {
    toast.add({
      severity: 'error',
      summary: '註冊失敗',
      detail:
        err instanceof HttpError
          ? ((err.body as { error?: string })?.error ?? err.message)
          : err instanceof Error
            ? err.message
            : String(err),
      life: 3000,
    })
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthShell panel-label="註冊公司帳號">
    <div class="auth-brand">
      <h1 class="auth-title">註冊公司帳號</h1>
      <p class="auth-caption">免費開始使用，註冊者即為公司管理員</p>
    </div>

    <div v-if="auth.isLoggedIn" class="auth-form">
      <Message severity="warn" :closable="false">
        目前已登入為
        <span class="font-medium">{{ auth.currentUser?.email }}</span>
        ，請先登出再註冊新的公司帳號。
      </Message>
      <Button
        label="登出目前身分"
        severity="secondary"
        outlined
        class="w-full"
        @click="logout()"
      />
    </div>

    <form v-else class="auth-form" novalidate @submit.prevent="submit">
      <div class="q-field">
        <label for="signup-email">Email <span class="req">*</span></label>
        <InputText
          id="signup-email"
          v-model="form.email"
          type="email"
          class="w-full"
          autocomplete="email"
          placeholder="name@company.com"
          :invalid="!!errors.email"
          :aria-invalid="!!errors.email"
          aria-describedby="signup-email-msg"
          @input="clear('email')"
        />
        <span
          v-if="errors.email"
          id="signup-email-msg"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.email
          }}
        </span>
      </div>

      <div class="q-field">
        <label for="signup-password">密碼 <span class="req">*</span></label>
        <div class="relative">
          <InputText
            id="signup-password"
            v-model="form.password"
            :type="passwordInputType"
            class="w-full pr-10"
            autocomplete="new-password"
            placeholder="至少 8 碼"
            :invalid="!!errors.password"
            :aria-invalid="!!errors.password"
            aria-describedby="signup-password-err"
            @input="clear('password')"
          />
          <button
            type="button"
            class="absolute inset-y-0 right-0 flex items-center px-3 text-[var(--color-slate)] hover:text-[var(--color-ink)]"
            :aria-label="showPassword ? '隱藏密碼' : '顯示密碼'"
            :aria-pressed="showPassword"
            @click="showPassword = !showPassword"
          >
            <i
              :class="showPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"
              aria-hidden="true"
            />
          </button>
        </div>
        <span
          v-if="errors.password"
          id="signup-password-err"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.password
          }}
        </span>
      </div>

      <div class="q-field">
        <label for="signup-companyType">
          類型 <span class="req">*</span>
        </label>
        <Select
          id="signup-companyType"
          v-model="form.companyType"
          :options="COMPANY_TYPE_OPTIONS"
          option-label="label"
          option-value="value"
          class="w-full"
        />
      </div>

      <div class="q-field">
        <label for="signup-companyName">
          公司／工作室名稱 <span class="req">*</span>
        </label>
        <InputText
          id="signup-companyName"
          v-model="form.companyName"
          class="w-full"
          autocomplete="organization"
          :invalid="!!errors.companyName"
          :aria-invalid="!!errors.companyName"
          aria-describedby="signup-companyName-err"
          @input="clear('companyName')"
        />
        <span
          v-if="errors.companyName"
          id="signup-companyName-err"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.companyName
          }}
        </span>
      </div>

      <div class="q-field">
        <label for="signup-taxId">統一編號</label>
        <InputText
          id="signup-taxId"
          v-model="form.taxId"
          class="w-full"
          inputmode="numeric"
          maxlength="8"
          placeholder="8 位數字（選填）"
          :invalid="!!errors.taxId"
          :aria-invalid="!!errors.taxId"
          aria-describedby="signup-taxId-err"
          @input="clear('taxId')"
        />
        <span
          v-if="errors.taxId"
          id="signup-taxId-err"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.taxId
          }}
        </span>
      </div>

      <div class="q-field">
        <div class="flex items-start gap-2 text-sm text-[var(--color-ink)]">
          <Checkbox
            v-model="form.agreed"
            input-id="signup-agreed"
            :binary="true"
            :invalid="!!errors.agreed"
            :aria-invalid="!!errors.agreed"
            aria-describedby="signup-agreed-err"
            @update:model-value="clear('agreed')"
          />
          <label for="signup-agreed" class="cursor-pointer leading-6">
            我已閱讀並同意
            <RouterLink to="/terms" target="_blank" class="link-btn">
              服務條款
            </RouterLink>
            及
            <RouterLink to="/privacy" target="_blank" class="link-btn">
              隱私權政策
            </RouterLink>
          </label>
        </div>
        <span
          v-if="errors.agreed"
          id="signup-agreed-err"
          class="q-error"
          role="alert"
        >
          <i class="pi pi-exclamation-circle" aria-hidden="true" />{{
            errors.agreed
          }}
        </span>
      </div>

      <Button
        type="submit"
        label="註冊並寄送驗證信"
        class="w-full"
        :loading="submitting"
      />
    </form>

    <div class="auth-links">
      已有帳號？
      <RouterLink :to="{ name: 'admin-login' }" class="link-btn">
        登入後台
      </RouterLink>
    </div>
  </AuthShell>
</template>
