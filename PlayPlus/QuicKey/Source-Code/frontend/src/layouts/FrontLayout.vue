<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useConfirm } from 'primevue/useconfirm'
import { useAuthStore } from '@/stores/auth'
import { logout } from '@/api/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { useOnboardingTour } from '@/composables/useOnboardingTour'
import AppHeader from '@/components/AppHeader.vue'
import UserBadge from '@/components/UserBadge.vue'
import PasswordChangeDialog from '@/components/PasswordChangeDialog.vue'
import PwaInstallPrompt from '@/components/PwaInstallPrompt.vue'
import { useSlideIndicator } from '@/composables/useSlideIndicator'

const auth = useAuthStore()
const onboarding = useOnboardingStore()
const { startTour } = useOnboardingTour()
const router = useRouter()
const route = useRoute()
const confirm = useConfirm()

const passwordDialogVisible = ref(false)

// 導覽選中底色：滑動到目前頁面（頂部桌機、底部手機各一個）
const topNav = ref<HTMLElement | null>(null)
const bottomNav = ref<HTMLElement | null>(null)
const { style: topIndicator } = useSlideIndicator(topNav, '.is-active', () => route.name)
const { style: bottomIndicator } = useSlideIndicator(bottomNav, '.is-active', () => route.name)

function handleLogout() {
  confirm.require({
    header: '登出',
    message: '確定要登出嗎？',
    icon: 'pi pi-sign-out',
    acceptLabel: '登出',
    rejectLabel: '取消',
    accept: () => {
      logout()
      router.push({ name: 'front-login' })
    },
  })
}

async function restartOnboarding() {
  if (!auth.currentUser) return
  await onboarding.reset()
  // 若已在 home，push 是 no-op → 直接 startTour；否則由 home onMounted 觸發
  if (route.name === 'front-home') {
    startTour()
  } else {
    router.push({ name: 'front-home' })
  }
}

const userMenuItems = computed(() => [
  {
    label: '新手導覽',
    icon: 'pi pi-compass',
    class: 'tour-onboarding-item',
    command: () => {
      restartOnboarding()
    },
  },
  {
    label: '修改密碼',
    icon: 'pi pi-key',
    command: () => {
      passwordDialogVisible.value = true
    },
  },
  {
    label: '登出',
    icon: 'pi pi-sign-out',
    command: () => {
      handleLogout()
    },
  },
])

const navItems = [
  { to: { name: 'front-home' }, label: '首頁', icon: 'pi-home' },
  { to: { name: 'front-new' }, label: '新增', icon: 'pi-plus-circle' },
  { to: { name: 'front-history' }, label: '歷史', icon: 'pi-list' },
]
</script>

<template>
  <div class="min-h-screen flex flex-col bg-[var(--color-surface)]">
    <AppHeader width="front" logo="horizontal">
      <template #nav>
        <div ref="topNav" class="relative flex items-center gap-1">
          <span class="nav-slide-indicator bg-white/15" :style="topIndicator" aria-hidden="true" />
          <RouterLink
            v-for="item in navItems"
            :key="item.label"
            :to="item.to"
            class="front-nav-link relative inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-white/80 hover:text-white transition-colors"
            active-class="is-active !text-white font-medium"
          >
            <i :class="['pi', item.icon]" />
            <span>{{ item.label }}</span>
          </RouterLink>
        </div>
      </template>
      <template #right>
        <UserBadge :user="auth.currentUser" :menu-items="userMenuItems" />
      </template>
    </AppHeader>

    <main class="flex-1 container mx-auto px-5 sm:px-4 pt-0 pb-28 lg:pb-8">
      <RouterView />
    </main>

    <nav
      class="fixed bottom-4 left-4 right-4 z-20 pointer-events-none flex justify-center lg:hidden"
    >
      <div
        ref="bottomNav"
        class="relative pointer-events-auto flex w-full max-w-md bg-white rounded-full shadow-lg border border-[var(--color-hairline)] p-1.5"
      >
        <span class="nav-slide-indicator bg-primary-50" :style="bottomIndicator" aria-hidden="true" />
        <RouterLink
          v-for="item in navItems"
          :key="item.label"
          :to="item.to"
          class="relative flex-1 flex flex-col items-center gap-0.5 py-1.5 rounded-full text-[var(--color-muted)] transition-colors"
          active-class="is-active !text-primary-700 font-medium"
        >
          <i :class="['pi', item.icon, 'text-lg']" />
          <span class="text-xs">{{ item.label }}</span>
        </RouterLink>
      </div>
    </nav>

    <PasswordChangeDialog v-model:visible="passwordDialogVisible" />
    <PwaInstallPrompt />
  </div>
</template>
