<script setup lang="ts">
import { computed } from 'vue'
import { formatCurrency } from '@/utils/format'

type Size = 'sm' | 'md' | 'lg' | 'xl'
type Weight = 'normal' | 'medium' | 'semibold'
type Tone = 'ink' | 'muted' | 'primary' | 'danger'

const SIZE_CLASSES: Record<Size, string> = {
  sm: 'text-sm',
  md: 'text-base',
  lg: 'text-xl',
  xl: 'text-2xl',
}

const WEIGHT_CLASSES: Record<Weight, string> = {
  normal: 'font-normal',
  medium: 'font-medium',
  semibold: 'font-semibold',
}

const TONE_CLASSES: Record<Tone, string> = {
  ink: 'text-[var(--color-ink)]',
  muted: 'text-[var(--color-muted)]',
  primary: 'text-primary-700',
  danger: 'text-[var(--color-status-rejected)]',
}

const props = withDefaults(
  defineProps<{
    value: number
    size?: Size
    weight?: Weight
    tone?: Tone
  }>(),
  {
    size: 'md',
    weight: 'semibold',
    tone: 'ink',
  },
)

const sizeClass = computed(() => SIZE_CLASSES[props.size])
const weightClass = computed(() => WEIGHT_CLASSES[props.weight])
const toneClass = computed(() => TONE_CLASSES[props.tone])
</script>

<template>
  <span
    class="tabular-nums"
    :class="[sizeClass, weightClass, toneClass]"
  >
    {{ formatCurrency(value) }}
  </span>
</template>
