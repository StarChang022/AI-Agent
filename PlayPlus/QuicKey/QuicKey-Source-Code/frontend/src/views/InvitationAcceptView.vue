<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { getInvitationByToken, acceptInvitation } from '@/api/invitations'
import { logout as apiLogout } from '@/api/auth'
import LogoMark from '@/components/LogoMark.vue'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Message from 'primevue/message'

/**
 * 邀請接受頁（public route `/invite/accept?token=xxx`，不套 layout）。
 *
 * - 頁面自帶 minimal chrome，不進 FrontLayout / AdminLayout
 * - 已登入身分開啟時提示「請先登出」而不自動登出
 * - 表單只收密碼 + 確認密碼；姓名唯讀（沿用 admin 邀請時填的）
 * - 掛載即呼 `GET /invitations/by-token/:token` 判斷連結狀態
 * - 送出走 `POST /invitations/by-token/:token/accept`，成功同時 auto-login（含 JWT）
 */

type ViewState =
  | 'loading'
  | 'ready'
  | 'not_found'
  | 'expired'
  | 'revoked'
  | 'already_used'
  | 'logged_in'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const token = computed(() =>
  typeof route.query.token === 'string' ? route.query.token : '',
)

const state = ref<ViewState>('loading')
const email = ref('')
const name = ref('')
const companyName = ref('')
const subtitle = computed(() =>
  companyName.value
    ? `接受邀請並加入「${companyName.value}」`
    : '接受邀請並加入公司',
)

// state 以 ref 保存，透過 evaluateState() 更新；掛載時跑一次、
// 使用者在「已登入」畫面按「登出目前身分」後再跑一次，讓畫面能跟著切換。
async function evaluateState() {
  if (auth.isLoggedIn) {
    state.value = 'logged_in'
    return
  }
  if (!token.value) {
    state.value = 'not_found'
    return
  }
  state.value = 'loading'
  try {
    const res = await getInvitationByToken(token.value)
    switch (res.status) {
      case 'valid':
        email.value = res.email ?? ''
        name.value = res.name ?? ''
        companyName.value = res.companyName ?? ''
        state.value = 'ready'
        break
      case 'expired':
      case 'revoked':
      case 'already_used':
      case 'not_found':
        state.value = res.status
        break
    }
  } catch {
    state.value = 'not_found'
  }
}

onMounted(evaluateState)

const password = ref('')
const passwordConfirm = ref('')
const passwordError = ref('')
const passwordConfirmError = ref('')
const formError = ref('')
const submitting = ref(false)

function validatePassword(): string {
  if (!password.value) return '請設定密碼'
  if (password.value.length < 8) return '密碼長度至少 8 碼'
  return ''
}

function validatePasswordConfirm(): string {
  if (!passwordConfirm.value) return '請再次輸入密碼'
  if (password.value !== passwordConfirm.value) return '兩次輸入的密碼不同'
  return ''
}

async function submit() {
  formError.value = ''
  passwordError.value = validatePassword()
  passwordConfirmError.value = validatePasswordConfirm()
  if (passwordError.value || passwordConfirmError.value) return
  if (state.value !== 'ready' || submitting.value) return
  submitting.value = true
  try {
    // acceptInvitation 內部完成 persistSession（寫 token + user）；view 只負責導頁
    await acceptInvitation(token.value, { password: password.value })
    router.replace({ name: 'front-home' })
  } catch {
    // 常見錯誤：invalid_or_expired_invitation（400）、validation_failed（422）
    formError.value = '接受邀請失敗，可能連結已失效，請聯絡管理員重新發送邀請'
  } finally {
    submitting.value = false
  }
}

function handleLogout() {
  // apiLogout 內部同步清 local session；清完重新評估畫面狀態，
  // 若 token 有效即從 'logged_in' 切到 'ready'
  apiLogout()
  evaluateState()
}
</script>

