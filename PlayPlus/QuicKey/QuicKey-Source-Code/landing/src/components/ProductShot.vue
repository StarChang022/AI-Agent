<script setup lang="ts">
/**
 * 產品實際畫面（截圖）展示元件。
 * 僅負責呈現官網用的靜態截圖，不引用產品前端的任何元件或商業邏輯。
 */
withDefaults(
  defineProps<{
    src: string
    alt: string
    caption?: string
    eager?: boolean
  }>(),
  { caption: '', eager: false },
)
</script>

<template>
  <figure class="product-shot">
    <div class="product-shot-frame">
      <img
        :src="src"
        :alt="alt"
        width="1600"
        height="1075"
        :loading="eager ? 'eager' : 'lazy'"
        :fetchpriority="eager ? 'high' : 'auto'"
        decoding="async"
      />
    </div>
    <figcaption v-if="caption" class="product-shot-caption">{{ caption }}</figcaption>
  </figure>
</template>

<style scoped>
.product-shot {
  margin: 0;
  min-width: 0;
}
.product-shot-frame {
  overflow: hidden;
  background: var(--color-canvas);
  border: 1px solid var(--color-hairline);
  border-radius: 20px;
  box-shadow: 0 30px 60px rgba(0, 0, 0, 0.18);
}
.product-shot img {
  display: block;
  width: 100%;
  height: auto;
}
.product-shot-caption {
  margin-top: 12px;
  font-size: 12px;
  line-height: 1.6;
  color: var(--color-muted);
}
@media (max-width: 639.98px) {
  .product-shot-frame {
    border-radius: 16px;
  }
}
</style>
