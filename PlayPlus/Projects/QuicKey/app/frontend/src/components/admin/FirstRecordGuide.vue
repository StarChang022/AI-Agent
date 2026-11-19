<script setup lang="ts">
/**
 * 新增第一筆收支的逐步引導（PRD 第 22 條）。放在支出／收入新增頁，v-if 由頁面依引導狀態決定。
 *
 * 不用 driver.js：driver 啟動時會把頁面其他元素設成不可點、把 Tab 限制在提示框與打亮區塊內，
 * 而下拉選單、日期選擇器的面板掛在 body 下，會被擋住、也蓋在遮罩下面，表單就沒辦法操作。
 * 這裡改成不遮罩：用外框打亮目前區塊（styles/index.css `.first-record-guide-target`），
 * 說明固定在畫面底部，表單照常操作，Tab 順序不受影響。
 *
 * 區塊用表單上的 data-guide 標記：record-upload / record-basic / record-amount /
 * record-category / record-payout / record-submit。
 * 按「下一步」不檢查必填；儲存由表單原本的檢查提示缺漏，成功後由頁面呼叫 completeRecord 結束。
 * 儲存失敗（saveFailure 變動）時停在第 6 步、不捲動（表單會自己捲到錯誤欄位），只把說明換成請使用者修正。
 * 卡片固定在底部，引導期間在捲動區 .admin-main 設 scroll-padding-bottom，聚焦到下緣的欄位不會被卡片蓋住。
 * Esc 不結束引導：Esc 留給下拉、日期面板與對話框關閉自己，避免誤關。
 */
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import Button from 'primevue/button'
import GuideCard from '@/components/admin/GuideCard.vue'
import type { RecordKind } from '@/composables/useFirstSetupGuide'
import type { DocumentType } from '@/types/domain'

const props = defineProps<{
  kind: RecordKind
  /** 憑證類型：收據的金額在基本資料區，第 2、3 步說明跟著換 */
  documentType: DocumentType
  /** 辨識中表單暫停編輯：先停在目前這步，辨識完成才能換步 */
  recognizing?: boolean
  /** 儲存失敗；seq 每次失敗遞增。invalid = 表單檢查沒過，error = 送出後失敗（原因見提示訊息） */
  saveFailure?: { reason: 'invalid' | 'error'; seq: number } | null
}>()
const emit = defineEmits<{ end: [] }>()

interface GuideStep {
  target: string
  title: string
  description: string
}

const steps = computed<GuideStep[]>(() => {
  const expense = props.kind === 'expense'
  const receipt = props.documentType === 'receipt'
  return [
    {
      target: 'record-upload',
      title: '上傳憑證並辨識',
      description: '上傳發票或收據後按「開始辨識」，日期、金額、品項等內容會自動帶入。沒有憑證也可以直接按「下一步」，改成手動輸入。',
    },
    {
      target: 'record-basic',
      title: '確認基本資料',
      description: receipt
        ? `選擇憑證類型，確認發生日期、${expense ? '賣方' : '客戶'}與總金額。`
        : expense
          ? '選擇憑證類型，確認發票日期（發票才有）、發生日期、賣方與發票號碼。'
          : '選擇憑證類型，確認發票日期（發票才有）、發生日期、客戶與發票號碼。',
    },
    {
      target: 'record-amount',
      title: receipt ? '品項明細' : '確認金額',
      description: receipt
        ? '品項明細是選填，需要時再新增。'
        : '輸入或確認金額。品項明細是選填，需要時再新增。',
    },
    {
      target: 'record-category',
      title: '選擇類別與帳戶',
      description: expense
        ? '選擇費用類別，以及這筆錢從哪個帳戶付出。'
        : '選擇收入類別，以及這筆錢收進哪個帳戶。',
    },
    {
      target: 'record-payout',
      title: expense ? '應付日期與付款狀態' : '應收日期與收款狀態',
      description: expense
        ? '確認應付日期，選擇付款狀態；已經付款就選「已付款」並填實付日期，還沒付款就維持待付款。'
        : '確認應收日期，選擇收款狀態；已經收到款項就選「已收款」並填實收日期，還沒收到就維持待收款。',
    },
    {
      target: 'record-submit',
      title: '儲存',
      description: '確認無誤後按「建立」。有漏填的欄位會標示出來，補齊後再按一次。',
    },
  ]
})

const index = ref(0)
/** 最後一次儲存失敗的原因；換到其他步驟時清掉 */
const failedReason = ref<'invalid' | 'error' | null>(null)
const step = computed(() => {
  const s = steps.value[index.value]
  if (s.target !== 'record-submit' || !failedReason.value) return s
  return {
    ...s,
    title: '還不能儲存',
    description:
      failedReason.value === 'invalid'
        ? '有欄位需要補上或修正，已在表單上標示出來。修改後再按「建立」。'
        : '這次沒有儲存成功，請依畫面上的提示處理後，再按「建立」。',
  }
})
const isFirst = computed(() => index.value === 0)
const isLast = computed(() => index.value === steps.value.length - 1)
const progressText = computed(() => `第 ${index.value + 1} 步 / 共 ${steps.value.length} 步`)

