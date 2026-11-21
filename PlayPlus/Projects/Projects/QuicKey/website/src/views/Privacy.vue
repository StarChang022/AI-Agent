<script setup lang="ts">
import LegalPage from '../components/LegalPage.vue'
import { privacyPage } from '../data/legal'
</script>

<template>
  <LegalPage
    :title="privacyPage.title"
    :updated="privacyPage.updated"
    :intro="privacyPage.intro"
    :sections="privacyPage.sections"
  />
</template>
