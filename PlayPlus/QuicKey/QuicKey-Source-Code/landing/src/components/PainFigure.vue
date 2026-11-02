<script setup lang="ts">
withDefaults(
  defineProps<{
    variant: 'receipts' | 'chart' | 'tags' | 'alarm' | 'coin' | 'lock'
    body?: string
    label: string
  }>(),
  { body: 'var(--color-primary-500)' },
)
</script>

<template>
  <svg class="pain-figure" viewBox="0 0 200 150" role="img" :aria-label="label">
    <ellipse cx="100" cy="142" rx="56" ry="6" fill="#c9cedd" opacity="0.5" />
    <rect x="68" y="92" width="64" height="48" rx="22" :fill="body" />
    <circle cx="100" cy="62" r="24" fill="#f5d0b5" />
    <path d="M76 58 Q100 26 124 58 Q116 42 100 40 Q84 42 76 58Z" fill="#2a3140" />
    <circle cx="92" cy="64" r="2.5" fill="#2a3140" />
    <circle cx="108" cy="64" r="2.5" fill="#2a3140" />
    <path d="M94 74 Q100 78 106 74" stroke="#8a4b2a" stroke-width="2" fill="none" stroke-linecap="round" />

    <!-- 收據堆疊：對帳 -->
    <g v-if="variant === 'receipts'" class="bob">
      <rect x="140" y="34" width="36" height="46" rx="4" fill="var(--color-canvas)" stroke="#c9cedd" stroke-width="2" transform="rotate(8 158 57)" />
      <rect x="144" y="48" width="36" height="46" rx="4" fill="var(--color-canvas)" stroke="#c9cedd" stroke-width="2" transform="rotate(-6 162 71)" />
      <line x1="150" y1="62" x2="172" y2="62" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
      <line x1="150" y1="72" x2="168" y2="72" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
    </g>

    <!-- 報表：看不懂 -->
    <g v-if="variant === 'chart'">
      <rect x="136" y="60" width="54" height="66" rx="8" fill="var(--color-canvas)" stroke="#c9cedd" stroke-width="2" />
      <rect class="grow" x="144" y="94" width="8" height="26" rx="2" fill="var(--color-primary-300)" />
      <rect class="grow grow-2" x="158" y="82" width="8" height="38" rx="2" fill="var(--color-primary-500)" />
      <rect class="grow grow-3" x="172" y="104" width="8" height="16" rx="2" fill="var(--color-primary-200)" />
      <g class="bob-slow">
        <circle cx="172" cy="34" r="16" fill="#fef3c7" />
        <text x="172" y="41" text-anchor="middle" font-size="20" font-weight="700" fill="#b45309">?</text>
      </g>
    </g>

    <!-- 類別：不知道選哪個 -->
    <g v-if="variant === 'tags'">
      <g class="bob">
        <rect x="140" y="36" width="46" height="28" rx="6" fill="var(--color-canvas)" stroke="#c9cedd" stroke-width="2" />
        <circle cx="148" cy="50" r="3" fill="#c9cedd" />
        <line x1="157" y1="46" x2="180" y2="46" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
        <line x1="157" y1="55" x2="172" y2="55" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
      </g>
      <g class="bob-slow">
        <rect x="140" y="76" width="46" height="28" rx="6" fill="var(--color-canvas)" stroke="#c9cedd" stroke-width="2" />
        <circle cx="148" cy="90" r="3" fill="#c9cedd" />
        <line x1="157" y1="86" x2="180" y2="86" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
        <line x1="157" y1="95" x2="172" y2="95" stroke="#c9cedd" stroke-width="3" stroke-linecap="round" />
      </g>
      <text x="32" y="46" font-size="22" font-weight="700" fill="#b45309" class="bob">?</text>
    </g>

    <!-- 警示：超預算 -->
    <g v-if="variant === 'alarm'">
      <g class="bob-slow">
        <path d="M168 38 L192 80 L144 80 Z" fill="#f59e0b" />
        <text x="168" y="70" text-anchor="middle" font-size="18" font-weight="700" fill="var(--color-canvas)">!</text>
      </g>
      <rect x="132" y="112" width="60" height="10" rx="5" fill="#e3e6ec" />
      <rect class="grow" x="132" y="112" width="60" height="10" rx="5" fill="#dc2626" />
    </g>

    <!-- 硬幣：等待撥款 -->
    <g v-if="variant === 'coin'">
      <g class="fall">
        <circle cx="160" cy="60" r="12" fill="#f59e0b" />
        <text x="160" y="65" text-anchor="middle" font-size="13" font-weight="700" fill="var(--color-canvas)">$</text>
      </g>
      <g class="blink" fill="#a6acb8">
        <circle cx="150" cy="118" r="4" />
        <circle cx="162" cy="118" r="4" />
        <circle cx="174" cy="118" r="4" />
      </g>
    </g>

    <!-- 鎖：怕改錯記錄 -->
    <g v-if="variant === 'lock'" class="bob">
      <path d="M148 64 V54 A10 10 0 0 1 168 54 V64" fill="none" stroke="#485266" stroke-width="5" stroke-linecap="round" />
      <rect x="142" y="62" width="32" height="26" rx="6" fill="#485266" />
      <circle cx="158" cy="75" r="3" fill="var(--color-canvas)" />
    </g>
  </svg>
</template>
