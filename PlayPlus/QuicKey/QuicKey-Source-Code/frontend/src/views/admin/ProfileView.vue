<script setup lang="ts">
/**
 * 個人設定（從頂欄頭像選單進入）：姓名、公司資訊（管理員）、通知偏好、修改密碼、重新開始新手導覽。
 * 帶 `?focus=company` 進入時（例如邀請員工前被提醒填公司名稱）自動聚焦公司名稱欄。
 * 通知偏好目前只存在這台瀏覽器（Prototype）。
 */
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import ToggleSwitch from 'primevue/toggleswitch'
import ProgressSpinner from 'primevue/progressspinner'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { getCompany, updateCompany, TAX_ID_RE } from '@/api/company'
import { updateMe } from '@/api/users'
import { HttpError } from '@/api/service'
import { ROLE_LABELS } from '@/constants/user'
import PageHeader from '@/components/PageHeader.vue'
import PasswordChangeDialog from '@/components/PasswordChangeDialog.vue'

const auth = useAuthStore()
const onboarding = useOnboardingStore()
const router = useRouter()
const route = useRoute()
const toast = useToast()

const name = ref(auth.currentUser?.name ?? '')
const nameError = ref('')
const passwordDialogVisible = ref(false)

const PREF_KEY = `quickey.prefs.${auth.currentUser?.id ?? 'guest'}`
function loadPrefs() {
  try {
    return { emailOnReview: true, budgetAlert: true, weeklyDigest: false, ...JSON.parse(localStorage.getItem(PREF_KEY) ?? '{}') }
  } catch {
    return { emailOnReview: true, budgetAlert: true, weeklyDigest: false }
  }
}
const prefs = reactive(loadPrefs())
watch(name, () => { nameError.value = '' })

const isAdmin = computed(() => auth.currentUser?.role === 'admin')
const companyName = ref('')
const taxId = ref('')
const taxIdError = ref('')
const companyLoading = ref(false)
watch(taxId, () => { taxIdError.value = '' })

function errorMessage(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { error?: string; details?: Record<string, string[]> } | undefined
    const first = body?.details && Object.values(body.details)[0]?.[0]
    return first ?? body?.error ?? err.message
  }
  return err instanceof Error ? err.message : String(err)
}

onMounted(async () => {
  if (isAdmin.value) {
    companyLoading.value = true
    try {
      const c = await getCompany()
      companyName.value = c.name ?? ''
      taxId.value = c.taxId ?? ''
    } catch (err) {
      toast.add({
        severity: 'error',
        summary: '載入公司資訊失敗',
        detail: errorMessage(err),
        life: 3000,
      })
    } finally {
      companyLoading.value = false
    }
  }
  if (route.query.focus === 'company' && isAdmin.value) {
    await nextTick()
    const el = document.getElementById('pf-company-name')
    el?.scrollIntoView({ block: 'center' })
    el?.focus()
  }
})

const saving = ref(false)
async function save() {
  const n = name.value.trim()
  if (!n) {
    nameError.value = '請填寫姓名'
    return
  }
  const t = taxId.value.trim()
  if (isAdmin.value && t && !TAX_ID_RE.test(t)) {
    taxIdError.value = '統一編號為 8 位數字'
    return
  }
  if (!auth.currentUser || saving.value) return
  saving.value = true
  try {
    // updateMe 內部已同步 auth.currentUser + localStorage，不用在這裡再 sync
    await updateMe({ name: n })
    if (isAdmin.value) {
      await updateCompany({ name: companyName.value.trim(), taxId: t || null })
    }
    try { localStorage.setItem(PREF_KEY, JSON.stringify(prefs)) } catch { /* ignore */ }
    toast.add({ severity: 'success', summary: '個人設定已儲存', life: 2500 })
  } catch (err) {
    // 統編檢核碼錯誤由後端 Company model 回 422（details.tax_id），歸位到欄位錯誤
    if (err instanceof HttpError && err.status === 422) {
      const details = (err.body as { details?: Record<string, string[]> })?.details
      if (details?.tax_id?.length) {
        taxIdError.value = '統一編號不正確'
        return
      }
    }
    toast.add({
      severity: 'error',
      summary: '儲存失敗',
      detail: errorMessage(err),
      life: 3000,
    })
  } finally {
    saving.value = false
  }
}

