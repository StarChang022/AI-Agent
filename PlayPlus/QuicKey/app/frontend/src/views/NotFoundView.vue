<script setup lang="ts">
import { RouterLink } from 'vue-router'
import LogoMark from '@/components/LogoMark.vue'
import Button from 'primevue/button'
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
        </div>

        <div class="card-lg px-6 py-10 text-center flex flex-col items-center">
          <div
            class="w-16 h-16 rounded-2xl bg-[var(--color-surface)] flex items-center justify-center mb-4"
            aria-hidden="true"
          >
            <i class="pi pi-compass text-3xl text-[var(--color-muted-soft)]" />
          </div>
          <div class="text-5xl font-bold text-primary-700 tracking-tight mb-2">
            404
          </div>
          <h1 class="text-sm font-semibold text-[var(--color-ink)] mb-1">
            找不到這個頁面
          </h1>
          <p class="text-xs text-[var(--color-muted)] mb-6 leading-relaxed">
            網址可能有誤，或這個頁面已經移除。
          </p>
          <RouterLink to="/login" class="w-full">
            <Button label="回到前台登入頁" class="w-full" />
          </RouterLink>
        </div>
      </div>
    </main>
  </div>
</template>
