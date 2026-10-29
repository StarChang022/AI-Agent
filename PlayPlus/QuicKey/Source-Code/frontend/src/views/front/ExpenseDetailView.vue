<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  deleteReimbursement as apiDeleteReimbursement,
  getReimbursement,
  withdrawReimbursement,
  type Reimbursement,
} from '@/api/reimbursements'
import { formatCurrency, formatDate } from '@/utils/format'
import PageHeader from '@/components/PageHeader.vue'
import ReimbursementTimeline from '@/components/ReimbursementTimeline.vue'
import ReimbursementInvoiceRows from '@/components/ReimbursementInvoiceRows.vue'
import { useReimbursementPayout } from '@/composables/useReimbursementPayout'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import Button from 'primevue/button'
import Dialog from 'primevue/dialog'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const route = useRoute()
const router = useRouter()
const confirm = useConfirm()
const toast = useToast()

const reimbursementId = computed(() => route.params.id as string)
// 後端 /reimbursements/:id 走 current_user.reimbursements.find_by，已限定本人；
// 404 代表不存在或非本人，統一走 EmptyState「找不到」處理，不另外做前端 canView。
const reimbursement = ref<Reimbursement | null>(null)
const isLoading = ref(false)
const notFound = ref(false)
/** 刪除 / 取消簽核中：期間 disable 按鈕避免重複觸發。 */
const isSubmitting = ref(false)

async function load() {
  isLoading.value = true
  notFound.value = false
  try {
    reimbursement.value = await getReimbursement(reimbursementId.value)
  } catch {
    reimbursement.value = null
    notFound.value = true
  } finally {
    isLoading.value = false
  }
}

onMounted(load)

const previewUrl = ref<string | null>(null)

function isImageDataUrl(url: string) {
  return url.startsWith('data:image/')
}

function receiptLabel(i: number) {
  return reimbursement.value?.receiptNames?.[i] ?? `檔案 ${i + 1}`
}

/** 圖片收據（tile grid 用），保留原 index 對應 receiptNames */
const imageReceipts = computed(() =>
  (reimbursement.value?.receiptUrls ?? [])
    .map((url, i) => ({ url, i }))
    .filter(({ url }) => isImageDataUrl(url)),
)
/** PDF 等非圖片收據（縱向 list 顯示檔名 + 下載 icon） */
const pdfReceipts = computed(() =>
  (reimbursement.value?.receiptUrls ?? [])
    .map((url, i) => ({ url, i }))
    .filter(({ url }) => !isImageDataUrl(url)),
)

function goEdit() {
  if (!reimbursement.value) return
  router.push({
    name: 'front-expense-edit',
    params: { id: reimbursement.value.id },
  })
}

function deleteReimbursement() {
  if (!reimbursement.value) return
  const target = reimbursement.value
  const isDraft = target.status === 'draft'
  confirm.require({
    header: isDraft ? '刪除草稿' : '刪除退回記錄',
    message: isDraft
      ? '確定要刪除這筆草稿嗎？此動作無法復原。'
      : '確定要刪除這筆已退回的請款嗎？此動作無法復原。',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      if (isSubmitting.value) return
      isSubmitting.value = true
      try {
        await apiDeleteReimbursement(target.id)
        toast.add({
          severity: 'success',
          summary: isDraft ? '草稿已刪除' : '記錄已刪除',
          life: 2500,
        })
        router.replace({ name: 'front-history' })
      } catch {
        toast.add({ severity: 'error', summary: '刪除失敗', life: 3000 })
      } finally {
        isSubmitting.value = false
      }
    },
  })
}

function withdrawReview() {
  if (!reimbursement.value) return
  const target = reimbursement.value
  confirm.require({
    header: '取消簽核',
    message: '取消後這筆請款會退回草稿，你可以繼續編輯或刪除。確定要繼續嗎？',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '取消簽核',
    rejectLabel: '返回',
    accept: async () => {
      if (isSubmitting.value) return
      isSubmitting.value = true
      try {
        await withdrawReimbursement(target.id)
        toast.add({ severity: 'success', summary: '已退回草稿', life: 2500 })
        await load()
      } catch {
        toast.add({ severity: 'error', summary: '取消失敗', life: 3000 })
      } finally {
        isSubmitting.value = false
      }
    },
  })
}
const { payoutInfo } = useReimbursementPayout()
</script>

