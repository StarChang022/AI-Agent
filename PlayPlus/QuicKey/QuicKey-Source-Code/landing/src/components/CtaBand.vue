<script setup lang="ts">
import { SIGNUP_URL } from '../config'
import LottieDeco from './LottieDeco.vue'
import ctaAnimation from '../assets/lottie/cta-01.json'
</script>

<template>
  <section class="cta-art">
    <div class="container-page cta-inner" v-reveal="'up'">
      <h2>從今天開始，讓帳務管理更省力</h2>
      <p class="cta-sub">告別繁瑣的記帳與整理，讓 QUICKEY 幫你輕鬆掌握每一筆收支。</p>
      <a :href="SIGNUP_URL" class="btn-primary">免費試用30天</a>
    </div>
    <LottieDeco class="cta-deco" :animation-data="ctaAnimation" v-reveal="{ type: 'soft', delay: 200 }" />
  </section>
</template>

<style scoped>
/* 與 Hero 相同的淺色背景（兩組淺綠光暈疊在白底上） */
.cta-art {
  position: relative;
  overflow: hidden;
  contain: paint;
  padding: 128px 0;
  text-align: center;
  color: var(--color-ink);
  background:
    radial-gradient(circle at 15% 10%, var(--color-primary-50), transparent 55%),
    radial-gradient(circle at 90% 80%, var(--color-primary-100), transparent 50%),
    var(--color-canvas);
}
.cta-inner {
  position: relative;
  z-index: 2;
}
.cta-art h2 {
  margin-bottom: 32px;
  font-size: clamp(30px, 5vw, 56px);
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
}
.cta-sub {
  max-width: 560px;
  margin: 0 auto 32px;
  text-align: center;
  color: var(--color-slate);
}
/* CTA 插畫：縮小並靠左貼齊，底部留距；疊於區塊底部，文字覆蓋在插畫上方，區塊高度不變 */
.cta-art .cta-deco {
  position: absolute;
  left: 0;
  bottom: 24px;
  z-index: 0;
  max-width: none;
  width: 96%;
  margin: 0;
  pointer-events: none;
  overflow: visible;
}
/* Lottie 預設 SVG 會裁切超出畫布的線條；允許溢出，由區塊 overflow:hidden 在邊緣自然收邊 */
.cta-art .cta-deco :deep(svg) {
  overflow: visible;
}
.cta-art .btn-primary {
  min-height: 56px;
  padding: 0 40px;
  font-size: 18px;
}
/* 手機：只顯示右側羽毛筆，左側線條超出區塊由 overflow 裁切；留白縮減 */
@media (max-width: 767.98px) {
  .cta-art {
    padding: 56px 0 112px;
  }
  .cta-art h2 {
    margin-bottom: 24px;
  }
  .cta-art .cta-deco {
    left: auto;
    right: 0;
    bottom: 16px;
    width: 130%;
  }
}
</style>