async function restartTour() {
  if (!auth.currentUser) return
  await onboarding.reset()
  router.push({ name: 'admin-dashboard' })
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="個人設定" size="admin" />

    <section class="dash-panel max-w-[640px] gap-4" aria-label="個人設定">
      <div class="dash-form-section">帳號資料</div>
      <div class="q-field max-w-[420px]">
        <label for="pf-name">姓名 <span class="req">*</span></label>
        <InputText id="pf-name" v-model="name" :invalid="!!nameError" aria-describedby="pf-name-err" />
        <span v-if="nameError" id="pf-name-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ nameError }}</span>
      </div>
      <div class="q-field max-w-[420px]">
        <label for="pf-email">Email</label>
        <InputText id="pf-email" :model-value="auth.currentUser?.email" disabled />
        <span class="q-help">Email 是登入帳號，無法修改</span>
      </div>
      <div class="dash-kv max-w-[420px]">
        <span>身分</span><b>{{ auth.currentUser ? ROLE_LABELS[auth.currentUser.role] : '—' }}</b>
      </div>

      <template v-if="isAdmin">
        <div class="dash-form-section pt-3 border-t border-[var(--color-hairline)]">公司資訊</div>
        <div v-if="companyLoading" class="flex items-center gap-2 text-sm text-[var(--color-slate)]" aria-live="polite">
          <ProgressSpinner style="width:1rem;height:1rem" stroke-width="4" aria-hidden="true" />
          載入中…
        </div>
        <template v-else>
          <div class="q-field max-w-[420px]">
            <label for="pf-company-name">公司名稱</label>
            <InputText id="pf-company-name" v-model="companyName" autocomplete="organization" aria-describedby="pf-company-name-help" />
            <span id="pf-company-name-help" class="q-help">員工收到的邀請會顯示公司名稱；邀請員工前需填寫</span>
          </div>
          <div class="q-field max-w-[420px]">
            <label for="pf-tax-id">統一編號</label>
            <InputText id="pf-tax-id" v-model="taxId" inputmode="numeric" maxlength="8" placeholder="8 位數字" :invalid="!!taxIdError" aria-describedby="pf-tax-id-err" />
            <span v-if="taxIdError" id="pf-tax-id-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ taxIdError }}</span>
          </div>
        </template>
      </template>

      <div class="dash-form-section pt-3 border-t border-[var(--color-hairline)]">通知</div>
      <label class="flex items-center gap-3 text-sm text-[var(--color-slate)]">
        <ToggleSwitch v-model="prefs.emailOnReview" />有新的請款待簽核時寄 Email 給我
      </label>
      <label class="flex items-center gap-3 text-sm text-[var(--color-slate)]">
        <ToggleSwitch v-model="prefs.budgetAlert" />類別預算使用超過 80% 時提醒我
      </label>
      <label class="flex items-center gap-3 text-sm text-[var(--color-slate)]">
        <ToggleSwitch v-model="prefs.weeklyDigest" />每週一寄送上週支出摘要
      </label>

      <div class="dash-form-section pt-3 border-t border-[var(--color-hairline)]">安全性</div>
      <div class="flex items-center justify-between max-w-[420px] text-sm text-[var(--color-slate)]">
        <span>密碼</span>
        <Button label="修改密碼" size="small" outlined @click="passwordDialogVisible = true" />
      </div>
      <div class="flex items-center justify-between max-w-[420px] text-sm text-[var(--color-slate)]">
        <span>新手導覽</span>
        <Button label="重新開始導覽" size="small" outlined @click="restartTour" />
      </div>

      <div class="form-foot pt-4 border-t border-[var(--color-hairline)]">
        <Button label="取消" outlined @click="router.back()" />
        <Button label="儲存" :loading="saving" @click="save" />
      </div>
    </section>

    <PasswordChangeDialog v-model:visible="passwordDialogVisible" />
  </div>
</template>
