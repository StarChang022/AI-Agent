<script setup lang="ts">
/**
 * 設定（從頂欄頭像選單進入）：姓名、公司資訊與目前方案（管理員）、修改密碼、重新開始新手導覽。
 */
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from 'primevue/usetoast'
import { useConfirm } from 'primevue/useconfirm'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import ProgressSpinner from 'primevue/progressspinner'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { checkCompanyExists, getCompany, updateCompany, TAX_ID_RE, type CompanyPlan } from '@/api/company'
import { updateMe } from '@/api/users'
import { HttpError } from '@/api/service'
import { ROLE_LABELS } from '@/constants/user'
import { PLAN_LABELS } from '@/constants/plan'
import PageHeader from '@/components/PageHeader.vue'
import PasswordChangeDialog from '@/components/PasswordChangeDialog.vue'
import PlanTableDialog from '@/components/admin/PlanTableDialog.vue'

const auth = useAuthStore()
const onboarding = useOnboardingStore()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

const name = ref(auth.currentUser?.name ?? '')
const nameError = ref('')
const passwordDialogVisible = ref(false)

watch(name, () => { nameError.value = '' })

const isAdmin = computed(() => auth.currentUser?.role === 'admin')
const companyName = ref('')
const companyNameError = ref('')
const taxId = ref('')
/** 目前已儲存的統編；統編有改動時才查是否與其他公司重複，避免查到自己公司 */
const savedTaxId = ref('')
const taxIdError = ref('')
const plan = ref<CompanyPlan | null>(null)
const planDialogVisible = ref(false)
const companyLoading = ref(false)
watch(companyName, () => { companyNameError.value = '' })
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
      savedTaxId.value = taxId.value
      plan.value = c.plan
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
})

