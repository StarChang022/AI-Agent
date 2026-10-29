<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import ArticleCard from '../components/ArticleCard.vue'
import { posts } from '../data/posts'

// 部落格內頁統一版型。文章內文尚未完成，以示意段落呈現，正式內容上線前替換。
const route = useRoute()
const post = computed(() => posts.find((p) => p.slug === route.params.slug))

const sections = [
  { id: 's1', title: '第一段小標題（示意）' },
  { id: 's2', title: '第二段小標題（示意）' },
  { id: 's3', title: '第三段小標題（示意）' },
]
const placeholder = '（內文示意）這裡會放文章正文。段落長度、標題層級與引言樣式，會依正式內容再調整。'

// 延伸閱讀：相同分類優先；若沒有相同分類的其他文章，則推薦最新（清單順序最前）的文章
const related = computed(() => {
  if (!post.value) return []
  const others = posts.filter((p) => p.slug !== post.value!.slug)
  const sameCategory = others.filter((p) => p.category === post.value!.category)
  return (sameCategory.length ? sameCategory : others).slice(0, 3)
})

const pageUrl = computed(() => (typeof window !== 'undefined' ? window.location.href : ''))
const shareFacebook = computed(() => `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(pageUrl.value)}`)
const shareLine = computed(() => `https://social-plugins.line.me/lineit/share?url=${encodeURIComponent(pageUrl.value)}`)

// 目錄錨點：自行捲動到標題（標題已設定 scroll-margin-top），並保留 router 狀態
// 目錄高亮：捲動時，最後一個已經捲過頂部參考線的標題即為目前所在區塊
const activeId = ref(sections[0].id)
let ticking = false
function updateActive() {
  ticking = false
  let current = sections[0].id
  for (const s of sections) {
    const el = document.getElementById(s.id)
    if (el && el.getBoundingClientRect().top <= 140) current = s.id
  }
  activeId.value = current
}
function onScroll() {
  if (ticking) return
  ticking = true
  requestAnimationFrame(updateActive)
}
onMounted(() => {
  window.addEventListener('scroll', onScroll, { passive: true })
  updateActive()
})
onBeforeUnmount(() => window.removeEventListener('scroll', onScroll))

function onTocClick(e: MouseEvent, id: string) {
  e.preventDefault()
  const el = document.getElementById(id)
  if (!el) return
  activeId.value = id
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  el.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' })
  history.replaceState(history.state, '', `#${id}`)
}

const copyStatus = ref('')
async function copyLink() {
  try {
    await navigator.clipboard.writeText(pageUrl.value)
    copyStatus.value = '已複製連結'
  } catch {
    copyStatus.value = '複製失敗，請手動複製網址列連結'
  }
  setTimeout(() => (copyStatus.value = ''), 2000)
}
</script>

