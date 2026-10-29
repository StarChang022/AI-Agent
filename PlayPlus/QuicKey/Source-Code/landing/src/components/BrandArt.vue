<template>
  <svg class="brand-art" viewBox="0 0 1200 600" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <g class="art-spin" style="transform-box: view-box; transform-origin: 600px 300px">
      <circle v-for="r in [120, 200, 280, 360, 440, 520]" :key="r" cx="600" cy="300" :r="r"
        fill="none" stroke="rgba(255,255,255,0.14)" stroke-width="1.5" />
      <circle cx="600" cy="300" r="280" fill="none" stroke="rgba(88,205,192,0.45)" stroke-width="2"
        stroke-dasharray="6 14" />
    </g>
    <path d="M-20 520 C 260 420, 470 600, 760 500 S 1120 380, 1220 470" fill="none"
      stroke="rgba(140,221,212,0.28)" stroke-width="2" />
    <path d="M-20 560 C 260 470, 500 640, 790 540 S 1130 430, 1220 510" fill="none"
      stroke="rgba(140,221,212,0.16)" stroke-width="2" />
  </svg>
</template>
