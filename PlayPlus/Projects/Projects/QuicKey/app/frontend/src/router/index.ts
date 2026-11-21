import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { expireSession } from '@/api/auth'
import { setUnauthorizedHandler } from '@/api/service'

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior(_to, _from, savedPosition) {
    return savedPosition ?? { top: 0 }
  },
  routes: [
    { path: '/', redirect: '/login' },

    // 邀請接受頁（public，不套 layout）
    {
      path: '/invite/accept',
      name: 'invitation-accept',
      meta: { public: true },
      component: () => import('@/views/InvitationAcceptView.vue'),
    },
    {
      path: '/terms',
      name: 'terms',
      meta: { public: true },
      component: () => import('@/views/TermsView.vue'),
    },
    {
      path: '/privacy',
      name: 'privacy',
      meta: { public: true },
      component: () => import('@/views/PrivacyView.vue'),
    },

    // 忘記密碼 / 重設密碼（public；未登入可存取）
    {
      path: '/forgot-password',
      name: 'forgot-password',
      meta: { public: true },
      component: () => import('@/views/ForgotPasswordView.vue'),
    },
    {
      path: '/reset-password',
      name: 'reset-password',
      meta: { public: true },
      component: () => import('@/views/ResetPasswordView.vue'),
    },

    // 前台
    {
      path: '/login',
      name: 'front-login',
      meta: { public: true, area: 'front' },
      component: () => import('@/views/front/LoginView.vue'),
    },
    {
      path: '/app',
      meta: { area: 'front' },
      component: () => import('@/layouts/FrontLayout.vue'),
      children: [
        { path: '', redirect: { name: 'front-home' } },
        {
          path: 'home',
          name: 'front-home',
          component: () => import('@/views/front/HomeView.vue'),
        },
        {
          path: 'new',
          name: 'front-new',
          component: () => import('@/views/front/ExpenseFormView.vue'),
        },
        {
          path: 'history',
          name: 'front-history',
          component: () => import('@/views/front/HistoryView.vue'),
        },
        {
          path: 'expenses/:id',
          name: 'front-expense-detail',
          component: () => import('@/views/front/ExpenseDetailView.vue'),
        },
        {
          path: 'expenses/:id/edit',
          name: 'front-expense-edit',
          component: () => import('@/views/front/ExpenseFormView.vue'),
        },
        {
          path: 'notifications',
          name: 'front-notifications',
          component: () => import('@/views/NotificationsView.vue'),
        },
      ],
    },

    // 後台
    {
      path: '/admin/login',
      name: 'admin-login',
      meta: { public: true, area: 'admin' },
      component: () => import('@/views/admin/LoginView.vue'),
    },
    {
      path: '/admin/signup',
      name: 'admin-signup',
      meta: { public: true, area: 'admin' },
      component: () => import('@/views/admin/SignupView.vue'),
    },
    {
      path: '/admin/signup/verify',
      name: 'admin-signup-verify',
      meta: { public: true, area: 'admin' },
      component: () => import('@/views/admin/SignupVerifyView.vue'),
    },
    {
      path: '/admin/signup/confirm',
      name: 'admin-signup-confirm',
      meta: { public: true, area: 'admin' },
      component: () => import('@/views/admin/SignupConfirmView.vue'),
    },
    // 歡迎設定（註冊後首次登入補姓名與公司資訊；需登入、不套 layout）
    {
      path: '/admin/setup',
      name: 'admin-setup',
      meta: { area: 'admin' },
      component: () => import('@/views/admin/SetupView.vue'),
    },
    {
      path: '/admin',
      meta: { area: 'admin' },
      component: () => import('@/layouts/AdminLayout.vue'),
      children: [
        { path: '', redirect: { name: 'admin-dashboard' } },
        {
          path: 'dashboard',
          name: 'admin-dashboard',
          component: () => import('@/views/admin/DashboardView.vue'),
        },
        {
          path: 'expenses',
          name: 'admin-expenses',
          component: () => import('@/views/admin/ExpensesView.vue'),
        },
        {
          path: 'expenses/new',
          name: 'admin-expense-new',
          component: () => import('@/views/admin/ExpenseFormView.vue'),
        },
        {
          path: 'expenses/:id/edit',
          name: 'admin-expense-edit',
          component: () => import('@/views/admin/ExpenseFormView.vue'),
        },
        {
          path: 'incomes',
          name: 'admin-incomes',
          component: () => import('@/views/admin/IncomesView.vue'),
        },
        {
          path: 'incomes/new',
          name: 'admin-income-new',
          component: () => import('@/views/admin/IncomeFormView.vue'),
        },
        {
          path: 'incomes/:id/edit',
          name: 'admin-income-edit',
          component: () => import('@/views/admin/IncomeFormView.vue'),
        },
        {
          path: 'recurring',
          name: 'admin-recurring',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/RecurringView.vue'),
        },
        {
          path: 'transfers',
          name: 'admin-transfers',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/TransfersView.vue'),
        },
        {
          path: 'categories',
          name: 'admin-categories',
          component: () => import('@/views/admin/CategoriesView.vue'),
        },
        {
          path: 'accounts',
          name: 'admin-accounts',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/AccountsView.vue'),
        },
        {
          path: 'budgets',
          name: 'admin-budgets',
          component: () => import('@/views/admin/BudgetsView.vue'),
        },
        {
          path: 'records',
          name: 'admin-records',
          component: () => import('@/views/admin/RecordsView.vue'),
        },
        {
          path: 'reports/profit-loss',
          name: 'admin-reports-profit-loss',
          component: () => import('@/views/admin/ReportsProfitLossView.vue'),
        },
        {
          path: 'reports/cashflow',
          name: 'admin-reports-cashflow',
          component: () => import('@/views/admin/ReportsCashflowView.vue'),
        },
        {
          path: 'review',
          name: 'admin-review',
          component: () => import('@/views/admin/ReviewView.vue'),
        },
        {
          path: 'profile',
          name: 'admin-profile',
          component: () => import('@/views/admin/ProfileView.vue'),
        },
        {
          path: 'notifications',
          name: 'admin-notifications',
          component: () => import('@/views/NotificationsView.vue'),
        },
        {
          path: 'users',
          name: 'admin-users',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/UsersView.vue'),
        },
        {
          path: 'audit-logs',
          name: 'admin-audit-logs',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/AuditLogsView.vue'),
        },
        // 資料匯出下載頁（PRD 第 24 條）：背景產生完成的通知信連到這裡
        {
          path: 'exports/:id',
          name: 'admin-export-download',
          meta: { requiredRole: 'admin' as const },
          component: () => import('@/views/admin/ExportDownloadView.vue'),
        },
      ],
    },

    // 404
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      meta: { public: true },
      component: () => import('@/views/NotFoundView.vue'),
    },
  ],
})

