<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { Invitation, Role, User } from '@/types/domain'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'
import {
  adminResetPassword,
  listUsers,
  setUserStatus,
  updateUser,
} from '@/api/users'
import {
  createInvitation,
  listInvitations,
  revokeInvitation,
} from '@/api/invitations'
import { getCompany } from '@/api/company'
import { HttpError } from '@/api/service'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import TabBar from '@/components/qds/TabBar.vue'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import Menu from 'primevue/menu'
import Message from 'primevue/message'
import Password from 'primevue/password'
import Select from 'primevue/select'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const toast = useToast()
const confirm = useConfirm()
const keyword = ref('')
const statusTab = ref<'active' | 'suspended'>('active')

// 列表走 API，一次抓所有狀態（含 suspended），tab 本地切；避免切 tab 多打一次
const allUsers = ref<User[]>([])
const activeInvitations = ref<Invitation[]>([])
// 員工名額上限由後端 Company::MEMBER_LIMIT 提供（透過 /api/company），避免前後端數字不同步
const memberLimit = ref(0)
// 邀請前的「公司名稱已填」檢查用；跟 memberLimit 同一支 /api/company 回來
const companyName = ref('')
const loading = ref(false)

async function refreshAll() {
  loading.value = true
  try {
    const [users, invs, company] = await Promise.all([
      listUsers(),
      listInvitations(),
      getCompany(),
    ])
    allUsers.value = users
    activeInvitations.value = invs
    memberLimit.value = company.memberLimit
    companyName.value = company.name ?? ''
  } catch (err) {
    toast.add({
      severity: 'error',
      summary: '載入資料失敗',
      detail: errorMessage(err),
      life: 3000,
    })
  } finally {
    loading.value = false
  }
}

onMounted(refreshAll)

function errorMessage(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { error?: string } | undefined
    return body?.error ?? err.message
  }
  if (err instanceof Error) return err.message
  return String(err)
}

const roleOptions: { value: Role; label: string }[] = [
  { value: 'employee', label: '一般人員' },
  { value: 'admin', label: '管理員' },
]

interface UserRow {
  kind: 'user'
  id: string
  name: string
  email: string
  role: Role
  raw: User
}

interface InvitationRow {
  kind: 'invitation'
  id: string
  name: string
  email: string
  raw: Invitation
}

type Row = UserRow | InvitationRow

// 人員是清單數量不是待辦，分頁不顯示數字（總數見表格底部）
const statusTabs = computed(() => [
  {
    value: 'active' as const,
    label: '使用中',
  },
  {
    value: 'suspended' as const,
    label: '停用',
  },
])

const rows = computed<Row[]>(() => {
  // 依「加入時間」舊 → 新排序（User.createdAt / Invitation.createdAt）。
  // 使用中人員在上、已邀請人員在下，分段內各自照時間排。
  const userRows: UserRow[] = allUsers.value
    .filter((u) => u.status === statusTab.value)
    .slice()
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((u) => ({
      kind: 'user',
      id: u.id,
      name: u.name,
      email: u.email,
      role: u.role,
      raw: u,
    }))
  const invRows: InvitationRow[] = statusTab.value === 'active' ? activeInvitations.value
    .slice()
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((inv) => ({
      kind: 'invitation',
      id: inv.id,
      name: inv.name,
      email: inv.email,
      raw: inv,
    })) : []
  return [...userRows, ...invRows]
})
const filteredRows = computed<Row[]>(() => {
  const kw = keyword.value.trim().toLowerCase()
  if (!kw) return rows.value
  return rows.value.filter(
    (r) =>
      r.name.toLowerCase().includes(kw) || r.email.toLowerCase().includes(kw),
  )
})

// 名額 = 使用中員工 + 有效邀請中 email 尚未出現在人員清單的筆數。
// 後端 Company#members_at_limit? 是權威來源；此處算的是顯示用，實際擋在 createInvitation 回 AT_LIMIT。
const quota = computed(() => {
  const activeEmployees = allUsers.value.filter(
    (u) => u.role === 'employee' && u.status === 'active',
  ).length
  const emailsInUsers = new Set(
    allUsers.value.map((u) => u.email.toLowerCase()),
  )
  const pendingInvitations = activeInvitations.value.filter(
    (inv) => !emailsInUsers.has(inv.email.toLowerCase()),
  ).length
  return activeEmployees + pendingInvitations
})
const canInvite = computed(() => quota.value < memberLimit.value)

