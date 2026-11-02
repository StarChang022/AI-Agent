<script setup lang="ts">
/** 請款列表工具列：搜尋、類別、費用日區間、金額區間、清除篩選、合計。 */
import { computed, onMounted, ref } from 'vue'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import MultiSelect from 'primevue/multiselect'
import { listCategories, type Category } from '@/api/categories'
import type { ReimbursementFilters } from '@/composables/useReimbursementFilters'
import SearchInput from '@/components/qds/SearchInput.vue'
import AmountRange from '@/components/qds/AmountRange.vue'

const props = withDefaults(defineProps<{ filters: ReimbursementFilters; filtered: boolean; showSearch?: boolean }>(), {
  showSearch: true,
})
defineEmits<{ reset: [] }>()

const activeCategories = ref<Category[]>([])
onMounted(async () => {
  try {
    activeCategories.value = await listCategories({ kind: 'expense' })
  } catch {
    activeCategories.value = []
  }
})
const options = computed(() => activeCategories.value.map((c) => ({ value: c.id, label: c.name })))
const f = computed(() => props.filters)
</script>

<template>
  <div class="dash-filter">
    <SearchInput v-if="showSearch" v-model="f.keyword" placeholder="搜尋申請人、說明、廠商" />
    <MultiSelect
      :show-toggle-all="false"
      v-model="f.categories"
      :options="options"
      option-label="label"
      option-value="value"
      placeholder="全部類別"
      size="small"
      :max-selected-labels="2"
      selected-items-label="已選 {0} 類"
      class="w-[160px]"
      aria-label="類別"
    />
    <DatePicker
      v-model="f.dateRange"
      selection-mode="range"
      date-format="yy/mm/dd"
      placeholder="費用日區間"
      show-icon
      icon-display="input"
      :manual-input="false"
      size="small"
      class="w-[230px]"
      aria-label="費用日區間"
    />
    <AmountRange v-model:min="f.min" v-model:max="f.max" />
    <Button v-if="filtered" label="清除篩選" text size="small" @click="$emit('reset')" />
  </div>
</template>
