<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import lottie, { type AnimationItem } from 'lottie-web'

// 裝飾用 Lottie 動畫：循環播放；使用者開啟「減少動態效果」時只顯示第一格靜態畫面
const props = withDefaults(defineProps<{ animationData: object; loop?: boolean }>(), { loop: true })

const container = ref<HTMLDivElement | null>(null)
let anim: AnimationItem | null = null

onMounted(() => {
  if (!container.value) return
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  anim = lottie.loadAnimation({
    container: container.value,
    renderer: 'svg',
    loop: props.loop,
    autoplay: !reduce,
    animationData: props.animationData,
    rendererSettings: { preserveAspectRatio: 'xMidYMid meet' },
  })
})

onBeforeUnmount(() => {
  anim?.destroy()
  anim = null
})
</script>

<template>
  <div ref="container" class="lottie-deco" aria-hidden="true" />
</template>

<style scoped>
.lottie-deco {
  width: 100%;
  max-width: 420px;
  margin-inline: auto;
}
.lottie-deco :deep(svg) {
  display: block;
  width: 100%;
  height: auto;
}
</style>
