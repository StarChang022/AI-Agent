import { createApp } from 'vue'
import './styles/index.css'
import './styles/layout.css'
import './styles/motion.css'
import App from './App.vue'
import router from './router'
import { vReveal } from './motion/reveal'

createApp(App).use(router).directive('reveal', vReveal).mount('#app')
