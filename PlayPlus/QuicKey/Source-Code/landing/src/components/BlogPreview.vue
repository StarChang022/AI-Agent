<script setup lang="ts">
import { staggerDelay } from '../motion/reveal'
import { RouterLink } from 'vue-router'
import ArticleCard from './ArticleCard.vue'
import { posts } from '../data/posts'

const latest = posts.slice(0, 3)
</script>

<template>
  <section class="section blog-fade">
    <div class="container-page">
      <header class="section-split" v-reveal="'up'">
        <div>
          <p class="eyebrow">知識文章</p>
          <h2 class="section-title">收支管理的實用觀念</h2>
        </div>
        <RouterLink to="/blog" class="btn-ghost">看全部文章</RouterLink>
      </header>

      <div class="article-grid">
        <ArticleCard v-for="(post, i) in latest" :key="post.slug" :post="post" v-reveal="{ type: 'up', delay: staggerDelay(i) }" />
      </div>
    </div>
  </section>
</template>

<style scoped>
/* 與上方「為什麼用 QUICKEY」銜接：頂部由白色漸層淡出 */
.blog-fade {
  position: relative;
  padding-top: 32px;
}
/* 與上方區塊的間距縮小：桌機頂部 padding 88px → 56px（手機維持原值） */
@media (min-width: 768px) {
  .blog-fade {
    padding-top: 56px;
  }
}
.blog-fade::before {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 160px;
  background: linear-gradient(to bottom, var(--color-canvas), transparent);
  pointer-events: none;
}
.blog-fade > .container-page {
  position: relative;
  z-index: 2;
}
</style>
