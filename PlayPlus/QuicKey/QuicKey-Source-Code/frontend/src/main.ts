import { createApp } from 'vue'
import { createPinia } from 'pinia'
import PrimeVue from 'primevue/config'
import ToastService from 'primevue/toastservice'
import ConfirmationService from 'primevue/confirmationservice'
import Tooltip from 'primevue/tooltip'

import App from './App.vue'
import router from './router'
import { Quickey } from './presets/quickey'
import { installInputModality } from './utils/inputModality'

import './styles/index.css'
import 'primeicons/primeicons.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(PrimeVue, {
  theme: {
    preset: Quickey,
    options: {
      darkModeSelector: '.dark',
      cssLayer: {
        name: 'primevue',
        order: 'theme, base, primevue, utilities',
      },
    },
  },
  locale: {
    // 月份標籤顯示純數字（避開英文縮寫 Jan/Feb...），跟 DatePicker 的 yy/mm、yy-mm-dd 格式一致
    monthNames: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
    monthNamesShort: [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
    ],
    // MultiSelect 超過 maxSelectedLabels 時的摘要文字（PrimeVue v4 使用 locale.selectionMessage）
    selectionMessage: '已選 {0} 項',
  },
})
app.use(ToastService)
app.use(ConfirmationService)
app.directive('tooltip', Tooltip)

installInputModality()
app.mount('#app')

// PWA splash fade-out：等 router 決策完 + 至少 700ms（讓過場看起來是設計的，不是卡頓）
const splash = document.getElementById('app-splash')
if (splash && splash.style.display !== 'none') {
  const MIN_MS = 700
  Promise.all([
    router.isReady(),
    new Promise((resolve) => window.setTimeout(resolve, MIN_MS)),
  ]).then(() => {
    splash.style.opacity = '0'
    window.setTimeout(() => splash.remove(), 320)
  })
}
