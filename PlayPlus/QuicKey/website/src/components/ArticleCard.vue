<script setup lang="ts">
import { RouterLink } from 'vue-router'
import type { Post } from '../data/posts'

// to：有提供路由時整張卡片可點進內頁；未提供時維持原本的靜態卡片（例如首頁預覽）
withDefaults(defineProps<{ post: Post; variant?: 'default' | 'feature' | 'row'; to?: string }>(), {
  variant: 'default',
  to: undefined,
})
</script>

<template>
  <component :is="to ? RouterLink : 'div'" v-bind="to ? { to } : {}" class="article-wrap">
    <article :class="['article-card', `is-${variant}`]">
      <div :class="['article-thumb', `tone-${post.tone}`]" aria-hidden="true">
        <span class="thumb-mark">QUICKEY</span>
        <span v-if="variant === 'feature'" class="thumb-cat">{{ post.category }}</span>
      </div>
      <div class="article-body">
        <p class="article-cat">{{ post.category }}</p>
        <h3>{{ post.title }}</h3>
        <p class="article-summary">{{ post.summary }}</p>
      </div>
    </article>
  </component>
</template>

<style scoped>
/* 文章卡片統一定義（列表、內頁延伸閱讀、首頁預覽共用） */
.article-card .article-body {
  gap: 8px;
  padding: 16px 20px 18px;
}
.article-card .article-cat {
  position: static;
  padding: 0;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--color-primary-700);
  background: none;
  border-radius: 0;
}
.article-card h3 {
  margin-top: 0;
  font-size: 18px;
  line-height: 1.45;
}
.article-card .article-summary {
  margin-top: 0;
  font-size: 14px;
  line-height: 1.6;
}
.article-wrap {
  display: flex;
  flex-direction: column;
  color: inherit;
  text-decoration: none;
  border-radius: 20px;
}
a.article-wrap:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 4px;
}
.article-wrap > .article-card {
  flex: 1;
  transition: transform 0.25s ease, box-shadow 0.25s ease;
}
.article-card h3 {
  transition: color 0.25s ease;
}
.article-wrap:hover h3,
.article-wrap:focus-visible h3 {
  color: var(--color-primary-700);
}
.article-wrap:hover > .article-card,
.article-wrap:focus-visible > .article-card {
  transform: translateY(-4px);
  box-shadow: var(--shadow-float);
}
@media (prefers-reduced-motion: reduce) {
  .article-wrap > .article-card {
    transition: none;
    transform: none;
  }
}
</style>