<template>
  <div>
    <div
      v-if="isLoading"
      class="py-12 flex flex-col items-center justify-center gap-2 text-[var(--color-muted)]"
    >
      <i class="pi pi-spin pi-spinner text-2xl" aria-hidden="true" />
      <span class="text-[13px]">載入中…</span>
    </div>

    <template v-else-if="reimbursement">
      <PageHeader title="請款詳情" :back="{ name: 'front-history' }" back-label="返回歷史紀錄">
        <template #actions>
          <!-- 桌機：動作按鈕放頁首右側（設計系統頁首） -->
          <div
            v-if="reimbursement.status === 'draft'"
            class="hidden lg:flex gap-2.5"
          >
            <Button
              type="button"
              outlined
              label="編輯草稿"
              @click="goEdit"
            />
            <Button
              type="button"
              severity="danger"
              label="刪除草稿"
              :disabled="isSubmitting"
              @click="deleteReimbursement"
            />
          </div>
          <div
            v-else-if="reimbursement.status === 'rejected'"
            class="hidden lg:flex gap-2.5"
          >
            <Button
              type="button"
              outlined
              label="重新編輯"
              @click="goEdit"
            />
            <Button
              type="button"
              severity="danger"
              label="刪除記錄"
              :disabled="isSubmitting"
              @click="deleteReimbursement"
            />
          </div>
          <div
            v-else-if="reimbursement.status === 'in_review'"
            class="hidden lg:flex"
          >
            <Button
              type="button"
              severity="warn"
              outlined
              label="取消簽核"
              :disabled="isSubmitting"
              @click="withdrawReview"
            />
          </div>
        </template>
      </PageHeader>


      <!-- Summary card：金額｜預計發放日並排（同管理端抽屜），其下類別、費用日、描述 -->
      <section class="card p-4 mb-3 rb-summary">
        <StatusBadge :status="reimbursement.status" />
        <div class="dt-stats">
          <div class="dt-stat">
            <span class="dt-stat-label">金額</span>
            <span class="dt-stat-value">{{ formatCurrency(reimbursement.amount) }}</span>
          </div>
          <div v-if="payoutInfo(reimbursement)" class="dt-stat">
            <span class="dt-stat-label">{{ payoutInfo(reimbursement)!.kind === 'paid' ? '發放日' : '預計發放日' }}</span>
            <span class="dt-stat-value">{{ payoutInfo(reimbursement)!.date }}</span>
          </div>
        </div>

        <dl class="grid grid-cols-2 gap-y-3 gap-x-4 text-sm mt-4">
          <div>
            <dt class="field-caption">費用類別</dt>
            <dd class="text-[var(--color-ink)]">
              {{ reimbursement.category.name }}
            </dd>
          </div>
          <div>
            <dt class="field-caption">費用日</dt>
            <dd class="text-[var(--color-ink)] tabular-nums">
              {{ formatDate(reimbursement.incurredAt) }}
            </dd>
          </div>
          <div class="col-span-2">
            <dt class="field-caption">描述</dt>
            <dd class="text-[var(--color-ink)] whitespace-pre-wrap leading-snug">
              {{ reimbursement.description || '（未填寫）' }}
            </dd>
          </div>
        </dl>
      </section>

      <!-- 憑證資訊（唯讀，與後台明細一致） -->
      <section class="card p-4 mb-3" aria-labelledby="rb-invoice">
        <h2 id="rb-invoice" class="section-title">憑證資訊</h2>
        <dl class="dt-list">
          <ReimbursementInvoiceRows :reimbursement="reimbursement" />
        </dl>
      </section>

      <!-- Receipts -->
      <section
        class="card p-4 mb-3"
      >
        <h2 class="section-title">
          發票或收據
          <span
            v-if="reimbursement.receiptUrls.length > 0"
            class="text-xs text-[var(--color-muted-soft)] font-normal ml-1"
          >
            （共 {{ reimbursement.receiptUrls.length }} 張）
          </span>
        </h2>

        <!-- 圖片：tile grid -->
        <div
          v-if="imageReceipts.length > 0"
          class="grid grid-cols-4 gap-2 lg:grid-cols-[repeat(auto-fill,minmax(0,110px))] lg:gap-3"
        >
          <button
            v-for="{ url, i } in imageReceipts"
            :key="i"
            type="button"
            class="aspect-square rounded-[10px] border border-[var(--color-hairline)] overflow-hidden bg-[var(--color-surface)] flex items-center justify-center hover:border-primary-400 transition-colors"
            @click="previewUrl = url"
          >
            <img
              :src="url"
              alt="發票"
              class="w-full h-full object-cover"
            />
          </button>
        </div>

        <!-- PDF：縱向 list 顯示原檔名 + 下載 icon（點擊直接下載，不進 dialog） -->
        <ul
          v-if="pdfReceipts.length > 0"
          class="space-y-2"
          :class="imageReceipts.length > 0 && 'mt-3'"
        >
          <li
            v-for="{ url, i } in pdfReceipts"
            :key="i"
            class="flex items-center gap-2 px-3 py-2.5 rounded-chip border border-[var(--color-hairline)]"
          >
            <i class="pi pi-file-pdf text-lg text-[var(--color-muted)] flex-shrink-0" />
            <span class="flex-1 text-sm text-[var(--color-ink)] truncate">
              {{ receiptLabel(i) }}
            </span>
            <a
              :href="url"
              :download="receiptLabel(i)"
              :aria-label="`下載 ${receiptLabel(i)}`"
              class="w-8 h-8 rounded-full flex items-center justify-center text-[var(--color-primary-700)] hover:bg-[var(--color-surface)] transition-colors flex-shrink-0"
            >
              <i class="pi pi-download text-sm" />
            </a>
          </li>
        </ul>
        <p
          v-if="reimbursement.receiptUrls.length === 0"
          class="text-sm text-[var(--color-muted-soft)]"
        >
          未上傳發票或收據
        </p>
      </section>

      <!-- 簽核進度：送出 → 簽核 → 發放（與管理端共用） -->
      <section class="card p-4 mb-3">
        <h2 id="emp-flow" class="section-title">簽核進度</h2>
        <ReimbursementTimeline :reimbursement="reimbursement" labelledby="emp-flow" />
      </section>

      <!-- Actions（手機版；桌機改由 PageHeader 右側 actions slot 承接） -->
      <div v-if="reimbursement.status === 'draft'" class="mt-1 grid grid-cols-2 gap-2.5 lg:hidden">
        <Button
          label="編輯草稿"
          outlined
          @click="goEdit"
        />
        <Button
          label="刪除草稿"
          severity="danger"
          @click="deleteReimbursement"
        />
      </div>
      <div
        v-else-if="reimbursement.status === 'rejected'"
        class="mt-1 grid grid-cols-2 gap-2.5 lg:hidden"
      >
        <Button
          label="重新編輯"
          outlined
          @click="goEdit"
        />
        <Button
          label="刪除記錄"
          severity="danger"
          @click="deleteReimbursement"
        />
      </div>
      <div v-else-if="reimbursement.status === 'in_review'" class="mt-1 lg:hidden">
        <Button
          label="取消簽核"
          severity="warn"
          outlined
          class="w-full"
          @click="withdrawReview"
        />
      </div>
    </template>

    <EmptyState
      v-else-if="notFound"
      icon="pi pi-exclamation-circle"
      title="找不到這筆請款"
      description="可能已被刪除，或這筆記錄不屬於你"
    >
      <template #action>
        <Button
          label="回到歷史記錄"
          @click="router.replace({ name: 'front-history' })"
        />
      </template>
    </EmptyState>

    <!-- Receipt preview（僅圖片；PDF 由 tile 上的下載連結直接觸發下載） -->
    <Dialog
      :visible="previewUrl !== null"
      modal
      dismissable-mask
      :closable="true"
      :show-header="false"
      :style="{ width: 'min(92vw, 720px)' }"
      content-class="!p-0"
      @update:visible="previewUrl = null"
    >
      <div class="relative bg-black">
        <button
          type="button"
          class="absolute top-2 right-2 z-10 w-9 h-9 rounded-full bg-black/60 text-white flex items-center justify-center hover:bg-black/80"
          @click="previewUrl = null"
        >
          <i class="pi pi-times" />
        </button>
        <img
          v-if="previewUrl"
          :src="previewUrl"
          alt="發票放大檢視"
          class="w-full max-h-[80vh] object-contain"
        />
      </div>
    </Dialog>
  </div>
</template>

<style scoped>
/* 卡片是白底：金額／發放日改淺灰區塊，與下方資訊分層；小標籤統一灰階 */
.rb-summary .dt-stat { background: var(--color-surface); }
.rb-summary .dt-stat-label,
.rb-summary dt { color: var(--color-muted); }
</style>
