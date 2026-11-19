<script setup lang="ts">
/**
 * 發生日期標籤旁的 ⓘ 說明（PRD 第 23 條）：點擊開關浮層，點空白處或按 Esc 關閉；
 * 手機以點擊開啟，不依賴滑鼠停留。收入、支出共用同一段說明，只說明發生日期（PRD 第 23 條）。
 */
import { ref, useId } from 'vue'
import Popover from 'primevue/popover'

const pop = ref<InstanceType<typeof Popover> | null>(null)
const open = ref(false)
const panelId = `occurred-help-${useId()}`
</script>

<template>
  <button
    type="button"
    class="occurred-help-btn"
    aria-label="發生日期說明"
    :aria-expanded="open"
    :aria-controls="open ? panelId : undefined"
    @click="pop?.toggle($event)"
  >
    <i class="pi pi-info-circle" aria-hidden="true" />
  </button>
  <Popover ref="pop" aria-label="發生日期說明" @show="open = true" @hide="open = false">
    <dl :id="panelId" class="occurred-help">
      <div>
        <dt>發生日期</dt>
        <dd>生意完成或費用發生的日期，決定這筆收支計入哪個月的損益。</dd>
      </div>
    </dl>
  </Popover>
</template>

<style scoped>
.occurred-help-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--color-muted);
  cursor: pointer;
}
.occurred-help-btn:hover { color: var(--color-ink); background: var(--color-canvas); }
.occurred-help-btn:focus-visible { outline: 2px solid var(--primary-solid); outline-offset: 2px; }
.occurred-help-btn .pi { font-size: 14px; }

.occurred-help {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-width: 300px;
  margin: 0;
  font-size: 14px;
  line-height: 1.5;
}
.occurred-help dt { font-weight: 600; color: var(--color-ink); }
.occurred-help dd { margin: 2px 0 0; color: var(--color-slate); }
</style>