<template>
  <div class="min-h-screen flex flex-col bg-[var(--color-surface)]">
    <main class="flex-1 flex justify-center px-4 pt-12 pb-8">
      <div class="w-full max-w-sm">
        <div class="mb-8 text-center flex flex-col items-center">
          <div
            class="w-20 h-20 rounded-2xl bg-primary-700 flex items-center justify-center mb-4"
          >
            <LogoMark :size="56" />
          </div>
          <div class="text-3xl font-bold text-primary-700 tracking-tight">
            Quickey
          </div>
          <div class="text-sm text-[var(--color-muted)] mt-1">
            {{ subtitle }}
          </div>
        </div>

        <!-- 載入中 -->
        <div v-if="state === 'loading'" class="flex justify-center py-8">
          <i class="pi pi-spinner pi-spin text-2xl text-[var(--color-muted)]" aria-label="載入中" />
        </div>

        <!-- 已登入身分 -->
        <div v-else-if="state === 'logged_in'" class="space-y-4">
          <Message severity="warn" :closable="false">
            目前已登入為
            <span class="font-medium">{{ auth.currentUser?.email }}</span>
            。<br />請先登出目前身分再開啟邀請連結。
          </Message>
          <Button
            label="登出目前身分"
            severity="secondary"
            outlined
            class="w-full"
            @click="handleLogout"
          />
        </div>

        <!-- Token 無效 -->
        <div v-else-if="state === 'not_found'" class="space-y-4">
          <Message severity="error" :closable="false">
            連結無效，請確認邀請連結是否完整。
          </Message>
          <p class="text-xs text-[var(--color-muted)] text-center">
            如需協助，請聯絡貴公司管理員重新發送邀請。
          </p>
        </div>

        <!-- 過期 -->
        <div v-else-if="state === 'expired'" class="space-y-4">
          <Message severity="error" :closable="false">
            邀請連結已過期。
          </Message>
          <p class="text-xs text-[var(--color-muted)] text-center">
            請聯絡貴公司管理員重新發送邀請。
          </p>
        </div>

        <!-- 撤回 -->
        <div v-else-if="state === 'revoked'" class="space-y-4">
          <Message severity="error" :closable="false">邀請已撤回。</Message>
          <p class="text-xs text-[var(--color-muted)] text-center">
            如有疑問請聯絡貴公司管理員。
          </p>
        </div>

        <!-- 已使用 -->
        <div v-else-if="state === 'already_used'" class="space-y-4">
          <Message severity="info" :closable="false">
            此邀請連結已被使用過。
          </Message>
          <RouterLink
            to="/login"
            class="block w-full text-center py-2 px-4 rounded-md bg-primary-700 text-white hover:bg-primary-800 text-sm"
          >
            前往登入
          </RouterLink>
        </div>

        <!-- Ready: 接受表單 -->
        <form
          v-else
          class="space-y-4"
          novalidate
          @submit.prevent="submit"
        >
          <div>
            <label
              for="invite-email"
              class="field-label"
            >
              Email
            </label>
            <InputText
              id="invite-email"
              :model-value="email"
              class="w-full"
              disabled
            />
          </div>
          <div>
            <label
              for="invite-name"
              class="field-label"
            >
              姓名
            </label>
            <InputText
              id="invite-name"
              :model-value="name"
              class="w-full"
              disabled
            />
            <p class="q-help mt-2">Email 或姓名有誤，請聯絡管理員。</p>
          </div>
          <div>
            <label
              for="invite-password"
              class="field-label"
            >
              設定密碼
            </label>
            <InputText
              id="invite-password"
              v-model="password"
              type="password"
              class="w-full"
              :invalid="!!passwordError"
              :aria-invalid="!!passwordError"
              aria-describedby="invite-password-error"
              placeholder="至少 8 碼"
              autocomplete="new-password"
              @input="passwordError = ''"
            />
            <p
              v-if="passwordError"
              id="invite-password-error"
              class="text-xs text-[var(--color-status-rejected)] mt-1"
              role="alert"
            >
              {{ passwordError }}
            </p>
          </div>
          <div>
            <label
              for="invite-password-confirm"
              class="field-label"
            >
              再次輸入密碼
            </label>
            <InputText
              id="invite-password-confirm"
              v-model="passwordConfirm"
              type="password"
              class="w-full"
              :invalid="!!passwordConfirmError"
              :aria-invalid="!!passwordConfirmError"
              aria-describedby="invite-password-confirm-error"
              autocomplete="new-password"
              @input="passwordConfirmError = ''"
            />
            <p
              v-if="passwordConfirmError"
              id="invite-password-confirm-error"
              class="text-xs text-[var(--color-status-rejected)] mt-1"
              role="alert"
            >
              {{ passwordConfirmError }}
            </p>
          </div>
          <Message v-if="formError" severity="error" :closable="false">
            {{ formError }}
          </Message>
          <Button
            type="submit"
            label="加入公司"
            class="w-full"
            :loading="submitting"
          />
        </form>
      </div>
    </main>
  </div>
</template>
