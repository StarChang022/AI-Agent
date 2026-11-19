<script setup lang="ts">
/**
 * 導覽結束後的首次設定詢問視窗（PRD 第 22 條）。掛在 AdminLayout，任何後台頁都能出現。
 * - 建立第一個帳戶：「建立帳戶」前往帳戶設定並自動開啟新增帳戶視窗
 * - 新增第一筆收支：「新增支出」「新增收入」進入新增頁逐步引導
 * 選「之後再說」、按 Esc 或右上角關閉都結束引導。PrimeVue Dialog（modal）內建 Esc 關閉與焦點留在視窗內；
 * 主要按鈕加 autofocus，開啟時焦點落在它而不是右上角 X。手機上按鈕直向排列、主要按鈕在最上面。
 */
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import { useOnboardingStore } from '@/stores/onboarding'
import { useFirstSetupGuide } from '@/composables/useFirstSetupGuide'

const onboarding = useOnboardingStore()
const { chooseCreateAccount, chooseRecord, skip } = useFirstSetupGuide()

function onVisible(v: boolean) {
  if (!v) skip()
}
</script>

<template>
  <Dialog
    :visible="onboarding.firstSetupStep === 'account-ask'"
    modal
    header="建立第一個帳戶"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="onVisible"
  >
    <p class="text-sm text-[var(--color-slate)]">
      每筆收支都要指定收付帳戶，例如「永豐-總公司」「零用金」。是否現在建立第一個帳戶？
    </p>

    <template #footer>
      <div class="first-setup-actions">
        <Button label="之後再說" text severity="secondary" @click="skip" />
        <Button label="建立帳戶" icon="pi pi-plus" class="ml-auto" autofocus @click="chooseCreateAccount" />
      </div>
    </template>
  </Dialog>

  <Dialog
    :visible="onboarding.firstSetupStep === 'record'"
    modal
    header="新增第一筆收支"
    :style="{ width: 'min(92vw, 440px)' }"
    @update:visible="onVisible"
  >
    <p class="text-sm text-[var(--color-slate)]">
      帳戶已經準備好了，是否現在記下第一筆支出或收入？之後也可以從 Excel 或憑證檔案批次匯入。
    </p>

    <template #footer>
      <div class="first-setup-actions">
        <Button label="之後再說" text severity="secondary" @click="skip" />
        <Button label="新增收入" icon="pi pi-plus" outlined class="ml-auto" @click="chooseRecord('income')" />
        <Button label="新增支出" icon="pi pi-plus" autofocus @click="chooseRecord('expense')" />
      </div>
    </template>
  </Dialog>
</template>

<style scoped>
.first-setup-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-xs);
  width: 100%;
}
@media (max-width: 639.98px) {
  /* 直向排列、每顆佔滿寬度；column-reverse 讓主要按鈕在最上面、「之後再說」在最下面 */
  .first-setup-actions {
    flex-direction: column-reverse;
    align-items: stretch;
  }
  .first-setup-actions > .p-button {
    width: 100%;
    margin-left: 0;
  }
}
</style>
