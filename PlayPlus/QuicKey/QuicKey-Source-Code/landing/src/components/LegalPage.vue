<script setup lang="ts">
// 段落可為純文字，或 `{ h3: '子標題' }`（同一章節內的小標）
export type LegalParagraph = string | { h3: string }

defineProps<{
  title: string
  updated: string
  intro?: string[]
  sections: { heading: string; paragraphs: LegalParagraph[] }[]
}>()
</script>

<template>
  <section class="section">
    <div class="container-page" style="max-width: 800px">
      <h1 class="section-title">{{ title }}</h1>
      <p style="margin-top: 12px; display: flex; gap: 12px; flex-wrap: wrap; align-items: center; color: var(--color-muted); font-size: 14px">
        <span class="badge-draft">草稿・待審閱</span>
        <span>更新日期：{{ updated }}</span>
      </p>
      <article class="prose">
        <p v-for="(text, i) in intro ?? []" :key="`intro-${i}`">{{ text }}</p>
        <template v-for="section in sections" :key="section.heading">
          <h2>{{ section.heading }}</h2>
          <template v-for="(item, i) in section.paragraphs" :key="i">
            <h3 v-if="typeof item !== 'string'">{{ item.h3 }}</h3>
            <p v-else>{{ item }}</p>
          </template>
        </template>
      </article>
    </div>
  </section>
</template>

<style scoped>
/* 章節內小標與上方段落保持間距 */
.prose h3 {
  margin: 32px 0 12px;
  font-size: 18px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--color-ink);
}
</style>