// ─── 邀請 Dialog ────────────────────────────────────
const inviteVisible = ref(false)
const inviteForm = ref<{ email: string; name: string }>({ email: '', name: '' })
const inviteEmailError = ref('')
const inviteNameError = ref('')
const inviteFormError = ref('')

// 與後端 Invitation#validates email format（URI::MailTo::EMAIL_REGEXP）同步；
// 後端是終極校驗，前端 pre-check 只是避免白送一次 request。
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function clearInviteErrors() {
  inviteEmailError.value = ''
  inviteNameError.value = ''
  inviteFormError.value = ''
}

const router = useRouter()

/**
 * 員工收到的邀請會顯示公司名稱，所以公司名稱未填時先引導到個人設定填寫。
 */
function openInvite() {
  if (!companyName.value.trim()) {
    confirm.require({
      header: '請先填寫公司名稱',
      message: '員工收到的邀請會顯示公司名稱，方便對方確認是哪家公司邀請。',
      icon: 'pi pi-info-circle',
      acceptLabel: '前往填寫',
      rejectLabel: '取消',
      rejectProps: { outlined: true, severity: 'secondary' },
      accept: () =>
        router.push({ name: 'admin-profile', query: { focus: 'company' } }),
    })
    return
  }
  inviteForm.value = { email: '', name: '' }
  clearInviteErrors()
  inviteVisible.value = true
}

function closeInvite() {
  inviteVisible.value = false
  clearInviteErrors()
}

function validateInviteEmail(): string {
  const v = inviteForm.value.email.trim()
  if (!v) return '請填 email'
  if (!EMAIL_RE.test(v)) return 'Email 格式不正確（例如 name@company.com）'
  return ''
}

function onInviteEmailBlur() {
  inviteEmailError.value = validateInviteEmail()
}

const inviteSubmitting = ref(false)
async function submitInvite() {
  clearInviteErrors()
  const email = inviteForm.value.email.trim()
  const name = inviteForm.value.name.trim()
  inviteEmailError.value = validateInviteEmail()
  if (!name) inviteNameError.value = '請填姓名'
  if (inviteEmailError.value || inviteNameError.value) return
  if (inviteSubmitting.value) return
  inviteSubmitting.value = true

  try {
    await createInvitation({ email, name })
    toast.add({
      severity: 'success',
      summary: '已發送邀請',
      detail: `邀請信已寄給 ${email}`,
      life: 3000,
    })
    closeInvite()
    await refreshAll()
  } catch (err) {
    if (err instanceof HttpError) {
      const code = (err.body as { error?: string })?.error
      switch (code) {
        case 'INVALID_EMAIL':
          inviteEmailError.value = 'Email 格式不正確（例如 name@company.com）'
          break
        case 'INVALID_NAME':
          inviteNameError.value = '請填姓名'
          break
        case 'EMAIL_IN_USE':
          toast.add({
            severity: 'error',
            summary: '無法發送邀請',
            detail: '該 email 已是公司人員',
            life: 4000,
          })
          break
        case 'EMAIL_PENDING':
          toast.add({
            severity: 'error',
            summary: '無法發送邀請',
            detail: '該 email 已有有效邀請，請先撤回既有邀請再重發',
            life: 4000,
          })
          break
        case 'AT_LIMIT':
          inviteFormError.value = `已達人員上限 ${memberLimit.value} 人，請先撤回既有邀請或移除人員`
          break
        default:
          inviteFormError.value = errorMessage(err)
      }
    } else {
      inviteFormError.value = errorMessage(err)
    }
  } finally {
    inviteSubmitting.value = false
  }
}

