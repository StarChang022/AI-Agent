<script setup lang="ts">
/**
 * 後台骨架：左側導覽（可收合，寬度滑入滑出）＋頂欄（收合鈕、全域搜尋、通知、頭像選單）。
 * 對應 design-system/design-layout-shell.html 與後台原型。
 */
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useConfirm } from 'primevue/useconfirm'
import Menu from 'primevue/menu'
import type { Role } from '@/types/domain'
import { ROLE_LABELS } from '@/constants/user'
import { useAuthStore } from '@/stores/auth'
import { logout } from '@/api/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { listAdminReimbursements } from '@/api/reimbursements'
import { useOnboardingTour } from '@/composables/useOnboardingTour'
import LogoHorizontal from '@/components/LogoHorizontal.vue'
import PasswordChangeDialog from '@/components/PasswordChangeDialog.vue'
import GlobalSearch from '@/components/admin/GlobalSearch.vue'
import NotificationBell from '@/components/admin/NotificationBell.vue'

const auth = useAuthStore()
const onboarding = useOnboardingStore()
const { startTour } = useOnboardingTour()
const router = useRouter()
const route = useRoute()
const confirm = useConfirm()

interface NavItem {
  label: string
  icon: string
  to: { name: string }
  /** 其他也算在這個選單項目下的頁面（例如新增支出頁屬於支出管理） */
  also?: string[]
  allowedRoles?: Role[]
  badge?: () => number
}
interface NavGroup {
  label: string
  items: NavItem[]
}

// 簽核 badge：直接問後端現在有幾筆 in_review。
// 注意：這個數字與通知未讀數獨立（admin 可能標已讀但沒處理），兩個不互通。
// perPage=1 讓後端只回 1 筆資料 + meta.total；用 meta.total 當 badge 數字。
const reviewCount = ref(0)
async function refreshReviewCount() {
  try {
    const res = await listAdminReimbursements({ status: 'in_review', perPage: 1 })
    reviewCount.value = res.meta.total
  } catch {
    /* 失敗保留舊值，不打擾使用者 */
  }
}

const navGroups: NavGroup[] = [
  {
    label: '主選單',
    items: [
      { label: '儀表板', icon: 'pi-th-large', to: { name: 'admin-dashboard' } },
      { label: '支出管理', icon: 'pi-file', to: { name: 'admin-expenses' }, also: ['admin-expense-new', 'admin-expense-edit'] },
      { label: '收入管理', icon: 'pi-wallet', to: { name: 'admin-incomes' }, also: ['admin-income-new', 'admin-income-edit'] },
    ],
  },
  {
    label: '請款',
    items: [
      { label: '請款記錄', icon: 'pi-list', to: { name: 'admin-records' } },
      { label: '簽核', icon: 'pi-check-square', to: { name: 'admin-review' }, badge: () => reviewCount.value },
    ],
  },
  {
    label: '報表',
    items: [
      { label: '損益報表', icon: 'pi-chart-bar', to: { name: 'admin-reports-profit-loss' } },
      { label: '現金流報表', icon: 'pi-money-bill', to: { name: 'admin-reports-cashflow' } },
    ],
  },
  {
    label: '系統',
    items: [
      { label: '類別管理', icon: 'pi-tag', to: { name: 'admin-categories' } },
      { label: '預算管理', icon: 'pi-chart-line', to: { name: 'admin-budgets' } },
      { label: '人員管理', icon: 'pi-users', to: { name: 'admin-users' }, allowedRoles: ['admin'] },
    ],
  },
]

const visibleGroups = computed<NavGroup[]>(() =>
  navGroups
    .map((g) => ({
      label: g.label,
      items: g.items.filter((i) => !i.allowedRoles || (auth.role !== null && i.allowedRoles.includes(auth.role))),
    }))
    .filter((g) => g.items.length > 0),
)

function isActive(item: NavItem) {
  const n = route.name as string
  return n === item.to.name || (item.also?.includes(n) ?? false)
}

// ─── 側邊導覽收合：桌機記住狀態；窄螢幕預設收合、打開時蓋在內容上 ───
const NAV_KEY = 'quickey.admin.navCollapsed'
const narrow = ref(false)
const collapsed = ref(false)
function readPref() {
  try { return localStorage.getItem(NAV_KEY) === '1' } catch { return false }
}
function syncWidth() {
  const was = narrow.value
  narrow.value = window.innerWidth < 1024
  if (narrow.value && !was) collapsed.value = true
  if (!narrow.value && was) collapsed.value = readPref()
}
function toggleNav() {
  collapsed.value = !collapsed.value
  if (!narrow.value) {
    try { localStorage.setItem(NAV_KEY, collapsed.value ? '1' : '0') } catch { /* ignore */ }
  }
}
onMounted(() => {
  narrow.value = window.innerWidth < 1024
  collapsed.value = narrow.value ? true : readPref()
  window.addEventListener('resize', syncWidth)
  void refreshReviewCount()
})
onBeforeUnmount(() => window.removeEventListener('resize', syncWidth))
watch(() => route.fullPath, () => {
  if (narrow.value) collapsed.value = true
  // 每次換頁都重算一次簽核 badge；approve / reject / 新送審都會改動數字
  void refreshReviewCount()
})

