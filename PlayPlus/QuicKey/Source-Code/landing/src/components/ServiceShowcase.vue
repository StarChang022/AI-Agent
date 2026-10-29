<script setup lang="ts">
import StrokeText from './StrokeText.vue'
import MockOcr from './mock/MockOcr.vue'
import MockRequest from './mock/MockRequest.vue'
import MockBudget from './mock/MockBudget.vue'
import MockReport from './mock/MockReport.vue'
</script>

<template>
  <div class="service-wrap">
    <section id="services" class="service-band">
    <div class="container-page">
      <header class="section-head" style="text-align: left" v-reveal="'up'">
        <p class="eyebrow">我們能幫你做什麼</p>
        <h2 class="section-title">繁瑣的帳務工作，交給快記更省力。</h2>
        <p class="lead">從收支紀錄到請款追蹤，讓每一筆帳更好記、更好管。</p>
      </header>

      <!-- 01 拍照就能記：收據上傳與辨識示意 -->
      <div class="svc-row">
        <div class="svc-text" v-reveal="'up'">
          <span class="svc-num" aria-hidden="true"><StrokeText text="01" stroke-color="#00b39f" fill-color="#00b39f" fill-mode="wipe" trigger="scroll" :font-size="96" :stroke-width="1.2" /></span>
          <h3 class="svc-title">拍照就能記，<span class="svc-hl">收支不費力</span></h3>
          <p>收據拍張照，AI 協助辨識資訊，減少手動輸入的時間。</p>
        </div>
        <div class="svc-visual" v-reveal="{ type: 'image', delay: 120 }">
          <MockOcr />
        </div>
      </div>

      <!-- 02 請款進度清楚：請款狀態流轉示意 -->
      <div class="svc-row is-reverse">
        <div class="svc-text" v-reveal="'up'">
          <span class="svc-num" aria-hidden="true"><StrokeText text="02" stroke-color="#00b39f" fill-color="#00b39f" fill-mode="wipe" trigger="scroll" :font-size="96" :stroke-width="1.2" /></span>
          <h3 class="svc-title"><span class="svc-hl">請款進度清楚</span>，不必一直問</h3>
          <p>線上提交請款、追蹤處理狀態，讓申請與審核流程更透明。</p>
        </div>
        <div class="svc-visual" v-reveal="{ type: 'image', delay: 120 }">
          <MockRequest />
        </div>
      </div>

      <!-- 03 預算花到哪 -->
      <div class="svc-row">
        <div class="svc-text" v-reveal="'up'">
          <span class="svc-num" aria-hidden="true"><StrokeText text="03" stroke-color="#00b39f" fill-color="#00b39f" fill-mode="wipe" trigger="scroll" :font-size="96" :stroke-width="1.2" /></span>
          <h3 class="svc-title">預算花到哪，<span class="svc-hl">一看就明白</span></h3>
          <p>集中查看預算與支出情況，隨時掌握資金使用狀態。</p>
        </div>
        <div class="svc-visual" v-reveal="{ type: 'image', delay: 120 }">
          <MockBudget />
        </div>
      </div>

      <!-- 04 報表自動整理 -->
      <div class="svc-row is-reverse">
        <div class="svc-text" v-reveal="'up'">
          <span class="svc-num" aria-hidden="true"><StrokeText text="04" stroke-color="#00b39f" fill-color="#00b39f" fill-mode="wipe" trigger="scroll" :font-size="96" :stroke-width="1.2" /></span>
          <h3 class="svc-title"><span class="svc-hl">報表自動整理</span>，不必重新算</h3>
          <p>依據收支紀錄彙整財務報表，讓每月經營狀況更容易掌握。</p>
        </div>
        <div class="svc-visual" v-reveal="{ type: 'image', delay: 120 }">
          <MockReport />
        </div>
      </div>
    </div>
  </section>
  </div>
</template>

<style scoped>
.svc-visual {
  min-width: 0;
}
/* 交錯排列：偶數列圖片在左、文字在右 */
@media (min-width: 900px) {
  .svc-row.is-reverse .svc-visual {
    order: -2;
  }
}

/* 數字：StrokeText 以 SVG 量測，讓字形靠左對齊而非置中 */
.svc-num :deep(svg) {
  width: auto;
}
/* 標題重點字：綠色底線由左往右延伸（與關於我們「更清楚」同色系），進場時觸發 */
.svc-hl {
  background-image: linear-gradient(var(--color-primary-500), var(--color-primary-500));
  background-repeat: no-repeat;
  background-position: 0 85%;
  background-size: 0% 0.42em;
  transition: background-size 0.8s var(--motion-ease) 0.35s;
}
.svc-text.is-revealed .svc-hl {
  background-size: 100% 0.42em;
}
@media (prefers-reduced-motion: reduce) {
  .svc-hl {
    transition: none;
    background-size: 100% 0.42em;
  }
}
</style>
