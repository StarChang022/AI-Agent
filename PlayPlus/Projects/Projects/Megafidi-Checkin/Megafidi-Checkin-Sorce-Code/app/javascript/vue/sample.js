import { createApp, watchEffect, reactive, ref } from 'vue/dist/vue.esm-bundler.js';

import axios from 'axios';
import Noty from 'noty';

window.Noty = Noty;

document.addEventListener('DOMContentLoaded', () => {

  let authenticity_token = document.querySelector("meta[name='csrf-token']").getAttribute("content");

  const app = createApp({
    components: {

    },
    setup() {
      const data = ref(gon.data)

      watchEffect(() => {
        fetchProducts()
      })

      return {
        data
      }
    }
  })

  app.mount('#vue-app');

})