const TARGET_CLASS = 'first-record-guide-target'
let current: HTMLElement | null = null

function reducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

/** 打亮目前這步的區塊；scroll 時捲到畫面上方（捲動區是 .admin-main，scrollIntoView 會自己找） */
function highlight(scroll = true) {
  current?.classList.remove(TARGET_CLASS)
  current = document.querySelector<HTMLElement>(`[data-guide="${step.value.target}"]`)
  if (!current) return
  current.classList.add(TARGET_CLASS)
  if (scroll) current.scrollIntoView({ block: 'start', behavior: reducedMotion() ? 'auto' : 'smooth' })
}

function next() {
  if (!isLast.value && !props.recognizing) index.value += 1
}
function prev() {
  if (!isFirst.value && !props.recognizing) index.value -= 1
}

/** 儲存失敗帶到第 6 步時不捲動，讓表單停在它捲到的錯誤欄位 */
let skipScroll = false
watch(index, () => {
  if (!isLast.value) failedReason.value = null
  const scroll = !skipScroll
  skipScroll = false
  void nextTick(() => highlight(scroll))
})

watch(
  () => props.saveFailure?.seq,
  () => {
    if (!props.saveFailure) return
    failedReason.value = props.saveFailure.reason
    if (!isLast.value) {
      skipScroll = true
      index.value = steps.value.length - 1
    }
  },
)

// 說明固定在底部：頁面底部補同高度的空白，最後一步的儲存按鈕才捲得到說明上方；
// 捲動區加同高度的 scroll-padding-bottom，聚焦欄位時瀏覽器自動捲動會避開卡片
const card = ref<InstanceType<typeof GuideCard> | null>(null)
const panel = computed(() => (card.value?.$el as HTMLElement | undefined) ?? null)
const panelHeight = ref(0)
let observer: ResizeObserver | null = null
let scroller: HTMLElement | null = null
const GAP = 24

watch(panelHeight, (h) => {
  if (scroller) scroller.style.scrollPaddingBottom = `${h + GAP}px`
})

onMounted(async () => {
  await nextTick()
  scroller = document.querySelector<HTMLElement>('.admin-main')
  highlight()
  if (panel.value) {
    observer = new ResizeObserver(([entry]) => {
      panelHeight.value = entry.target.getBoundingClientRect().height
    })
    observer.observe(panel.value)
  }
  // 讀屏與鍵盤使用者從說明開始，不用從頁首找
  panel.value?.focus({ preventScroll: true })
})

onBeforeUnmount(() => {
  current?.classList.remove(TARGET_CLASS)
  current = null
  observer?.disconnect()
  scroller?.style.removeProperty('scroll-padding-bottom')
  scroller = null
})

</script>

<template>
  <div aria-hidden="true" :style="{ height: `${panelHeight + GAP}px` }" />

  <GuideCard
    ref="card"
    class="first-record-guide"
    :label="kind === 'expense' ? '新增第一筆支出引導' : '新增第一筆收入引導'"
    :progress="progressText"
    :title="step.title"
    @end="emit('end')"
  >
    <p>{{ step.description }}</p>
    <template #status>
      <p v-if="recognizing" class="frg-status">
        <i class="pi pi-spin pi-spinner" aria-hidden="true" />正在辨識憑證，完成後再繼續下一步。
      </p>
    </template>
    <template #actions>
      <Button label="上一步" outlined size="small" :disabled="isFirst || recognizing" @click="prev" />
      <Button label="下一步" size="small" :disabled="isLast || recognizing" @click="next" />
    </template>
  </GuideCard>
</template>

<style scoped>
/* 卡片外觀在 GuideCard；這裡只決定位置：固定在畫面右下角，手機貼底全寬 */
.first-record-guide {
  position: fixed;
  right: var(--space-xl);
  bottom: var(--space-xl);
  /* 在頂欄之上、手機側邊選單遮罩（45）與 PrimeVue 對話框、下拉面板之下 */
  z-index: 40;
  width: min(360px, calc(100vw - 2 * var(--space-md)));
}
.frg-status {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: var(--space-xs) 0 0;
  font-size: 13px;
  color: var(--muted);
}
@media (max-width: 639.98px) {
  .first-record-guide {
    left: var(--space-sm);
    right: var(--space-sm);
    bottom: calc(var(--space-sm) + env(safe-area-inset-bottom));
    width: auto;
  }
}
</style>