/**
 * 權限守衛規則：
 * - 公開頁面（登入頁）任何人都能進
 * - 未登入 → 導向對應的 login 頁；後台頁面帶 redirect，登入後回到原本要去的頁面（例如信中的匯出下載連結）
 * - 已登入但角色不符該區域 → 導向該角色的預設頁面
 *   - employee 不能進 /admin/*
 *   - admin 可以進 /app/*（頭像選單「切換到員工前台」）
 * - 管理員尚未填姓名（剛註冊）→ 一律先導向 /admin/setup 歡迎設定
 * - 特定頁面若標了 `meta.requiredRole`，角色不符改導 /admin/dashboard
 */
router.beforeEach((to) => {
  const auth = useAuthStore()
  const area = to.meta.area as 'front' | 'admin' | undefined
  const isPublic = to.meta.public === true
  const requiredRole = to.meta.requiredRole as
    | 'employee'
    | 'admin'
    | undefined

  if (isPublic) return true

  if (!auth.isLoggedIn) {
    if (area !== 'admin') return { name: 'front-login' }
    return to.name === 'admin-dashboard' || to.path === '/admin'
      ? { name: 'admin-login' }
      : { name: 'admin-login', query: { redirect: to.fullPath } }
  }

  if (area === 'admin' && auth.role === 'employee') {
    return { name: 'front-home' }
  }

  // 管理員可以從頭像選單「切換到員工前台」提交自己的請款，所以不擋 /app/*

  // 剛註冊的管理員尚未填姓名 → 先完成歡迎設定；已填過就不再進設定頁
  const needsSetup = auth.role === 'admin' && !auth.currentUser?.name.trim()
  if (needsSetup && to.name !== 'admin-setup') return { name: 'admin-setup' }
  if (!needsSetup && to.name === 'admin-setup') {
    return { name: 'admin-dashboard' }
  }

  if (requiredRole && auth.role !== requiredRole) {
    return { name: 'admin-dashboard' }
  }

  return true
})

/**
 * 已登入時 API 回 401（登入過期、使用中被停用）：登出並回登入頁，帶原頁面當 redirect，
 * 重新登入後回到原頁。依角色決定前台／後台登入頁（管理員在前台時也回後台登入）。
 */
setUnauthorizedHandler(() => {
  const isAdmin = useAuthStore().role === 'admin'
  expireSession()
  void router.replace({
    name: isAdmin ? 'admin-login' : 'front-login',
    query: { redirect: router.currentRoute.value.fullPath },
  })
})

export default router