const saving = ref(false)
async function save() {
  const n = name.value.trim()
  if (!n) {
    nameError.value = '請填寫姓名'
    return
  }
  const c = companyName.value.trim()
  if (isAdmin.value && !c) {
    companyNameError.value = '請填寫公司名稱'
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
    // 統編改成新的值時，比照註冊頁檢查是否已有其他公司使用；查詢失敗就不儲存
    if (isAdmin.value && t && t !== savedTaxId.value) {
      let result
      try {
        result = await checkCompanyExists(t)
      } catch (err) {
        toast.add({
          severity: 'error',
          summary: '統編查詢失敗',
          detail: errorMessage(err),
          life: 3000,
        })
        return
      }
      if (result.exists && !(await askContinueOnDuplicate(result.matchedName))) {
        // 視窗關閉時會把焦點還給原本的儲存按鈕；等關閉這次畫面更新跑完再 focus，才不會被蓋掉
        await nextTick()
        document.getElementById('pf-tax-id')?.focus()
        return
      }
    }
    // updateMe 內部已同步 auth.currentUser + localStorage，不用在這裡再 sync
    await updateMe({ name: n })
    if (isAdmin.value) {
      await updateCompany({ name: c, taxId: t || null })
      savedTaxId.value = t
    }
    toast.add({ severity: 'success', summary: '設定已儲存', life: 2500 })
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

function askContinueOnDuplicate(matchedName: string | null): Promise<boolean> {
  const detail = matchedName
    ? `已有公司使用這個統一編號（${matchedName}），請確認統編是否正確。`
    : '已有公司使用這個統一編號，請確認統編是否正確。'
  return new Promise((resolve) => {
    confirm.require({
      header: '統一編號已存在',
      message: `${detail}\n\n若仍要儲存，兩家公司的帳務資料各自獨立，不會共用或合併。`,
      icon: 'pi pi-exclamation-circle',
      acceptLabel: '仍要儲存',
      rejectLabel: '返回修改',
      rejectProps: { outlined: true, severity: 'secondary' },
      accept: () => resolve(true),
      reject: () => resolve(false),
      onHide: () => resolve(false),
    })
  })
}

async function restartTour() {
  if (!auth.currentUser) return
  await onboarding.reset()
  router.push({ name: 'admin-dashboard' })
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="設定" size="admin" />

    <section class="dash-panel gap-4" aria-label="設定">
      <div class="dash-form-section">帳號資料</div>
      <div class="pf-grid">
        <div class="q-field">
          <label for="pf-name">姓名 <span class="req">*</span></label>
          <InputText id="pf-name" v-model="name" :invalid="!!nameError" aria-describedby="pf-name-err" />
          <span v-if="nameError" id="pf-name-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ nameError }}</span>
        </div>
        <div class="q-field">
          <label for="pf-email">Email</label>
          <InputText id="pf-email" :model-value="auth.currentUser?.email" disabled />
          <span class="q-help">Email 是登入帳號，無法修改</span>
        </div>
        <div class="dash-kv">
          <span>身分</span><b>{{ auth.currentUser ? ROLE_LABELS[auth.currentUser.role] : '—' }}</b>
        </div>
      </div>

      <template v-if="isAdmin">
        <div class="dash-form-section pt-3 border-t border-[var(--color-hairline)]">公司資訊</div>
        <div v-if="companyLoading" class="flex items-center gap-2 text-sm text-[var(--color-slate)]" aria-live="polite">
          <ProgressSpinner style="width:1rem;height:1rem" stroke-width="4" aria-hidden="true" />
          載入中…
        </div>
        <div v-else class="pf-grid">
          <div class="q-field">
            <label for="pf-company-name">公司名稱 <span class="req">*</span></label>
            <InputText id="pf-company-name" v-model="companyName" autocomplete="organization" :invalid="!!companyNameError" aria-describedby="pf-company-name-err pf-company-name-help" />
            <span v-if="companyNameError" id="pf-company-name-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ companyNameError }}</span>
            <span id="pf-company-name-help" class="q-help">員工收到的邀請會顯示公司名稱</span>
          </div>
          <div class="q-field">
            <label for="pf-tax-id">統一編號</label>
            <InputText id="pf-tax-id" v-model="taxId" inputmode="numeric" maxlength="8" placeholder="8 位數字" :invalid="!!taxIdError" aria-describedby="pf-tax-id-err" />
            <span v-if="taxIdError" id="pf-tax-id-err" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ taxIdError }}</span>
          </div>
          <div class="flex items-center justify-between gap-3 text-sm text-[var(--color-slate)]">
            <span>目前方案</span>
            <div class="flex items-center gap-1">
              <span v-if="plan" class="plan-tag">{{ PLAN_LABELS[plan] ?? plan }}</span>
              <Button
                type="button"
                icon="pi pi-info-circle"
                text
                rounded
                size="small"
                aria-label="查看方案"
                aria-haspopup="dialog"
                v-tooltip.top="'查看方案'"
                @click="planDialogVisible = true"
              />
            </div>
          </div>
        </div>
      </template>

      <div class="dash-form-section pt-3 border-t border-[var(--color-hairline)]">安全性</div>
      <!-- 兩列上下排，寬度對齊上方左欄（電腦版不拉滿整頁，按鈕才不會離文字太遠） -->
      <div class="pf-grid">
        <div class="flex flex-col gap-4">
          <div class="flex items-center justify-between text-sm text-[var(--color-slate)]">
            <span>密碼</span>
            <Button label="修改密碼" size="small" outlined @click="passwordDialogVisible = true" />
          </div>
          <div class="flex items-center justify-between text-sm text-[var(--color-slate)]">
            <span>新手導覽</span>
            <Button label="重新開始導覽" size="small" outlined @click="restartTour" />
          </div>
        </div>
      </div>

      <div class="form-foot pt-4 border-t border-[var(--color-hairline)]">
        <Button label="取消" outlined @click="router.back()" />
        <Button label="儲存" :loading="saving" @click="save" />
      </div>
    </section>

    <PasswordChangeDialog v-model:visible="passwordDialogVisible" />
    <PlanTableDialog v-if="isAdmin" v-model:visible="planDialogVisible" :current-plan="plan" />
  </div>
</template>

<style scoped>
/* 電腦版兩欄並排、手機一欄；欄距 24px、列距 16px（design.md 欄位間距） */
.pf-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 16px 24px;
  align-items: start;
}
@media (min-width: 1024px) {
  .pf-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}

/* 目前方案：有外框的標籤，文字要明顯 */
.plan-tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 12px;
  border: 1px solid var(--color-primary-text);
  border-radius: 999px;
  background: var(--color-canvas);
  color: var(--color-primary-text);
  font-size: 14px;
  font-weight: 600;
  white-space: nowrap;
  /* 純顯示用：不能被選取、游標維持箭頭，避免看起來像可點的按鈕 */
  user-select: none;
  cursor: default;
}
@media (max-width: 639.98px) {
  .plan-tag { font-size: 13px; }
}
</style>