<template>
  <section class="section post-page">
    <div v-if="post" class="post-wrap">
      <header class="post-head">
        <nav class="crumbs" aria-label="麵包屑">
          <RouterLink to="/blog">部落格</RouterLink>
          <span aria-hidden="true">／</span>
          <span>{{ post.category }}</span>
        </nav>
        <h1 class="post-title">{{ post.title }}</h1>
        <p class="post-summary">{{ post.summary }}</p>
        <div :class="['post-cover', `tone-${post.tone}`]" aria-hidden="true">
          <span class="thumb-mark">QUICKEY</span>
        </div>
      </header>

      <div class="post-layout">
        <aside class="post-toc" aria-labelledby="toc-title">
          <p id="toc-title" class="toc-title">目錄</p>
          <ol>
            <li v-for="s in sections" :key="s.id">
              <a
                :href="`#${s.id}`"
                :class="{ 'is-active': activeId === s.id }"
                :aria-current="activeId === s.id ? 'location' : undefined"
                @click="onTocClick($event, s.id)"
              >{{ s.title }}</a>
            </li>
          </ol>
        </aside>

        <div class="post-content">
          <article class="prose post-body">
            <template v-for="s in sections" :key="s.id">
              <h2 :id="s.id">{{ s.title }}</h2>
              <p>{{ placeholder }}</p>
              <p>{{ placeholder }}</p>
            </template>
          </article>

          <div class="share">
            <p class="share-title">分享這篇文章</p>
            <div class="share-actions">
              <a :href="shareFacebook" class="share-btn" target="_blank" rel="noopener noreferrer" aria-label="分享到 Facebook（開新視窗）" title="分享到 Facebook">
                <svg viewBox="0 0 64 64" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M25.4315 35.579H18.6525C17.5578 35.579 17.2209 35.1579 17.2209 34.1474C17.2209 31.4105 17.2209 28.5895 17.2209 25.8526C17.2209 24.7579 17.642 24.3369 18.6525 24.3369H25.4315V18.3158C25.3473 15.6632 25.9788 12.9684 27.2841 10.5684C28.6736 8.16843 30.8631 6.40001 33.3894 5.5158C35.1157 4.88422 36.7999 4.63159 38.6104 4.63159H45.3052C46.2736 4.63159 46.6946 5.05264 46.6946 6.02107V13.8105C46.6946 14.779 46.2736 15.2 45.3052 15.2C43.4525 15.2 41.5999 15.2 39.7473 15.2842C37.8946 15.3684 36.9262 16.1684 36.9262 18.1053C36.842 20.1684 36.9262 22.1474 36.9262 24.2526H44.7999C45.8946 24.2526 46.3157 24.6737 46.3157 25.7684V34.0632C46.3157 35.1579 45.9788 35.579 44.7999 35.579H37.0104V57.8526C37.0104 59.0316 36.5894 59.4105 35.4525 59.4105H26.9052C25.8946 59.4105 25.4736 58.9895 25.4736 57.979L25.4315 35.579Z" /></svg>
              </a>
              <a :href="shareLine" class="share-btn" target="_blank" rel="noopener noreferrer" aria-label="分享到 LINE（開新視窗）" title="分享到 LINE">
                <svg viewBox="0 0 64 64" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M32 5.76843C16.9263 5.76843 4.63159 15.8316 4.63159 28.1263C4.63159 39.1579 14.3579 48.4632 27.4948 50.1474C28.379 50.3579 29.6 50.779 29.8948 51.4948C30.1053 52.2948 30.1895 53.1369 29.979 53.9369L29.6421 56.2526C29.5158 56.9263 29.0947 58.9895 32.0421 57.7684C34.9895 56.5474 47.8316 48.379 53.6 41.7684C57.5158 37.4737 59.4105 33.0105 59.4105 28.0842C59.3684 15.8316 47.0737 5.76843 32 5.76843ZM21.2632 35.4948H15.7895C15.0316 35.4948 14.4421 34.8632 14.4421 34.0632V23.1158C14.4421 22.2737 15.0737 21.6842 15.8737 21.6842C16.7158 21.6842 17.3053 22.3158 17.3053 23.1158V32.5474H21.2632C22.1053 32.6316 22.6105 33.3053 22.6105 34.1053C22.5684 34.779 22.0211 35.4105 21.2632 35.4948ZM26.9474 34.0632C27.0316 34.8632 26.4 35.579 25.6 35.579C24.8 35.6632 24.0842 35.0316 24.0842 34.2316C24.0842 34.1474 24.0842 34.1053 24.0842 34.0211V23.1158C24 22.2737 24.6316 21.6 25.4316 21.6C26.2316 21.6 26.9474 22.1474 26.9474 22.9474V23.1579V34.0632ZM40 34.0632C40 34.8211 39.3684 35.4948 38.5684 35.4948C38.1053 35.4948 37.6842 35.2842 37.3895 34.9474L31.7895 27.2842V34.0632C31.8737 34.8632 31.2421 35.579 30.4421 35.579C29.6421 35.6632 28.9263 35.0316 28.9263 34.2316C28.9263 34.1474 28.9263 34.1053 28.9263 34.0211V23.0737C28.9263 22.4421 29.3474 21.8947 29.8948 21.7684C30.0211 21.6842 30.1895 21.6842 30.3158 21.6842C30.7369 21.6842 31.2 21.8947 31.4948 22.2316L37.0947 29.8105V23.0316C37.0947 22.1895 37.7263 21.6 38.5263 21.6C39.3263 21.6 39.9579 22.2316 39.9579 23.0316L40 34.0632ZM48.7579 27.1158C49.5579 27.2 50.1053 27.8737 50.1053 28.6737C50.0211 29.4316 49.4737 29.979 48.7579 30.0211H44.8V32.6316H48.7579C49.5579 32.7158 50.1053 33.3895 50.1053 34.1895C50.0211 34.9474 49.4737 35.4948 48.7579 35.5369H43.2842C42.5263 35.5369 41.9369 34.8632 41.9369 34.1053V23.1158C41.9369 22.2737 42.5684 21.6842 43.3684 21.6842H48.8421C49.6421 21.7684 50.1895 22.4421 50.1895 23.2421C50.1053 24 49.5579 24.5474 48.7579 24.5895H44.8V27.2L48.7579 27.1158Z" /></svg>
              </a>
              <button type="button" class="share-btn" aria-label="複製連結" title="複製連結" @click="copyLink">
                <svg viewBox="0 0 64 64" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M57.152 6.34809C51.3546 0.550637 41.9147 0.550637 36.1172 6.34809L27.6963 14.769C26.5368 15.9285 26.5368 17.8142 27.6963 18.9736C28.8558 20.1331 30.7414 20.1331 31.9009 18.9736L40.3218 10.5644C43.8003 7.08595 49.4572 7.08595 52.9474 10.5644C56.4259 14.0429 56.4259 19.7115 52.9474 23.19L44.5265 31.6109C43.367 32.7704 43.367 34.656 44.5265 35.8155C45.1121 36.4011 46.7049 37.5958 48.7311 35.8155L57.152 27.3946C62.9495 21.5971 62.9495 12.1573 57.152 6.34809Z" /><path d="M31.608 44.5177L23.1988 52.9269C19.8257 56.3 13.9463 56.3 10.5732 52.9269C8.88667 51.2404 7.96142 49.0034 7.96142 46.6141C7.96142 44.2249 8.88667 41.9879 10.5732 40.3013L18.9824 31.8804C20.1419 30.7209 20.1419 28.8353 18.9824 27.6758C17.8229 26.5163 15.9373 26.5163 14.7778 27.6758L6.36858 36.0967C3.54599 38.9076 2 42.6437 2 46.6258C2 50.5962 3.54599 54.3323 6.35687 57.1432C9.16776 59.9541 12.9039 61.5001 16.8743 61.5001C20.8446 61.5001 24.5808 59.9541 27.3917 57.1432L35.8009 48.734C36.9604 47.5745 36.9604 45.6889 35.8009 44.5294C34.6414 43.3582 32.7675 43.3582 31.608 44.5177Z" /><path d="M39.8067 23.6936C38.6472 22.5341 36.7615 22.5341 35.602 23.6936L20.7278 38.5679C19.5683 39.7274 19.5683 41.613 20.7278 42.7725C21.3134 43.3581 22.9062 44.5176 24.9324 42.7725L39.8067 27.8982C40.9661 26.7387 40.9661 24.8531 39.8067 23.6936Z" /></svg>
              </button>
              <span class="copy-status" role="status" aria-live="polite">{{ copyStatus }}</span>
            </div>
          </div>
        </div>
      </div>

      <section class="related" aria-labelledby="related-title">
        <h2 id="related-title" class="related-title">延伸閱讀</h2>
        <div class="related-grid">
          <ArticleCard v-for="r in related" :key="r.slug" :post="r" :to="`/blog/${r.slug}`" />
        </div>
        <div class="post-foot">
          <RouterLink to="/blog" class="btn-ghost">返回部落格</RouterLink>
        </div>
      </section>
    </div>

    <div v-else class="post-wrap">
      <h1 class="post-title">找不到這篇文章</h1>
      <p class="post-summary">這篇文章可能已移除，或網址有誤。</p>
      <div class="post-foot">
        <RouterLink to="/blog" class="btn-ghost">返回部落格</RouterLink>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* 文章頁頂部留白為一般區塊的一半，讓麵包屑更靠近導覽列 */
