<script setup lang="ts">
import LogoMark from './LogoMark.vue'
import LogoHorizontal from './LogoHorizontal.vue'

withDefaults(
  defineProps<{
    brand?: string
    width?: 'wide' | 'front'
    logo?: 'icon' | 'horizontal'
  }>(),
  {
    brand: 'Quickey',
    width: 'wide',
    logo: 'icon',
  },
)
</script>

<template>
  <header class="sticky top-0 z-20 bg-primary-700 rounded-b-2xl sm:rounded-b-none">
    <div
      class="h-20 sm:h-14 flex items-center justify-between gap-4 px-4"
      :class="width === 'front' ? 'container mx-auto' : ''"
    >
      <div class="flex items-center gap-2 min-w-0">
        <div v-if="$slots.left" class="flex items-center">
          <slot name="left" />
        </div>
        <LogoHorizontal v-if="logo === 'horizontal'" :height="22" />
        <template v-else>
          <LogoMark :size="28" />
          <span class="font-semibold text-white truncate">
            {{ brand }}
          </span>
        </template>
      </div>
      <div v-if="$slots.nav || $slots.right" class="flex items-center gap-4">
        <nav v-if="$slots.nav" class="hidden lg:flex items-center gap-1">
          <slot name="nav" />
        </nav>
        <div v-if="$slots.right" class="flex items-center gap-3 text-white/85">
          <slot name="right" />
        </div>
      </div>
    </div>
  </header>
</template>
