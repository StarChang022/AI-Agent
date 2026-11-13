<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRoute, useRouter, type LocationQuery } from 'vue-router'
import ArticleCard from '../components/ArticleCard.vue'
import QSelect from '../components/QSelect.vue'
import BlogPagination from '../components/BlogPagination.vue'
import { posts, postCategories } from '../data/posts'

const PAGE_SIZE = 12
const ALL = '全部'
const categories = [ALL, ...postCategories]

// 排序選項（示意）：最新／最舊依發布日期，熱門依瀏覽數；後端接上後改由 API 排序
type SortKey = 'newest' | 'oldest' | 'popular'
const sortOptions: { value: SortKey; label: string }[] = [
  { value: 'newest', label: '從新到舊' },
  { value: 'oldest', label: '從舊到新' },
  { value: 'popular', label: '依熱門' },
]
const DEFAULT_SORT: SortKey = 'newest'

const route = useRoute()
const router = useRouter()
const listRef = ref<HTMLElement | null>(null)

// 篩選狀態全部來自 URL query：?q=關鍵字&cat=分類&page=頁碼
const query = computed(() => (typeof route.query.q === 'string' ? route.query.q : ''))
const active = computed(() => {
  const c = typeof route.query.cat === 'string' ? route.query.cat : ALL
  return (categories as string[]).includes(c) ? c : ALL
})
const sortKey = computed<SortKey>(() => {
  const s = typeof route.query.sort === 'string' ? route.query.sort : DEFAULT_SORT
  return sortOptions.some((o) => o.value === s) ? (s as SortKey) : DEFAULT_SORT
})
// 無搜尋與分類篩選時才顯示精選（與排序無關）
const noFilter = computed(() => !query.value.trim() && active.value === ALL)

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return posts.filter((p) => {
    const inCategory = active.value === ALL || p.category === active.value
    const inText = !q || `${p.title}${p.summary}`.toLowerCase().includes(q)
    return inCategory && inText
  })
})

// 排序：依發布日期或瀏覽數；精選文章固定為前三篇，不隨排序改變
const sorted = computed(() => {
  const list = [...filtered.value]
  if (sortKey.value === 'popular') return list.sort((a, b) => b.views - a.views)
  const byDate = (a: { publishedAt: string }, b: { publishedAt: string }) =>
    a.publishedAt < b.publishedAt ? 1 : a.publishedAt > b.publishedAt ? -1 : 0
  return sortKey.value === 'oldest' ? list.sort((a, b) => -byDate(a, b)) : list.sort(byDate)
})

// 精選：前三篇，只在預設列表第 1 頁以提示區塊顯示；左側列表永遠包含全部文章
const featuredCount = computed(() => (posts.length >= 3 ? 3 : 0))
const gridPool = computed(() => sorted.value)
const totalPages = computed(() => Math.max(1, Math.ceil(gridPool.value.length / PAGE_SIZE)))

const requestedPage = computed(() => {
  const n = Number.parseInt(typeof route.query.page === 'string' ? route.query.page : '1', 10)
  return Number.isFinite(n) && n >= 1 ? n : 1
})
const currentPage = computed(() => Math.min(requestedPage.value, totalPages.value))
const pageItems = computed(() =>
  gridPool.value.slice((currentPage.value - 1) * PAGE_SIZE, currentPage.value * PAGE_SIZE),
)
// 精選為常駐提示區塊：不論頁數或篩選都顯示
const showFeatured = computed(() => featuredCount.value > 0)
const isEmpty = computed(() => filtered.value.length === 0)

// 更新 URL：值為空或預設值時移除該參數
function buildQuery(patch: { q?: string; cat?: string; page?: number; sort?: string }, base: LocationQuery = route.query): LocationQuery {
  const next: LocationQuery = { ...base }
  const set = (key: string, value: string | undefined) => {
    if (value === undefined || value === '') delete next[key]
    else next[key] = value
  }
  if ('q' in patch) set('q', patch.q?.trim() ? patch.q : undefined)
  if ('cat' in patch) set('cat', patch.cat === ALL ? undefined : patch.cat)
  if ('page' in patch) set('page', patch.page && patch.page > 1 ? String(patch.page) : undefined)
  if ('sort' in patch) set('sort', patch.sort === DEFAULT_SORT ? undefined : patch.sort)
  return next
}

// 搜尋輸入使用 replace，避免每個字都產生一筆瀏覽紀錄
function onSearch(e: Event) {
  const value = (e.target as HTMLInputElement).value
  router.replace({ query: buildQuery({ q: value, page: undefined }) })
}

// 切換分類：push 進瀏覽紀錄，並回到第 1 頁
function setCategory(c: string) {
  router.push({ query: buildQuery({ cat: c, page: undefined }) })
}

// 排序切換：push 進瀏覽紀錄，並回到第 1 頁
function onSort(value: string) {
  router.push({ query: buildQuery({ sort: value, page: undefined }) })
}

function clearAll() {
  router.push({ query: buildQuery({ q: '', cat: ALL, sort: DEFAULT_SORT, page: undefined }) })
}

function scrollToList() {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  listRef.value?.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' })
}

// 分頁切換：push 進瀏覽紀錄（上一頁可返回），並捲動到文章列表起點
async function goToPage(page: number) {
  await router.push({ query: buildQuery({ page }) })
  // 等待 router 完成預設捲動（回到頁首）之後，再捲到列表起點
  setTimeout(scrollToList, 0)
}
</script>