.post-page {
  padding-top: 32px;
}
@media (min-width: 768px) {
  .post-page {
    padding-top: 44px;
  }
}

/* 所有內頁區塊共用同一個寬度與左右邊界（與延伸閱讀對齊）；文字一律靠左 */
.post-wrap {
  max-width: 1000px;
  margin-inline: auto;
  padding-inline: 16px;
  text-align: left;
}
@media (min-width: 768px) {
  .post-wrap {
    padding-inline: 12px;
  }
}

.post-head {
  text-align: left;
}
.crumbs {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  font-size: 12px;
  color: var(--color-muted);
}
.crumbs a {
  color: var(--color-primary-700);
  font-weight: 600;
}
.post-title {
  margin-top: 16px;
  font-size: clamp(28px, 4vw, 40px);
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
}
.post-summary {
  margin-top: 16px;
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-slate);
}
.post-cover {
  position: relative;
  aspect-ratio: 16 / 9;
  margin-top: 32px;
  overflow: hidden;
  border-radius: var(--radius-card-lg);
}
.post-cover.tone-1 {
  background: linear-gradient(135deg, var(--color-primary-100), var(--color-primary-300));
}
.post-cover.tone-2 {
  background: linear-gradient(135deg, var(--color-primary-800), var(--color-primary-500));
}
.post-cover.tone-3 {
  background: linear-gradient(135deg, var(--color-surface-soft), var(--color-primary-200));
}
.post-cover .thumb-mark {
  position: absolute;
  left: 24px;
  top: 20px;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  color: var(--color-canvas);
}
.post-cover.tone-1 .thumb-mark,
.post-cover.tone-3 .thumb-mark {
  color: var(--color-primary-700);
}

