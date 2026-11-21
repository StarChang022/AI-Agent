<script setup lang="ts">
import LegalPage from '../components/LegalPage.vue'
import { termsPage } from '../data/legal'
</script>

<template>
  <LegalPage
    :title="termsPage.title"
    :updated="termsPage.updated"
    :intro="termsPage.intro"
    :sections="termsPage.sections"
  />
</template>