<template>
  <section class="section blog-page">
    <div class="container-page blog-container">
      <header class="blog-header" v-reveal="'soft'">
        <h1 class="blog-title">把收支管好，從這裡開始</h1>
        <p class="lead blog-lead">實用觀念、管理技巧與工作流程，讓日常帳務更省力。</p>
      </header>

      <div class="blog-layout">
        <div class="blog-main">
          <h2 id="post-list" ref="listRef" class="list-title">所有文章</h2>
          <div class="list-bar">
            <p class="result-count" aria-live="polite">找到 {{ filtered.length }} 篇文章</p>
            <div class="sort-field">
              <QSelect id="post-sort" :model-value="sortKey" :options="sortOptions" aria-label="排序方式" @update:model-value="onSort" />
            </div>
          </div>

          <div v-if="isEmpty" class="blog-empty">
            <p>找不到符合條件的文章，可以試試其他關鍵字或切換分類。</p>
            <button v-if="!noFilter || sortKey !== DEFAULT_SORT" type="button" class="chip" @click="clearAll">清除搜尋與分類</button>
          </div>

          <div v-else-if="pageItems.length" class="article-grid">
            <ArticleCard v-for="post in pageItems" :key="post.slug" :post="post" :to="`/blog/${post.slug}`" />
          </div>

          <BlogPagination
            v-if="totalPages > 1"
            :current="currentPage"
            :total="totalPages"
            @change="goToPage"
          />
        </div>

        <aside class="blog-side" aria-label="精選文章與搜尋" v-reveal="{ type: 'soft', delay: 120 }">


          <section class="side-block" aria-label="搜尋與分類">
            <div class="search-field">
              <label for="post-search" class="sr-only">搜尋文章</label>
              <svg class="search-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                <circle cx="11" cy="11" r="7" />
                <path d="M20 20l-3.5-3.5" />
              </svg>
              <input
                id="post-search"
                type="search"
                :value="query"
                placeholder="搜尋文章標題"
                autocomplete="off"
                @input="onSearch"
              />
            </div>
            <div class="chip-row side-chips" role="group" aria-label="文章分類">
              <button
                v-for="c in categories"
                :key="c"
                type="button"
                class="chip"
                :aria-pressed="active === c"
                @click="setCategory(c)"
              >
                {{ c }}
              </button>
            </div>
          </section>
          <section v-if="showFeatured" class="side-block featured" aria-labelledby="featured-title">
            <h2 id="featured-title" class="side-title">精選文章</h2>
            <ul class="featured-list">
              <li v-for="p in posts.slice(0, 3)" :key="p.slug">
                <RouterLink :to="`/blog/${p.slug}`" class="featured-link">{{ p.title }}</RouterLink>
              </li>
            </ul>
          </section>
        </aside>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* 頁首副標與標題間距同 section-head */
.blog-lead {
  margin-top: var(--section-lead-gap-top);
}
.blog-layout {
  display: grid;
  gap: 48px;
  margin-top: 48px;
}
/* 手機與平板：搜尋與精選置於文章列表上方 */
.blog-side {
  display: grid;
  gap: 32px;
  order: -2;
}
.blog-main {
  min-width: 0;
}
@media (min-width: 960px) {
  .blog-layout {
    grid-template-columns: minmax(0, 1fr) 300px;
    align-items: start;
  }
  .blog-side {
    order: 0;
    position: sticky;
    top: 96px;
  }
}
.side-block {
  display: grid;
  gap: 16px;
}
.side-title {
  font-size: 20px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--color-ink);
}
.side-block .search-field input {
  width: 100%;
}
.side-chips {
  gap: 8px;
}
.list-title {
  margin-bottom: 8px;
  font-size: 24px;
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
  scroll-margin-top: 96px;
}
.list-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 20px;
}
.list-bar .result-count {
  margin: 0;
}
.sort-field {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--color-slate);
}
.sort-field .qselect {
  width: 200px;
}
/* 左側 Grid 寬度變窄，桌機維持 3 欄 */
.blog-main .article-grid {
  grid-template-columns: 1fr;
}
@media (min-width: 640px) {
  .blog-main .article-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (min-width: 1100px) {
  .blog-main .article-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
.blog-empty {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 16px;
  padding: 40px 0;
  font-size: 16px;
  color: var(--color-slate);
}
/* 側邊欄精選：縮小縮圖與字級，讓 300px 寬的欄位容得下 */
.side-block.featured {
  position: relative;
}
/* 綠色直線只貼齊「精選文章」標題的高度 */
.side-block.featured .side-title {
  position: relative;
  padding-left: 16px;
}
.side-block.featured .side-title::before {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: 0;
  width: 4px;
  border-radius: 2px;
  background: var(--color-primary-500);
}
.featured-list {
  display: grid;
  gap: 8px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.featured-link {
  display: block;
  padding: 12px 14px;
  font-size: 16px;
  font-weight: 600;
  line-height: 1.5;
  color: var(--color-ink);
  background: var(--color-surface);
  border-radius: var(--radius-control);
  text-decoration: none;
  transition: color 0.15s ease, background-color 0.15s ease;
}
.featured-link:hover {
  color: var(--color-primary-700);
  background: var(--color-surface-soft);
}
.featured-link:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
}
/* 搜尋欄放大鏡：改用 svg，取消共用樣式的圓形 ::before */
.side-block .search-field::before {
  content: none;
}
.side-block .search-field .search-icon {
  position: absolute;
  top: 50%;
  left: 16px;
  transform: translateY(-50%);
  color: var(--color-muted);
  pointer-events: none;
}
</style>
