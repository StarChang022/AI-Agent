<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import AuthShell from '@/components/AuthShell.vue'
import Message from 'primevue/message'

/**
 * 驗證信已寄出提示頁（public route `/admin/signup/verify?email=`）。
 *
 * 註冊 payload（密碼、公司資訊）已於 SignupView 送出時連同 token 寫入後端，
 * 使用者點完信中連結即完成註冊。若沒收到信或連結過期，請回註冊頁重新填寫。
 */

const route = useRoute()

const email = computed(() =>
  typeof route.query.email === 'string' ? route.query.email : '',
)
</script>

<template>
  <AuthShell panel-label="驗證 Email">
    <div class="auth-brand">
      <span
        class="pi pi-envelope text-4xl text-primary-700 mb-3"
        aria-hidden="true"
      />
      <h1 class="auth-title">請到信箱完成驗證</h1>
    </div>

    <div v-if="email" class="auth-form">
      <p class="text-sm text-[var(--color-ink)] leading-7 text-center">
        驗證信已寄至
        <span class="font-semibold break-all">{{ email }}</span>
        <br />
        請在 30 分鐘內點擊信中的連結完成註冊。
      </p>

      <Message severity="info" :closable="false">
        <div class="text-sm leading-6">
          沒收到信、Email 填錯或連結過期，請回註冊頁重新填寫資料。
        </div>
      </Message>

      <RouterLink
        :to="{ name: 'admin-signup' }"
        class="block w-full text-center py-2 px-4 rounded-md border border-[var(--color-primary-700)] text-primary-700 hover:bg-primary-50 text-sm"
      >
        重新填寫註冊資料
      </RouterLink>
    </div>

    <div v-else class="auth-form">
      <Message severity="error" :closable="false">
        找不到註冊資料，請回註冊頁重新填寫。
      </Message>
      <RouterLink
        :to="{ name: 'admin-signup' }"
        class="block w-full text-center py-2 px-4 rounded-md bg-primary-700 text-white hover:bg-primary-800 text-sm"
      >
        前往註冊
      </RouterLink>
      <div class="auth-links">
        已完成驗證？
        <RouterLink :to="{ name: 'admin-login' }" class="link-btn">
          登入後台
        </RouterLink>
      </div>
    </div>
  </AuthShell>
</template>
