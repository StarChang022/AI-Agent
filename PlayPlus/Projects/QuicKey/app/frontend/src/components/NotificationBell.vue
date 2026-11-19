<script setup lang="ts">
/**
 * 通知鈴：顯示未讀通知（前台、後台頂欄共用）。
 * 資料與未讀計數由 useNotifications 共用（通知中心頁亦用同一份）。
 * popover 僅顯示最近 5 則；完整清單在「查看所有訊息」導向的通知中心頁（依角色分前台／後台）。
 */
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import Popover from 'primevue/popover'
import Button from 'primevue/button'
import { describeNotification, notificationsRouteName, useNotifications } from '@/composables/useNotifications'
import type { Notification } from '@/api/notifications'

/** tone="dark"：放在深色頂欄（前台）時改綠底白框 */
const props = withDefaults(defineProps<{ tone?: 'light' | 'dark' }>(), { tone: 'light' })

const router = useRouter()
const { preview, previewLoading, unreadCount, refreshPreview, refreshUnreadCount, markRead, markAllRead } =
  useNotifications()

const previewViews = computed(() => preview.value.map(describeNotification))

const pop = ref<InstanceType<typeof Popover> | null>(null)
const open = ref(false)
async function openItem(n: Notification) {
  const target = describeNotification(n).to
  await markRead(n.id)
  pop.value?.hide()
  router.push(target)
}
function openAll() {
  pop.value?.hide()
  router.push({ name: notificationsRouteName() })
}

// 首次載入拉未讀數；進入時馬上顯示紅點，不等 popover 打開
onMounted(() => {
  void refreshUnreadCount()
})
</script>

<template>
  <button
    type="button"
    class="icon-circle-btn"
    :class="{ 'icon-circle-btn--on-dark': props.tone === 'dark' }"
    :aria-label="unreadCount ? `通知，${unreadCount} 則未讀` : '通知'"
    aria-haspopup="true"
    :aria-expanded="open"
    @click="pop?.toggle($event)"
  >
    <i class="pi pi-bell" aria-hidden="true" />
    <span v-if="unreadCount" class="dash-dot" aria-hidden="true" />
  </button>
  <!-- @show：僅開啟 popover 時刷新預覽，不在關閉時浪費一次 fetch -->
  <Popover ref="pop" @show="open = true; refreshPreview()" @hide="open = false">
    <div class="notif-pop">
      <div class="notif-head">
        <span>通知</span>
        <button v-if="unreadCount" type="button" class="link-btn" @click="markAllRead">全部標為已讀</button>
      </div>
      <div v-if="previewLoading && previewViews.length === 0" class="dash-empty">
        <i class="pi pi-spin pi-spinner" aria-hidden="true" />
      </div>
      <template v-else-if="previewViews.length">
        <button
          v-for="(v, i) in previewViews"
          :key="v.id"
          type="button"
          class="notif-item unread"
          @click="openItem(preview[i])"
        >
          {{ v.title }}<small>{{ v.sub }}</small>
        </button>
      </template>
      <div v-else class="dash-empty">沒有新通知</div>
      <div class="notif-footer">
        <Button label="查看所有訊息" size="small" @click="openAll" />
      </div>
    </div>
  </Popover>
</template>

<style scoped>
.notif-pop { width: min(320px, calc(100vw - 48px)); }
/* 手機版字級不超過 14px */
@media (max-width: 639.98px) {
  .notif-item { font-size: 14px; }
  .notif-item small { font-size: 12px; }
}
</style>