/* 左側目錄（桌機固定於左欄）＋右側內文；手機版目錄置於內文上方 */
.post-layout {
  display: grid;
  gap: 32px;
  margin-top: 48px;
}
.post-content {
  min-width: 0;
}
.post-toc {
  padding-bottom: 8px;
  border-bottom: 1px solid var(--color-hairline);
}
.toc-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-muted);
}
.post-toc ol {
  display: grid;
  gap: 8px;
  margin-top: 12px;
  padding: 0;
  list-style: none;
  font-size: 14px;
}
.post-toc ol {
  border-left: 1px solid var(--color-hairline);
}
.post-toc a {
  position: relative;
  display: block;
  padding: 6px 0 6px 16px;
  color: var(--color-muted);
  text-decoration: none;
  line-height: 1.5;
  transition: color 0.15s ease;
}
/* 目錄左側線條；目前所在區塊以品牌綠色段落標示 */
.post-toc a::before {
  content: '';
  position: absolute;
  left: -1px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: transparent;
  transition: background-color 0.15s ease;
}
.post-toc a:hover {
  color: var(--color-ink);
}
.post-toc a.is-active {
  color: var(--color-ink);
  font-weight: 600;
}
.post-toc a.is-active::before {
  background: var(--color-primary-500);
}
.post-toc a:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
  border-radius: 4px;
}
.post-body {
  max-width: 680px;
}
.post-body :deep(h2) {
  scroll-margin-top: 96px;
}
.share {
  max-width: 680px;
  margin-top: 56px;
  padding-top: 24px;
  border-top: 1px solid var(--color-hairline);
}
.share-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-ink);
}
.share-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
}
.share-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  padding: 0;
  color: var(--color-hairline-strong);
  background: var(--color-canvas);
  border: 1.5px solid var(--color-hairline-strong);
  border-radius: 999px;
  cursor: pointer;
  text-decoration: none;
  transition: color 0.15s ease, border-color 0.15s ease, background-color 0.15s ease;
}
.share-btn:hover {
  color: var(--color-primary-700);
  border-color: var(--color-primary-500);
  background: var(--color-primary-50);
}
.share-btn:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}
.copy-status {
  font-size: 14px;
  color: var(--color-primary-700);
}

.related {
  margin-top: 88px;
  padding-top: 40px;
  border-top: 1px solid var(--color-hairline);
}
.related-title {
  font-size: 24px;
  font-weight: 600;
  color: var(--color-ink);
}
.related-grid {
  display: grid;
  gap: 24px;
  margin-top: 24px;
}
@media (min-width: 640px) {
  .related-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (min-width: 960px) {
  .related-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
  .post-layout {
    grid-template-columns: 180px minmax(0, 1fr);
    gap: 48px;
    align-items: start;
  }
  .post-toc {
    position: sticky;
    top: 96px;
    grid-column: 1;
    width: 180px;
    border-bottom: 0;
    padding-bottom: 0;
  }
  .post-content {
    grid-column: 2;
  }
}
.post-foot {
  margin-top: 40px;
}
</style>
