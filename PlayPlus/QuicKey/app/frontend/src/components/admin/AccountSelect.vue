<script setup lang="ts">
/**
 * 帳戶下拉（必選）。選項由使用端的 useAccountOptions 提供。
 * 帳戶一律在帳戶設定建立（PRD 第 20 條），這裡不提供當場新增；
 * 公司沒有帳戶時，用到它的表單入口都已停用，這裡不另外處理空清單。
 */
import Select from 'primevue/select'
import type { AccountOption } from '@/api/accounts'

defineProps<{
  inputId: string
  /** 外層 <label> 的 id：Select 不是原生表單元件，要靠它把標籤念給讀屏 */
  labelledBy: string
  options: AccountOption[]
  loading?: boolean
  invalid?: boolean
  disabled?: boolean
  errorId?: string
  /** 放在 Dialog 內當第一個欄位時，開啟後焦點落在這裡 */
  autofocus?: boolean
}>()
const model = defineModel<string | null>({ required: true })
</script>

<template>
  <Select
    v-model="model"
    :input-id="inputId"
    :options="options"
    option-label="name"
    option-value="id"
    placeholder="請選擇帳戶"
    empty-message="沒有可選的帳戶"
    :loading="loading"
    :invalid="invalid"
    :disabled="disabled"
    :aria-labelledby="labelledBy"
    :pt="{ label: { 'aria-required': 'true', 'aria-describedby': errorId, autofocus: autofocus || undefined } }"
    fluid
  />
</template>
