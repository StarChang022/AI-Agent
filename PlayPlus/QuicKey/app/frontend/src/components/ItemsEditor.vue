<script setup lang="ts">
/**
 * 品項明細編輯區（支出 / 收入 / 代墊款表單共用）。
 * 品項選填、不強制與金額相等；小計 = 數量 × 單價，自動計算不可改。
 * 桌面一列一筆；手機卡片式：第 1 行品項名 + 刪除、第 2 行數量 / 單價 / 小計。
 */
import { useId } from 'vue'
import type { ExpenseItem } from '@/types/domain'
import Button from 'primevue/button'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'

withDefaults(
  defineProps<{
    /** 品項名稱欄的範例提示 */
    placeholder?: string
  }>(),
  { placeholder: '例：A4 影印紙' },
)

const items = defineModel<ExpenseItem[]>({ required: true })

/** 手機版 label for 用；同頁有多個編輯區時避免 id 撞名 */
const uid = useId()

function addItem() {
  items.value = [...items.value, { name: '', quantity: 1, unitPrice: 0, subtotal: 0 }]
}

function removeItem(i: number) {
  items.value = items.value.filter((_, idx) => idx !== i)
}

function recomputeSubtotal(it: ExpenseItem) {
  it.subtotal = (Number(it.quantity) || 0) * (Number(it.unitPrice) || 0)
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-2">
      <div class="field-label !mb-0">品項</div>
      <Button
        v-if="items.length > 0"
        type="button"
        label="新增品項"
        icon="pi pi-plus"
        size="small"
        text
        @click="addItem"
      />
    </div>
    <div v-if="items.length === 0" class="items-empty">
      <b>尚未加入品項</b>
      <span>品項為選填，需要明細時再新增。</span>
      <Button type="button" label="新增品項" icon="pi pi-plus" outlined @click="addItem" />
    </div>
    <div v-else class="space-y-3 sm:space-y-2">
      <!-- 桌面表頭（跟下方列同步：flex + 相同寬度 / gap） -->
      <div class="hidden sm:flex items-center gap-2 field-sublabel" aria-hidden="true">
        <div class="flex-1 basis-0 min-w-0">品項名稱</div>
        <div class="w-32">數量</div>
        <div class="w-32">單價</div>
        <div class="w-32">小計</div>
        <div class="w-8" />
      </div>

      <div v-for="(it, i) in items" :key="i">
        <!-- 桌面：刪除按鈕貼齊小計右邊 -->
        <div class="hidden sm:flex items-center gap-2">
          <InputText
            v-model="it.name"
            :placeholder="placeholder"
            :aria-label="`第 ${i + 1} 筆品項名稱`"
            class="flex-1 basis-0 min-w-0"
          />
          <InputNumber
            v-model="it.quantity"
            :min="0"
            :min-fraction-digits="0"
            :max-fraction-digits="0"
            :aria-label="`第 ${i + 1} 筆數量`"
            class="w-32"
            input-class="w-full"
            placeholder="數量"
            @update:model-value="recomputeSubtotal(it)"
          />
          <InputNumber
            v-model="it.unitPrice"
            :min="0"
            :min-fraction-digits="0"
            :max-fraction-digits="0"
            :aria-label="`第 ${i + 1} 筆單價`"
            class="w-32"
            input-class="w-full"
            placeholder="單價"
            @update:model-value="recomputeSubtotal(it)"
          />
          <InputNumber
            :model-value="it.subtotal"
            disabled
            :min-fraction-digits="0"
            :max-fraction-digits="0"
            :aria-label="`第 ${i + 1} 筆小計`"
            class="w-32"
            input-class="w-full"
            placeholder="小計"
          />
          <Button
            type="button"
            severity="secondary"
            text
            rounded
            icon="pi pi-trash"
            size="small"
            :aria-label="`移除第 ${i + 1} 筆品項`"
            class="flex-none"
            @click="removeItem(i)"
          />
        </div>

        <!-- 手機：卡片式 -->
        <div class="sm:hidden flex flex-col gap-2 rounded-lg border border-[var(--color-hairline)] p-2">
          <div class="flex items-center gap-2">
            <InputText
              v-model="it.name"
              :placeholder="placeholder"
              :aria-label="`第 ${i + 1} 筆品項名稱`"
              class="flex-1"
            />
            <Button
              type="button"
              severity="secondary"
              text
              rounded
              icon="pi pi-trash"
              size="small"
              :aria-label="`移除第 ${i + 1} 筆品項`"
              class="flex-none"
              @click="removeItem(i)"
            />
          </div>
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="block field-sublabel mb-1" :for="`${uid}-qty-${i}`">數量</label>
              <InputNumber
                v-model="it.quantity"
                :input-id="`${uid}-qty-${i}`"
                :aria-label="`第 ${i + 1} 筆數量`"
                :min="0"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                class="w-full"
                input-class="w-full"
                placeholder="0"
                @update:model-value="recomputeSubtotal(it)"
              />
            </div>
            <div>
              <label class="block field-sublabel mb-1" :for="`${uid}-unit-${i}`">單價</label>
              <InputNumber
                v-model="it.unitPrice"
                :input-id="`${uid}-unit-${i}`"
                :aria-label="`第 ${i + 1} 筆單價`"
                :min="0"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                class="w-full"
                input-class="w-full"
                placeholder="0"
                @update:model-value="recomputeSubtotal(it)"
              />
            </div>
            <div>
              <label class="block field-sublabel mb-1" :for="`${uid}-sub-${i}`">小計</label>
              <InputNumber
                :model-value="it.subtotal"
                :input-id="`${uid}-sub-${i}`"
                :aria-label="`第 ${i + 1} 筆小計`"
                disabled
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                class="w-full"
                input-class="w-full"
                placeholder="0"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