// ─── 頭像選單 ───
const passwordDialogVisible = ref(false)
const userMenu = ref<InstanceType<typeof Menu> | null>(null)
const initial = computed(() => auth.currentUser?.name.charAt(0) ?? '?')

function handleLogout() {
  confirm.require({
    header: '登出',
    message: '確定要登出嗎？',
    icon: 'pi pi-sign-out',
    acceptLabel: '登出',
    rejectLabel: '取消',
    accept: () => {
      logout()
      router.push({ name: 'admin-login' })
    },
  })
}
async function restartOnboarding() {
  if (!auth.currentUser) return
  await onboarding.reset()
  if (route.name === 'admin-dashboard') startTour()
  else router.push({ name: 'admin-dashboard' })
}
const userMenuItems = computed(() => [
  { label: '個人設定', icon: 'pi pi-user', command: () => router.push({ name: 'admin-profile' }) },
  { label: '新手導覽', icon: 'pi pi-compass', class: 'tour-onboarding-item', command: restartOnboarding },
  { label: '修改密碼', icon: 'pi pi-key', command: () => { passwordDialogVisible.value = true } },
  { label: '切換到員工前台', icon: 'pi pi-mobile', command: () => router.push({ name: 'front-home' }) },
  { separator: true },
  { label: '登出', icon: 'pi pi-sign-out', command: handleLogout },
])

// 新手導覽最後一步要打開頭像選單
const avatarBtn = ref<HTMLButtonElement | null>(null)
watch(
  () => onboarding.userMenuOpen,
  (open) => {
    if (open) avatarBtn.value?.click()
    else userMenu.value?.hide()
  },
)
function toggleUserMenu(e: MouseEvent) {
  if (onboarding.userMenuOpen) userMenu.value?.show(e)
  else userMenu.value?.toggle(e)
}
</script>

<template>
  <div class="admin-shell" :class="{ 'nav-collapsed': collapsed }">
    <nav id="admin-nav" class="side-nav" aria-label="主選單" :inert="collapsed || undefined">
      <div class="sn-inner">
        <RouterLink :to="{ name: 'admin-dashboard' }" class="sn-brand" aria-label="Quickey 後台首頁">
          <LogoHorizontal tone="dark" :height="22" />
        </RouterLink>
        <div class="sn-scroll">
          <template v-for="group in visibleGroups" :key="group.label">
            <div class="sn-group">{{ group.label }}</div>
            <RouterLink
              v-for="item in group.items"
              :key="item.label"
              :to="item.to"
              class="sn-item"
              :class="{ active: isActive(item), 'tour-nav-active': onboarding.activeSidebarRouteName === item.to.name }"
              :aria-current="isActive(item) ? 'page' : undefined"
            >
              <i :class="['pi', item.icon]" aria-hidden="true" />
              {{ item.label }}
              <span v-if="item.badge && item.badge()" class="sn-badge" :aria-label="`${item.badge()} 筆待處理`">{{ item.badge() }}</span>
            </RouterLink>
          </template>
        </div>
      </div>
    </nav>
    <div v-if="narrow && !collapsed" class="nav-scrim" aria-hidden="true" @click="collapsed = true" />

    <div class="admin-body">
      <header class="admin-topbar">
        <button
          type="button"
          class="nav-toggle"
          :aria-label="collapsed ? '展開側邊選單' : '收合側邊選單'"
          :aria-expanded="!collapsed"
          aria-controls="admin-nav"
          @click="toggleNav"
        >
          <i class="pi pi-bars" aria-hidden="true" />
        </button>
        <GlobalSearch />
        <div class="tb-actions">
          <NotificationBell />
          <button
            ref="avatarBtn"
            type="button"
            class="avatar"
            data-tour="user-menu-trigger"
            aria-haspopup="true"
            :aria-label="`帳號選單：${auth.currentUser?.name ?? ''}`"
            @click="toggleUserMenu"
          >
            {{ initial }}
          </button>
          <Menu ref="userMenu" :model="userMenuItems" popup class="user-menu">
            <template v-if="auth.currentUser" #start>
              <div class="menu-head">{{ auth.currentUser.name }}<span class="sep" aria-hidden="true" />{{ ROLE_LABELS[auth.currentUser.role] }}</div>
            </template>
          </Menu>
        </div>
      </header>
      <main class="admin-main">
        <RouterView />
      </main>
    </div>

    <PasswordChangeDialog v-model:visible="passwordDialogVisible" />
  </div>
</template>

<style>
</style>
