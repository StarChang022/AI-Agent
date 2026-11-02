<script setup lang="ts">
/**
 * 期間選擇（period-picker）：預設期間＋自訂日期區間合成一個小尺寸控制項。
 * 見 design-system/design-select-date.html。
 * - 展開後只列出單純期間選項；實際起訖日固定顯示在選單底部。
 * - 選「自訂日期區間」在同一個 Popover 裡改顯示區間月曆（可選到日），選完關閉並回到按鈕。
 */
import { computed, nextTick, ref } from 'vue'
import Popover from 'primevue/popover'
import DatePicker from 'primevue/datepicker'
import { PERIOD_OPTIONS, periodLabel, periodRangeText, type Period, type PeriodPreset } from '@/utils/period'

const props = withDefaults(
  defineProps<{
    label?: string
    defaultPreset?: Exclude<PeriodPreset, 'custom'>
    size?: 'md' | 'sm'
  }>(),
  { size: 'md' },
)
const model = defineModel<Period>({ required: true })

const pop = ref<InstanceType<typeof Popover> | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)
const listRef = ref<HTMLUListElement | null>(null)
const mode = ref<'list' | 'calendar'>('list')
const open = ref(false)
const range = ref<(Date | null)[] | null>(null)

const text = computed(() => (model.value.preset === 'custom' ? '自訂日期區間' : periodLabel(model.value)))
const isCustom = computed(() => model.value.preset === 'custom' && !!model.value.start)
const defaultPreset = computed(() => props.defaultPreset ?? 'month')
const isDefault = computed(() => model.value.preset === defaultPreset.value && !model.value.start && !model.value.end)
const rangeText = computed(() => periodRangeText(model.value))

function toggle(e: Event) {
  mode.value = 'list'
  pop.value?.toggle(e)
}
function onShow() {
  open.value = true
  nextTick(() => {
    const el = listRef.value?.querySelector<HTMLElement>('[aria-selected="true"]') ?? listRef.value?.querySelector<HTMLElement>('[role="option"]')
    el?.focus()
  })
}
function onHide() {
  open.value = false
  mode.value = 'list'
}
function choose(v: string) {
  if (v === 'custom') {
    range.value = model.value.start ? [model.value.start, model.value.end ?? null] : null
    mode.value = 'calendar'
    return
  }
  model.value = { preset: v as Period['preset'] }
  pop.value?.hide()
  trigger.value?.focus()
}
function reset() {
  model.value = { preset: defaultPreset.value }
  pop.value?.hide()
  trigger.value?.focus()
}
function onRange(v: Date | Date[] | (Date | null)[] | null | undefined) {
  const arr = Array.isArray(v) ? (v as (Date | null)[]) : null
  range.value = arr
  if (arr && arr[0] instanceof Date && arr[1] instanceof Date) {
    model.value = { preset: 'custom', start: arr[0], end: arr[1] }
    pop.value?.hide()
    trigger.value?.focus()
  }
}
function onListKey(e: KeyboardEvent) {
  const items = Array.from(listRef.value?.querySelectorAll<HTMLElement>('[role="option"]') ?? [])
  const i = items.indexOf(document.activeElement as HTMLElement)
  if (e.key === 'ArrowDown') { e.preventDefault(); items[Math.min(i + 1, items.length - 1)]?.focus() }
  else if (e.key === 'ArrowUp') { e.preventDefault(); items[Math.max(i - 1, 0)]?.focus() }
  else if (e.key === 'Escape') { pop.value?.hide(); trigger.value?.focus() }
}
</script>

<template>
  <button
    ref="trigger"
    type="button"
    class="period-trigger"
    :class="[`is-${props.size}`, { 'is-custom': isCustom, 'is-open': open }]"
    aria-haspopup="listbox"
    :aria-expanded="open"
    :aria-label="(props.label ? props.label + '：' : '') + text"
    @click="toggle"
    @keydown.down.prevent="toggle"
  >
    <i class="pi pi-calendar" aria-hidden="true" />
    <span class="period-value">{{ text }}</span>
    <i class="pi pi-chevron-down period-chev" aria-hidden="true" />
  </button>
  <Popover ref="pop" class="period-pop qds-dropdown-pop" @show="onShow" @hide="onHide">
    <ul v-if="mode === 'list'" ref="listRef" class="period-list" role="listbox" :aria-label="props.label" @keydown="onListKey">
      <li
        v-for="o in PERIOD_OPTIONS"
        :key="o.value"
        role="option"
        tabindex="-1"
        :aria-selected="model.preset === o.value"
        :class="{ sel: model.preset === o.value }"
        @click="choose(o.value)"
        @keydown.enter.prevent="choose(o.value)"
        @keydown.space.prevent="choose(o.value)"
      >
        <span>{{ o.label }}</span>
      </li>
      <li
        role="option"
        tabindex="-1"
        class="period-custom"
        :aria-selected="model.preset === 'custom'"
        :class="{ sel: model.preset === 'custom' }"
        @click="choose('custom')"
        @keydown.enter.prevent="choose('custom')"
        @keydown.space.prevent="choose('custom')"
      >
        <span class="period-custom-row"><span>自訂日期區間</span><i class="pi pi-angle-right" aria-hidden="true" /></span>
      </li>
      <li class="period-current" role="presentation">
        <span class="period-current-head">
          <span>目前區間</span>
          <button v-if="!isDefault" type="button" @click="reset">重設</button>
        </span>
        <b>{{ rangeText }}</b>
      </li>
    </ul>
    <div v-else class="period-cal">
      <button type="button" class="link-btn period-back" @click="mode = 'list'">
        <i class="pi pi-chevron-left" aria-hidden="true" /> 返回
      </button>
      <DatePicker
        :model-value="range"
        selection-mode="range"
        inline
        :number-of-months="1"
        :max-date="new Date()"
        aria-label="選擇起訖日期"
        @update:model-value="onRange"
      />
      <p class="period-hint">{{ range && range[0] && !range[1] ? '請選擇結束日期' : '請選擇開始日期' }}</p>
    </div>
  </Popover>
