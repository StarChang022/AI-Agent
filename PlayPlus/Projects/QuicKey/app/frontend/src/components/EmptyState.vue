<script setup lang="ts">
withDefaults(
  defineProps<{
    icon?: string
    title: string
    description?: string
    variant?: 'card' | 'plain'
  }>(),
  {
    icon: 'pi pi-inbox',
    description: undefined,
    variant: 'card',
  },
)
</script>

<template>
  <div
    class="flex flex-col items-center text-center"
    :class="[variant === 'card' ? 'card-lg px-4 py-11' : 'py-8']"
  >
    <div
      class="w-16 h-16 rounded-2xl bg-[var(--color-surface)] flex items-center justify-center mb-3.5"
    >
      <i :class="[icon, 'text-3xl text-[var(--color-muted-soft)]']" />
    </div>
    <div class="text-sm text-[var(--color-ink)] font-semibold mb-1">{{ title }}</div>
    <div v-if="description" class="text-xs text-[var(--color-muted-soft)]">
      {{ description }}
    </div>
    <div v-if="$slots.action" class="mt-4">
      <slot name="action" />
    </div>
  </div>
</template>
