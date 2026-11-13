<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import type { AnimationItem } from 'lottie-web'

// 裝飾用 Lottie 動畫：循環播放；使用者開啟「減少動態效果」時只顯示第一格靜態畫面
// lottie-web 載入時就會用到 document，所以在 onMounted 裡才動態載入，建置時（Node 端）不會執行到。
// 動畫 JSON 也透過 load 在 onMounted 才載入（例：:load="() => import('../assets/lottie/cta-01.json')"），
// 才不會被打包進主程式、拖慢首次載入。
const props = withDefaults(defineProps<{ load: () => Promise<{ default: object }>; loop?: boolean }>(), {
  loop: true,
})

const container = ref<HTMLDivElement | null>(null)
let anim: AnimationItem | null = null
let unmounted = false

onMounted(async () => {
  const [{ default: lottie }, { default: animationData }] = await Promise.all([import('lottie-web'), props.load()])
  if (unmounted || !container.value) return
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  anim = lottie.loadAnimation({
    container: container.value,
    renderer: 'svg',
    loop: props.loop,
    autoplay: !reduce,
    animationData,
    rendererSettings: { preserveAspectRatio: 'xMidYMid meet' },
  })
})

onBeforeUnmount(() => {
  unmounted = true
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
