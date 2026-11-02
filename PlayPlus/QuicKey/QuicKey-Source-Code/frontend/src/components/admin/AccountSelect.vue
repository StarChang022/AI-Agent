<script setup lang="ts">
/**
 * 帳戶下拉（必選），下拉底部可直接新增帳戶；新增成功後自動選取。
 * 選項由使用端的 useAccountOptions 提供，新增後透過 created 補進清單。
 */
import { computed, ref } from 'vue'
import Button from 'primevue/button'
import Select from 'primevue/select'
import AccountFormDialog from '@/components/admin/AccountFormDialog.vue'
import type { AccountOption } from '@/api/accounts'
import type { Account } from '@/types/domain'

const props = defineProps<{
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
/** 新增視窗開著；放在 Dialog 內使用時，外層要據此停用 Esc 關閉 */
const creating = defineModel<boolean>('creating', { default: false })
const emit = defineEmits<{ created: [account: AccountOption] }>()

const selectRef = ref<{ hide: () => void } | null>(null)

const placeholder = computed(() =>
  !props.loading && props.options.length === 0 ? '尚無帳戶，請先新增' : '請選擇帳戶',
)

function openCreate() {
  selectRef.value?.hide()
  creating.value = true
}

/** 開啟視窗的底部按鈕已隨面板消失，關閉後焦點要回到下拉本身 */
function restoreFocus() {
  document.getElementById(props.inputId)?.focus()
}

function onSaved(account: Account) {
  emit('created', account)
  model.value = account.id
}
</script>

<template>
  <Select
    ref="selectRef"
    v-model="model"
    :input-id="inputId"
    :options="options"
    option-label="name"
    option-value="id"
    :placeholder="placeholder"
    :loading="loading"
    :invalid="invalid"
    :disabled="disabled"
    :aria-labelledby="labelledBy"
    :pt="{ label: { 'aria-required': 'true', 'aria-describedby': errorId, autofocus: autofocus || undefined } }"
    empty-message="尚無帳戶"
    fluid
  >
    <template #footer>
      <div class="account-select-footer">
        <Button label="新增帳戶" icon="pi pi-plus" text size="small" fluid @click="openCreate" />
      </div>
    </template>
  </Select>
  <AccountFormDialog v-model:visible="creating" @saved="onSaved" @after-hide="restoreFocus" />
</template>

<style scoped>
.account-select-footer {
  padding: 4px;
  border-top: 1px solid var(--color-hairline);
}
</style>
