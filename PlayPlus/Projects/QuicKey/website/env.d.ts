/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<object, object, unknown>
  export default component
}

interface ImportMetaEnv {
  readonly VITE_SITE_URL?: string
  /** Cloudflare Turnstile 前端金鑰（建置時帶入） */
  readonly VITE_TURNSTILE_SITE_KEY?: string
}
