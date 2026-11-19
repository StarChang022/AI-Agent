<script setup lang="ts">
import HeroSection from '../components/HeroSection.vue'
import PainPoints from '../components/PainPoints.vue'
import ServiceShowcase from '../components/ServiceShowcase.vue'
import BenefitStrip from '../components/BenefitStrip.vue'
// 上線前隱藏「知識文章」區塊，確定開放後取消註解
// import BlogPreview from '../components/BlogPreview.vue'
import CtaBand from '../components/CtaBand.vue'
</script>

<template>
  <HeroSection />
  <PainPoints />
  <ServiceShowcase />
  <BenefitStrip />
  <!-- <BlogPreview /> -->
  <CtaBand />
</template>