// ─── 撤回邀請 ───────────────────────────────────────
function confirmRevoke(inv: Invitation) {
  confirm.require({
    header: '撤回邀請',
    message: `確定撤回對「${inv.email}」的邀請？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '確認撤回',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      try {
        await revokeInvitation(inv.id)
        toast.add({
          severity: 'success',
          summary: '已撤回邀請',
          life: 2500,
        })
        await refreshAll()
      } catch (err) {
        toast.add({
          severity: 'error',
          summary: '撤回失敗',
          detail: errorMessage(err),
          life: 3000,
        })
      }
    },
  })
}

// ─── 編輯人員 Dialog（只改姓名 + role）─────────────
const editVisible = ref(false)
const editingId = ref<string | null>(null)
const editForm = ref<{ name: string; role: Role; email: string }>({
  name: '',
  role: 'employee',
  email: '',
})
const editNameError = ref('')

function openEdit(user: User) {
  editingId.value = user.id
  editForm.value = { name: user.name, role: user.role, email: user.email }
  editNameError.value = ''
  editVisible.value = true
}

function closeEdit() {
  editVisible.value = false
  editingId.value = null
  editNameError.value = ''
}

const editSubmitting = ref(false)

async function submitEdit() {
  editNameError.value = ''
  const name = editForm.value.name.trim()
  if (!name) {
    editNameError.value = '請填姓名'
    return
  }
  if (!editingId.value || editSubmitting.value) return
  // role 下拉在 Dialog 內已 disabled（Decision：暫不支援轉移管理員），
  // 這裡只送 name；後端 /users/:id 本來也只收 name。
  editSubmitting.value = true
  try {
    await updateUser(editingId.value, { name })
    toast.add({
      severity: 'success',
      summary: '已更新',
      detail: name,
      life: 2500,
    })
    closeEdit()
    await refreshAll()
  } catch (err) {
    editNameError.value = errorMessage(err)
  } finally {
    editSubmitting.value = false
  }
}

// ─── 每列 ⋯ 選單：重設密碼、停用 / 重新啟用（自己的帳號不能在這裡操作）──────
const auth = useAuthStore()
const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<User | null>(null)
const rowMenuItems = computed(() => {
  const u = menuTarget.value
  if (!u) return []
  const self = u.id === auth.currentUser?.id
  const suspended = u.status === 'suspended'
  const items: {
    label?: string
    icon?: string
    disabled?: boolean
    class?: string
    separator?: boolean
    command?: () => void
  }[] = []
  if (!suspended) {
    items.push({
      label: self ? '重設密碼（請到個人設定修改）' : '重設密碼',
      icon: 'pi pi-key',
      disabled: self,
      command: () => openResetPassword(u),
    })
    items.push({ separator: true })
  }
  items.push(
    {
      label: suspended ? '重新啟用' : self ? '停用（不能停用自己）' : '停用',
      icon: suspended ? 'pi pi-refresh' : 'pi pi-ban',
      class: suspended ? undefined : 'menu-danger',
      disabled: self,
      command: () => (suspended ? activateUser(u) : confirmSuspend(u)),
    },
  )
  return items
})
function openRowMenu(e: MouseEvent, u: User) {
  menuTarget.value = u
  rowMenu.value?.toggle(e)
}

// ─── 重設密碼 Dialog（管理員直接設定新密碼，不需舊密碼）──────
const resetTarget = ref<User | null>(null)
const resetPwd = ref('')
const resetConfirm = ref('')
const resetPwdError = ref('')
const resetConfirmError = ref('')

function openResetPassword(u: User) {
  resetTarget.value = u
  resetPwd.value = ''
  resetConfirm.value = ''
  resetPwdError.value = ''
  resetConfirmError.value = ''
}
function closeResetPassword() {
  resetTarget.value = null
}
/** 產生 10 碼隨機密碼（排除容易看錯的 0/O、1/l/I），方便管理員直接告知對方 */
function generatePassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
  const buf = new Uint32Array(10)
  crypto.getRandomValues(buf)
  const pwd = Array.from(buf, (n) => chars[n % chars.length]).join('')
  resetPwd.value = pwd
  resetConfirm.value = pwd
  resetPwdError.value = ''
  resetConfirmError.value = ''
}
const resetSubmitting = ref(false)
async function submitResetPassword() {
  const u = resetTarget.value
  if (!u || resetSubmitting.value) return
  resetPwdError.value = !resetPwd.value ? '請設定新密碼' : resetPwd.value.length < 8 ? '密碼長度至少 8 碼' : ''
  resetConfirmError.value = !resetConfirm.value ? '請再次輸入新密碼' : resetConfirm.value !== resetPwd.value ? '兩次輸入的密碼不同' : ''
  if (resetPwdError.value || resetConfirmError.value) return
  resetSubmitting.value = true
  try {
    await adminResetPassword(u.id, { newPassword: resetPwd.value })
    toast.add({ severity: 'success', summary: '已重設密碼', detail: `請將新密碼告知 ${u.name}`, life: 3500 })
    closeResetPassword()
  } catch (err) {
    // 後端 WEAK_PASSWORD（防禦性）或其他錯誤統一掛在新密碼欄下
    resetPwdError.value = errorMessage(err)
  } finally {
    resetSubmitting.value = false
  }
}

// ─── 停用 / 重新啟用人員 ───────────────────────────
function confirmSuspend(user: User) {
  confirm.require({
    header: '停用人員',
    message: `確定要停用「${user.name}」嗎？停用後對方將不再列入使用中人員。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '停用',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      try {
        await setUserStatus(user.id, { status: 'suspended' })
        toast.add({
          severity: 'success',
          summary: '已停用',
          detail: user.name,
          life: 2500,
        })
        await refreshAll()
      } catch (err) {
        toast.add({
          severity: 'error',
          summary: '停用失敗',
          detail: errorMessage(err),
          life: 3000,
        })
      }
    },
  })
}