</template>

<style scoped>
.period-trigger {
  display: inline-flex; align-items: center; gap: 8px; height: 40px; padding: 0 14px;
  background: #fff; border: 1.5px solid var(--color-hairline); border-radius: var(--radius-control);
  font: inherit; font-size: 16px; color: var(--color-slate); cursor: pointer; white-space: nowrap;
  font-variant-numeric: tabular-nums; transition: border-color .15s ease, box-shadow .15s ease;
}
.period-trigger.is-sm { height: 36px; padding-inline: 12px; font-size: 15px; }
.period-trigger:hover { border-color: var(--color-hairline-strong); }
.period-trigger:focus-visible, .period-trigger.is-open { outline: none; border-color: var(--color-primary-700); box-shadow: 0 0 0 3px var(--color-primary-100); }
.period-trigger.is-custom { color: var(--color-ink); }
.period-trigger .pi { font-size: 16px; color: var(--color-muted); }
.period-trigger.is-sm .pi { font-size: 15px; }
.period-chev { font-size: 12px !important; transition: transform .15s ease; }
.period-trigger.is-open .period-chev { transform: rotate(180deg); }
</style>

<style>
.period-pop { max-width: min(360px, calc(100vw - 32px)); }
.period-pop.p-popover { border-radius: var(--radius-card); border: 1px solid var(--color-hairline); box-shadow: var(--shadow-float); margin-top: 6px; }
.period-pop::before,
.period-pop::after,
.period-pop.p-popover::before,
.period-pop.p-popover::after,
.period-pop .p-popover-arrow,
.period-pop [data-pc-section='arrow'] { display: none !important; content: none !important; }
.period-pop .p-popover-content { padding: 8px; overflow: hidden; border-radius: inherit; }
.period-list { list-style: none; margin: 0; padding: 0; min-width: 220px; }
.period-list [role='option'] { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 10px 12px; border-radius: var(--radius-tag); font-size: 16px; color: var(--color-ink); cursor: pointer; outline: none; }
.period-list [role='option']:hover, .period-list [role='option']:focus-visible { background: var(--color-surface-soft); }
.period-list [role='option'].sel { background: var(--color-primary-50); color: var(--color-primary-700); font-weight: 600; }
.period-list .period-custom { margin-top: 2px; }
.period-custom-row { display: flex; align-items: center; justify-content: space-between; width: 100%; }
.period-custom-row .pi { font-size: 14px; color: var(--color-muted); }
.period-current { display: flex; flex-direction: column; gap: 2px; margin-top: 8px; padding: 10px 12px 2px; border-top: 1px solid var(--color-hairline); color: var(--color-muted); font-size: 13px; }
.period-current-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.period-current button { border: 0; background: transparent; padding: 0; color: var(--color-primary-700); font: inherit; font-size: 13px; font-weight: 600; cursor: pointer; }
.period-current button:hover { text-decoration: underline; text-underline-offset: 3px; }
.period-current button:focus-visible { outline: 2px solid var(--color-primary-700); outline-offset: 2px; border-radius: 4px; }
.period-current b { color: var(--color-slate); font-size: 14px; font-weight: 600; font-variant-numeric: tabular-nums; white-space: nowrap; }
.period-cal { padding: 4px; }
.period-back { display: inline-flex; align-items: center; gap: 4px; margin: 2px 4px 6px; }
.period-back .pi { font-size: 12px; }
.period-cal .p-datepicker,
.period-cal .p-datepicker-panel { width: min(320px, calc(100vw - 56px)); min-width: 0; border: none; box-shadow: none; padding: 0; }
.period-cal .p-datepicker-header { padding: 6px 4px; }
.period-cal .p-datepicker-title,
.period-cal .p-datepicker-select-month,
.period-cal .p-datepicker-select-year { font-size: 16px; }
.period-cal .p-datepicker-calendar,
.period-cal .p-datepicker-day-view { width: 100%; font-size: 14px; }
.period-cal .p-datepicker-weekday { font-size: 14px; }
.period-cal .p-datepicker-calendar th,
.period-cal .p-datepicker-calendar td { padding: 1px; }
.period-cal .p-datepicker-day { width: 34px; height: 34px; font-size: 14px; }
.period-hint { margin: 6px 4px 2px; font-size: 14px; color: var(--color-muted); }
</style>
