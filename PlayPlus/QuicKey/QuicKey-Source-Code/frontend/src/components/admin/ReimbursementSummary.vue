<script setup lang="ts">
/**
 * 請款單動作視窗頂部的摘要卡（駁回、作廢、取消作廢共用；與「調整付款日」相同的 .dlg-summary）。
 * 單筆：類別｜申請人、費用日｜金額；多筆：已選 N 筆｜申請人數｜合計。
 */
import { computed } from 'vue'
import type { ReimbursementSummary } from '@/api/reimbursements'
import { formatCurrency, formatDate } from '@/utils/format'

const props = defineProps<{ targets: ReimbursementSummary[] }>()
const one = computed(() => (props.targets.length === 1 ? props.targets[0] : null))
const total = computed(() => props.targets.reduce((a, x) => a + x.amount, 0))
const people = computed(() => new Set(props.targets.map((t) => t.employee.id)).size)
</script>

<template>
  <div v-if="one" class="dlg-summary">
    <b>{{ one.category.name }}</b>
    <span>{{ one.employee.name }}<span class="sep" aria-hidden="true" />費用日 {{ formatDate(one.incurredAt) }}</span>
    <strong>{{ formatCurrency(one.amount) }}</strong>
  </div>
  <div v-else-if="targets.length" class="dlg-summary">
    <b>已選 {{ targets.length }} 筆</b>
    <span>{{ people }} 位申請人</span>
    <strong>{{ formatCurrency(total) }}</strong>
  </div>
</template>
