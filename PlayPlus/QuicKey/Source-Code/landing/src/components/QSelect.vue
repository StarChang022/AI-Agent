<script setup lang="ts">
/**
 * 下拉選單（依 Quickey Design System · Select 規格實作）
 * 外觀與互動對齊 design-system/design-select-date.html 的 .qds-select。
 * 鍵盤：↑↓ 移動、Home/End 跳頭尾、Enter/Space 選取、Esc 或 Tab 關閉。
 */
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

export interface SelectOption {
  value: string
  label: string
}

const props = withDefaults(
  defineProps<{
    id: string
    modelValue: string
    options: SelectOption[]
    placeholder?: string
    invalid?: boolean
    disabled?: boolean
    required?: boolean
    describedby?: string
    ariaLabel?: string
  }>(),
  { placeholder: '請選擇', invalid: false, disabled: false, required: false, ariaLabel: undefined },
)

const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const root = ref<HTMLElement>()
const trigger = ref<HTMLButtonElement>()
const panel = ref<HTMLUListElement>()
const open = ref(false)
const listId = `${props.id}-listbox`

const selectedIndex = computed(() => props.options.findIndex((o) => o.value === props.modelValue))
const selectedLabel = computed(() => (selectedIndex.value >= 0 ? props.options[selectedIndex.value].label : ''))

function optionEls(): HTMLElement[] {
  return Array.from(panel.value?.querySelectorAll<HTMLElement>('[role="option"]') ?? [])
}

function focusOption(i: number) {
  optionEls()[i]?.focus()
}

async function openPanel() {
  if (props.disabled || open.value) return
  open.value = true
  await nextTick()
  focusOption(selectedIndex.value >= 0 ? selectedIndex.value : 0)
}

function closePanel(returnFocus: boolean) {
  open.value = false
  if (returnFocus) trigger.value?.focus()
}

function toggle() {
  if (open.value) closePanel(true)
  else openPanel()
}

function choose(i: number) {
  const o = props.options[i]
  if (!o) return
  emit('update:modelValue', o.value)
  closePanel(true)
}

function moveTo(i: number) {
  const max = props.options.length - 1
  const next = Math.min(Math.max(i, 0), max)
  focusOption(next)
}

function currentFocusIndex(): number {
  return optionEls().indexOf(document.activeElement as HTMLElement)
}

function onTriggerKeydown(e: KeyboardEvent) {
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault()
    openPanel()
  }
}

function onPanelKeydown(e: KeyboardEvent) {
  const i = currentFocusIndex()
  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault()
      moveTo(i + 1)
      break
    case 'ArrowUp':
      e.preventDefault()
      moveTo(i - 1)
      break
    case 'Home':
      e.preventDefault()
      moveTo(0)
      break
    case 'End':
      e.preventDefault()
      moveTo(props.options.length - 1)
      break
    case 'Enter':
    case ' ':
      e.preventDefault()
      if (i >= 0) choose(i)
      break
    case 'Escape':
      e.preventDefault()
      closePanel(true)
      break
    case 'Tab':
      closePanel(false)
      break
  }
}

function onDocumentPointerDown(e: Event) {
  if (open.value && root.value && !root.value.contains(e.target as Node)) closePanel(false)
}

onMounted(() => document.addEventListener('mousedown', onDocumentPointerDown))
onBeforeUnmount(() => document.removeEventListener('mousedown', onDocumentPointerDown))
</script>

<template>
  <div ref="root" class="qselect" :class="{ 'is-open': open, 'is-invalid': invalid }">
    <button
      :id="id"
      ref="trigger"
      type="button"
      class="qselect-trigger"
      aria-haspopup="listbox"
      :aria-expanded="open ? 'true' : 'false'"
      :aria-controls="open ? listId : undefined"
      :aria-required="required ? 'true' : undefined"
      :aria-invalid="invalid ? 'true' : undefined"
      :aria-label="ariaLabel"
      :aria-describedby="describedby"
      :disabled="disabled"
      @click="toggle"
      @keydown="onTriggerKeydown"
    >
      <span class="qselect-value" :class="{ 'is-placeholder': !selectedLabel }">{{ selectedLabel || placeholder }}</span>
      <svg class="qselect-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
        <path d="M6 9l6 6 6-6" />
      </svg>
    </button>

    <ul v-if="open" :id="listId" ref="panel" class="qselect-panel" role="listbox" :aria-labelledby="id" @keydown="onPanelKeydown">
      <li
        v-for="(o, i) in options"
        :key="o.value"
        role="option"
        tabindex="-1"
        :aria-selected="i === selectedIndex ? 'true' : 'false'"
        :class="{ 'is-selected': i === selectedIndex }"
        @click="choose(i)"
      >
        {{ o.label }}
      </li>
    </ul>
  </div>
</template>

<style scoped>
.qselect {
  position: relative;
  width: 100%;
}
.qselect-trigger {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 44px;
  box-sizing: border-box;
  padding: 0 14px;
  font: inherit;
  font-size: 14px;
  color: var(--color-ink);
  text-align: left;
  background: var(--color-canvas);
  border: 1.5px solid var(--color-hairline);
  border-radius: var(--radius-control);
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.qselect-trigger:hover {
  border-color: var(--color-hairline-strong);
}
.qselect-trigger:focus-visible,
.qselect.is-open .qselect-trigger {
  outline: none;
  border-color: var(--color-primary-500);
  box-shadow: 0 0 0 3px var(--color-primary-100);
}
.qselect.is-invalid .qselect-trigger {
  border-color: #dc2626;
}
.qselect-trigger:disabled {
  color: var(--color-muted-soft);
  background: var(--color-surface);
  border-color: var(--color-hairline);
  cursor: not-allowed;
}
.qselect-value {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.qselect-value.is-placeholder {
  color: var(--color-muted-soft);
}
.qselect-chev {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
  color: var(--color-muted);
  transition: transform 0.15s ease;
}
.qselect.is-open .qselect-chev {
  transform: rotate(180deg);
}
.qselect-panel {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  z-index: 40;
  box-sizing: border-box;
  width: 100%;
  min-width: 100%;
  max-height: 264px;
  margin: 0;
  padding: 6px;
  overflow-y: auto;
  list-style: none;
  background: var(--color-canvas);
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-control);
  box-shadow: var(--shadow-float);
}
.qselect-panel [role='option'] {
  padding: 10px 12px;
  font-size: 14px;
  color: var(--color-ink);
  border-radius: 12px;
  cursor: pointer;
  outline: none;
  transition: background-color 0.1s ease;
}
.qselect-panel [role='option']:hover,
.qselect-panel [role='option']:focus-visible {
  background: var(--color-surface);
}
.qselect-panel [role='option'].is-selected {
  background: var(--color-primary-50);
  color: var(--color-primary-700);
  font-weight: 600;
}
.qselect-panel [role='option'].is-selected:hover,
.qselect-panel [role='option'].is-selected:focus-visible {
  background: var(--color-primary-100);
}
</style>