async function activateUser(user: User) {
  try {
    await setUserStatus(user.id, { status: 'active' })
    toast.add({
      severity: 'success',
      summary: '已重新啟用',
      detail: user.name,
      life: 2500,
    })
    await refreshAll()
  } catch (err) {
    toast.add({
      severity: 'error',
      summary: '操作失敗',
      detail: errorMessage(err),
      life: 3000,
    })
  }
}

function roleLabel(role: Role) {
  return roleOptions.find((r) => r.value === role)?.label ?? role
}
</script>

<template>
  <div class="dash-page">
    <PageHeader
      title="人員管理"
      size="admin"
    >
      <template #actions>
        <Button
          v-tooltip.bottom="
            !canInvite ? `已達人員上限 ${memberLimit} 人` : undefined
          "
          icon="pi pi-user-plus"
          label="邀請人員"
          :disabled="!canInvite"
          data-tour="users-invite-button"
          @click="openInvite"
        />
      </template>
    </PageHeader>

    <section class="dash-panel dash-table-panel" aria-label="人員列表">
      <div class="list-head">
        <TabBar
          v-model="statusTab"
          :tabs="statusTabs"
          variant="segmented"
          label="人員狀態"
        />
        <div class="list-head-tools">
          <SearchInput v-model="keyword" placeholder="搜尋姓名或 Email" />
        </div>
      </div>
      <DataTable :value="filteredRows" :loading="loading" data-key="id" row-hover>
        <template #empty>
          <EmptyState
            variant="plain"
            icon="pi pi-users"
            :title="keyword.trim() ? '沒有符合條件的人員' : statusTab === 'suspended' ? '目前沒有停用人員' : '還沒有人員資料'"
            :description="statusTab === 'suspended' ? '停用後的人員會集中在這裡，可視情況重新啟用' : '可邀請員工加入公司，開始送出代墊款'"
          >
            <template v-if="!keyword.trim() && statusTab === 'active'" #action>
              <Button
                icon="pi pi-user-plus"
                label="邀請人員"
                :disabled="!canInvite"
                @click="openInvite"
              />
            </template>
          </EmptyState>
        </template>
        <Column
          field="name"
          header="姓名"
          body-class="whitespace-nowrap"
          style="min-width: 8rem"
        />
        <Column
          field="email"
          header="Email"
          body-class="whitespace-nowrap"
          style="min-width: 12rem"
        />
        <Column
          header="身分"
          body-class="whitespace-nowrap"
          style="min-width: 6rem"
        >
          <template #body="{ data }">
            <template v-if="data.kind === 'user'">
              <span
                class="tag-soft"
                :class="{
                  'tag-warn': data.role === 'admin',
                  'tag-neutral': data.role === 'employee',
                }"
                >{{ roleLabel(data.role) }}</span
              >
            </template>
            <template v-else>
              <span class="tag-soft tag-neutral">{{
                roleLabel('employee')
              }}</span>
            </template>
          </template>
        </Column>
        <Column
          header="狀態"
          body-class="whitespace-nowrap"
          style="min-width: 5rem"
        >
          <template #body="{ data }">
            <span v-if="data.kind === 'user'" class="tag-soft" :class="data.raw.status === 'suspended' ? 'tag-neutral' : 'tag-success'">
              {{ data.raw.status === 'suspended' ? '停用' : '使用中' }}
            </span>
            <span v-else class="tag-soft">已邀請</span>
          </template>
        </Column>
        <Column
          header-class="act user-action-col"
          body-class="act user-action-col"
        >
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <span v-if="data.kind === 'user'" class="row-actions">
              <Button
                type="button"
                outlined
                size="small"
                icon="pi pi-pencil"
                :aria-label="`編輯 ${data.name}`"
                v-tooltip.top="'編輯'"
                @click="openEdit(data.raw)"
              />
              <Button
                type="button"
                outlined
                size="small"
                icon="pi pi-ellipsis-h"
                aria-label="更多動作"
                aria-haspopup="true"
                v-tooltip.top="'更多動作'"
                @click="openRowMenu($event, data.raw)"
              />
            </span>
            <span v-else class="row-actions">
              <Button
                outlined
                size="small"
                severity="danger"
                icon="pi pi-times"
                label="撤回"
                @click="confirmRevoke(data.raw)"
              />
            </span>
          </template>
        </Column>
      </DataTable>
      <div class="dash-table-summary">
        使用中名額
        <b class="text-[var(--color-ink)] font-semibold tabular-nums">{{ quota }} / {{ memberLimit }}</b>
        <span class="sep" aria-hidden="true" />顯示 {{ filteredRows.length }} 筆
      </div>
    </section>

    <!-- 邀請 Dialog -->
    <Dialog
      :visible="inviteVisible"
      header="邀請人員"
      modal
      :style="{ width: 'min(92vw, 28rem)' }"
      @update:visible="closeInvite"
    >
      <form class="form-main" novalidate @submit.prevent="submitInvite">
        <div class="q-field">
          <label for="invite-form-email">Email</label>
          <InputText
            id="invite-form-email"
            autofocus
            v-model="inviteForm.email"
            type="email"
            class="w-full"
            :invalid="!!inviteEmailError"
            :aria-invalid="!!inviteEmailError"
            aria-describedby="invite-form-email-error"
            placeholder="new@example.com"
            @input="inviteEmailError = ''"
            @blur="onInviteEmailBlur"
          />
          <p
            v-if="inviteEmailError"
            id="invite-form-email-error"
            class="q-error"
            role="alert"
          >
            <i class="pi pi-exclamation-circle" aria-hidden="true" />
            {{ inviteEmailError }}
          </p>
        </div>
        <div class="q-field">
          <label for="invite-form-name">姓名</label>
          <InputText
            id="invite-form-name"
            v-model="inviteForm.name"
            class="w-full"
            :invalid="!!inviteNameError"
            :aria-invalid="!!inviteNameError"
            aria-describedby="invite-form-name-error"
            placeholder="姓名"
            @input="inviteNameError = ''"
          />
          <p
            v-if="inviteNameError"
            id="invite-form-name-error"
            class="q-error"
            role="alert"
          >
            <i class="pi pi-exclamation-circle" aria-hidden="true" />
            {{ inviteNameError }}
          </p>
        </div>
        <Message v-if="inviteFormError" severity="error" :closable="false">
          {{ inviteFormError }}
        </Message>
        <button type="submit" class="hidden" />
      </form>
      <template #footer>
        <Button type="button" outlined label="取消" @click="closeInvite" />
        <Button type="button" label="發送邀請" :loading="inviteSubmitting" @click="submitInvite" />
      </template>
    </Dialog>

    <!-- 編輯人員 Dialog -->
    <Dialog
      :visible="editVisible"
      header="編輯人員"
      modal
      :style="{ width: 'min(92vw, 28rem)' }"
      @update:visible="closeEdit"
    >
      <form class="form-main" novalidate @submit.prevent="submitEdit">
        <div class="q-field">
          <label for="edit-email">Email</label>
          <InputText
            id="edit-email"
            :model-value="editForm.email"
            class="w-full"
            disabled
          />
        </div>
        <div class="q-field">
          <label for="edit-name">姓名</label>
          <InputText
            id="edit-name"
            autofocus
            v-model="editForm.name"
            class="w-full"
            :invalid="!!editNameError"
            :aria-invalid="!!editNameError"
            aria-describedby="edit-name-error"
            @input="editNameError = ''"
          />
          <p
            v-if="editNameError"
            id="edit-name-error"
            class="q-error"
            role="alert"
          >
            <i class="pi pi-exclamation-circle" aria-hidden="true" />
            {{ editNameError }}
          </p>
        </div>
        <div class="q-field">
          <label for="edit-role">身分</label>
          <Select
            id="edit-role"
            v-model="editForm.role"
            :options="roleOptions"
            option-label="label"
            option-value="value"
            class="w-full"
            disabled
          />
          <p class="q-help">此階段暫不支援新增 / 轉移管理員身分。</p>
        </div>
        <button type="submit" class="hidden" />
      </form>
      <template #footer>
        <Button type="button" outlined label="取消" @click="closeEdit" />
        <Button type="button" label="儲存" :loading="editSubmitting" @click="submitEdit" />
      </template>
    </Dialog>

    <Menu ref="rowMenu" :model="rowMenuItems" popup />

    <!-- 重設密碼 Dialog -->
    <Dialog
      :visible="resetTarget !== null"
      header="重設密碼"
      modal
      :style="{ width: 'min(92vw, 28rem)' }"
      @update:visible="closeResetPassword"
    >
      <form class="form-main reset-password-form" novalidate @submit.prevent="submitResetPassword">
        <div class="q-field">
          <div class="flex items-center justify-between">
            <label for="reset-pwd">新密碼</label>
            <Button type="button" text size="small" label="產生隨機密碼" icon="pi pi-sync" @click="generatePassword" />
          </div>
          <Password
            v-model="resetPwd"
            input-id="reset-pwd"
            :input-props="{ autofocus: true }"
            :feedback="false"
            toggle-mask
            fluid
            autocomplete="new-password"
            :invalid="!!resetPwdError"
            aria-describedby="reset-pwd-msg"
            @update:model-value="resetPwdError = ''"
          />
          <p v-if="resetPwdError" id="reset-pwd-msg" class="q-error" role="alert"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ resetPwdError }}</p>
          <p v-else id="reset-pwd-msg" class="q-help">至少 8 碼</p>
        </div>
        <div class="q-field">
          <label for="reset-confirm">確認新密碼</label>
          <Password
            v-model="resetConfirm"
            input-id="reset-confirm"
            :feedback="false"
            toggle-mask
            fluid
            autocomplete="new-password"
            :invalid="!!resetConfirmError"
            aria-describedby="reset-confirm-msg"
            @update:model-value="resetConfirmError = ''"
          />
          <p v-if="resetConfirmError" id="reset-confirm-msg" class="q-error" role="alert"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ resetConfirmError }}</p>
        </div>
        <button type="submit" class="hidden" />
      </form>
      <template #footer>
        <Button type="button" outlined label="取消" @click="closeResetPassword" />
        <Button type="button" label="重設密碼" :loading="resetSubmitting" @click="submitResetPassword" />
      </template>
    </Dialog>
  </div>
</template>

<style scoped>
/* 操作欄：user 列是編輯 + ⋯ 兩個 icon、invitation 列是撤回；取能容下較寬者 */
:deep(.user-action-col) {
  min-width: 8rem;
}
.reset-password-form label { font-weight: 400; }
@media (max-width: 639.98px) {
  :deep(.user-action-col) {
    min-width: 6rem;
  }
}
</style>
