<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { User } from '@/types/domain'
import { ROLE_LABELS } from '@/constants/user'
import { useOnboardingStore } from '@/stores/onboarding'
import Menu from 'primevue/menu'

/**
 * Header 右側使用者徽章：點名字/頭像展開下拉選單。
 * `menuItems` 由 FrontLayout / AdminLayout 決定（例如「修改密碼」、「登出」）。
 *
 * 額外 hook：watch `onboarding.userMenuOpen`，讓 tour 尾步能程式化把 popup
 * 打開/關閉，好對「新手導覽」項目做 highlight。用 dispatch click 走原本的
 * @click 流程（menuRef.toggle(event) 需要 event.currentTarget 做定位）。
 */
interface MenuItem {
  label: string
  icon?: string
  command?: () => void
  class?: string
}

const props = defineProps<{
  user: User | null
  menuItems: MenuItem[]
}>()

const initial = computed(() => props.user?.name.charAt(0) ?? '?')
const roleLabel = computed(() =>
  props.user ? ROLE_LABELS[props.user.role] : '訪客',
)
const displayName = computed(() => props.user?.name ?? '未登入')
const accountLabel = computed(() => props.user?.email ?? '尚未登入帳號')

const menuRef = ref<InstanceType<typeof Menu> | null>(null)
const triggerRef = ref<HTMLButtonElement | null>(null)
const onboarding = useOnboardingStore()

function toggleMenu(event: MouseEvent) {
  // Tour 尾步（userMenuOpen === true）期間強制保持開啟：改用 show() 而非
  // toggle()，避免使用者/程式重覆點 trigger 造成 toggle 關閉，讓「新手導覽」
  // 項目 highlight 中斷。tour 結束（onDestroyed / onPrevClick）會把 store 的
  // userMenuOpen 設回 false，此時 toggle 又恢復預設行為。
  if (onboarding.userMenuOpen) {
    menuRef.value?.show(event)
    return
  }
  menuRef.value?.toggle(event)
}

watch(
  () => onboarding.userMenuOpen,
  (open) => {
    if (open) {
      triggerRef.value?.click()
    } else {
      menuRef.value?.hide()
    }
  },
)
</script>

<template>
  <div class="flex items-center">
    <button
      ref="triggerRef"
      type="button"
      aria-haspopup="true"
      aria-label="開啟使用者選單"
      data-tour="user-menu-trigger"
      class="flex items-center gap-2 rounded-full pl-3.5 pr-2.5 py-1 hover:bg-white/10 transition-colors"
      @click="toggleMenu"
    >
      <span class="hidden md:inline text-[15px] font-semibold text-white">{{ displayName }}</span>
      <div
        class="w-9 h-9 rounded-full bg-white flex items-center justify-center text-primary-700 font-semibold flex-shrink-0"
      >
        {{ initial }}
      </div>
      <i class="pi pi-chevron-down text-xs text-white/70" aria-hidden="true" />
    </button>

    <Menu ref="menuRef" :model="menuItems" popup>
      <template #start>
        <div class="menu-head user-menu-head">
          <div>{{ displayName }}<span class="sep" aria-hidden="true" />{{ roleLabel }}</div>
          <div class="user-menu-account">{{ accountLabel }}</div>
        </div>
      </template>
    </Menu>
  </div>
</template>
