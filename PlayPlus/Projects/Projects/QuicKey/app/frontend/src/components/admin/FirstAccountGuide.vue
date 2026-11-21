<script setup lang="ts">
/**
 * 新增帳戶視窗旁的一步引導說明卡（PRD 第 22 條「沒有任何帳戶」）。
 * AccountsView 在引導開啟的新增帳戶視窗打開時顯示；不改 AccountFormDialog 本身。
 *
 * 位置與操作：
 * - 卡片 Teleport 進視窗（.p-dialog）的頁尾，以視窗為定位基準放在視窗外面：
 *   寬螢幕在視窗右邊，視窗旁放不下（< 1120px，含手機）就接在視窗下方、貼近畫面底部，
 *   同時把視窗往上推、限制高度（styles/index.css `.p-dialog.has-first-setup-guide`），
 *   卡片不會擋住欄位與「儲存」。
 * - 放進視窗裡才會疊在 modal 遮罩上面，而且在 PrimeVue 的焦點鎖定範圍內，
 *   鍵盤 Tab 經過「儲存」後就會到「結束引導」。
 * - 「結束引導」只收起卡片，視窗不關，焦點移回第一個欄位。
 *
 * dialogSelector 指向視窗本身（AccountsView 透過屬性傳到 Dialog 的根元素）。
 */
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import GuideCard from '@/components/admin/GuideCard.vue'

const props = defineProps<{ dialogSelector: string }>()
const emit = defineEmits<{ end: [] }>()

const DIALOG_CLASS = 'has-first-setup-guide'
const target = ref<HTMLElement | null>(null)
const card = ref<InstanceType<typeof GuideCard> | null>(null)
let dialog: HTMLElement | null = null
let observer: ResizeObserver | null = null
let cancelled = false

/** 視窗由 PrimeVue 掛到 body，打開後下一個畫格才出現；最多等 2 秒 */
async function waitForDialog(): Promise<HTMLElement | null> {
  const start = Date.now()
  while (!cancelled && Date.now() - start < 2000) {
    const el = document.querySelector<HTMLElement>(props.dialogSelector)
    if (el?.querySelector('.p-dialog-footer')) return el
    await new Promise((r) => setTimeout(r, 50))
  }
  return null
}

onMounted(async () => {
  dialog = await waitForDialog()
  if (!dialog || cancelled) return
  dialog.classList.add(DIALOG_CLASS)
  target.value = dialog.querySelector<HTMLElement>('.p-dialog-footer')
  await nextTick()
  const el = card.value?.$el as HTMLElement | undefined
  if (!el) return
  // 視窗打開時讀屏一併念出說明
  dialog.setAttribute('aria-describedby', card.value!.descId)
  observer = new ResizeObserver(([entry]) => {
    dialog?.style.setProperty('--first-setup-guide-h', `${entry.target.getBoundingClientRect().height}px`)
  })
  observer.observe(el)
})

onBeforeUnmount(() => {
  cancelled = true
  observer?.disconnect()
  if (dialog) {
    dialog.classList.remove(DIALOG_CLASS)
    dialog.style.removeProperty('--first-setup-guide-h')
    dialog.removeAttribute('aria-describedby')
  }
  dialog = null
})

/** 卡片收起後焦點會掉出視窗，先移回第一個欄位 */
function end() {
  dialog?.querySelector<HTMLElement>('.p-dialog-content input')?.focus()
  emit('end')
}
</script>

<template>
  <Teleport v-if="target" :to="target">
    <GuideCard
      ref="card"
      class="first-account-guide"
      label="建立第一個帳戶引導"
      progress="第 1 步，共 1 步"
      title="填寫第一個帳戶"
      @end="end"
    >
      <ul>
        <li><b>帳戶名稱</b>：方便辨認的名稱，例如「永豐-總公司」「零用金」。</li>
        <li><b>起始月份</b>：從哪個月開始記帳。</li>
        <li><b>起始金額</b>：起始月份月初這個帳戶的實際餘額。</li>
      </ul>
    </GuideCard>
  </Teleport>
</template>

<style scoped>
/* 以視窗（.p-dialog 有 transform，是定位基準）為準，放在視窗外面 */
.first-account-guide {
  position: absolute;
  top: 0;
  left: calc(100% + var(--space-md));
  width: 320px;
}
@media (max-width: 1119.98px) {
  .first-account-guide {
    top: calc(100% + var(--space-sm));
    left: 0;
    width: 100%;
  }
}
</style>
