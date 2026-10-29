<script setup lang="ts">
import { nextTick, reactive, ref } from 'vue'
import { CONTACT_EMAIL, LINE_ID, LINE_URL } from '../config'
import LottieDeco from '../components/LottieDeco.vue'
import contactAnimation from '../assets/lottie/contact-01.json'
import QSelect from '../components/QSelect.vue'

const topics = ['產品諮詢', '功能建議', '合作洽談', '其他問題']
const topicOptions = topics.map((t) => ({ value: t, label: t }))

const form = reactive({ name: '', company: '', email: '', phone: '', topic: '', message: '', human: false, agree: false })
const errors = reactive<Record<string, string>>({})
const status = ref<'idle' | 'sending' | 'done'>('idle')

function validate(): string[] {
  Object.keys(errors).forEach((k) => delete errors[k])
  if (!form.name.trim()) errors.name = '請填寫姓名'
  if (!form.email.trim()) errors.email = '請填寫 Email'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim())) errors.email = 'Email 格式好像不太對，再確認一下'
  if (!form.topic) errors.topic = '請選擇需求類別'
  if (form.message.trim().length < 5) errors.message = '請簡單描述你的需求（至少 5 個字）'
  if (!form.human) errors.human = '請先完成機器人驗證'
  if (!form.agree) errors.agree = '送出前請先同意隱私權政策'
  return Object.keys(errors)
}

async function submit() {
  const invalid = validate()
  if (invalid.length) {
    await nextTick()
    document.getElementById(invalid[0])?.focus()
    return
  }
  status.value = 'sending'
  // 示範版本：尚未串接後端，這裡只模擬送出
  await new Promise((r) => setTimeout(r, 700))
  Object.assign(form, { name: '', company: '', email: '', phone: '', topic: '', message: '', human: false, agree: false })
  status.value = 'done'
}
</script>

<template>
  <section class="section contact-section">
    <div class="container-page contact-page">
      <div class="contact-info">
        <h1 class="section-title contact-title" v-reveal="{ type: 'up', delay: 80 }">有任何問題，歡迎與我們聯繫</h1>
        <p class="lead contact-lead" v-reveal="{ type: 'soft', delay: 160 }">留下需求，我們會盡快回覆你。也可以直接透過 LINE 或 Email 聯絡。</p>

        <div class="contact-rows" v-reveal="{ type: 'soft', delay: 200 }">
          <div class="contact-row">
            <h3>LINE 官方帳號</h3>
            <a :href="LINE_URL" target="_blank" rel="noopener">{{ LINE_ID }}</a>
          </div>
          <div class="contact-row">
            <h3>Email</h3>
            <a :href="`mailto:${CONTACT_EMAIL}`">{{ CONTACT_EMAIL }}</a>
          </div>
        </div>

        <!-- 插畫播放一次後停在最後一格，不循環 -->
        <LottieDeco class="contact-art" :animation-data="contactAnimation" :loop="false" aria-hidden="true" v-reveal="{ type: 'soft', delay: 240 }" />
      </div>

      <div class="form-panel" v-reveal="{ type: 'soft', delay: 120 }">
        <div v-if="status === 'done'" class="form-success" role="status">
          <p style="font-size: 20px; font-weight: 600">已收到你的訊息</p>
          <p style="margin-top: 8px; font-weight: 400">我們會盡快回覆你。</p>
          <button type="button" class="btn-ghost btn-sm" style="margin-top: 16px" @click="status = 'idle'">再寫一則</button>
        </div>

        <form v-else class="form-grid" novalidate @submit.prevent="submit">
          <div class="field" :class="{ 'has-error': errors.name }">
            <label for="name">姓名<span class="req" aria-hidden="true">*</span></label>
            <input id="name" v-model="form.name" type="text" autocomplete="name" placeholder="請輸入你的姓名" required
              :aria-invalid="!!errors.name" aria-describedby="name-error" />
            <p v-if="errors.name" id="name-error" class="field-error" role="alert">{{ errors.name }}</p>
          </div>

          <div class="field">
            <label for="company">公司名稱</label>
            <input id="company" v-model="form.company" type="text" autocomplete="organization" placeholder="例如：快記股份有限公司" />
          </div>

          <div class="field" :class="{ 'has-error': errors.email }">
            <label for="email">Email<span class="req" aria-hidden="true">*</span></label>
            <input id="email" v-model="form.email" type="email" autocomplete="email" placeholder="name@company.com" required
              :aria-invalid="!!errors.email" aria-describedby="email-error" />
            <p v-if="errors.email" id="email-error" class="field-error" role="alert">{{ errors.email }}</p>
          </div>

          <div class="field">
            <label for="phone">聯絡電話</label>
            <input id="phone" v-model="form.phone" type="tel" autocomplete="tel" placeholder="例如：02-1234-5678" />
          </div>

          <div class="field full" :class="{ 'has-error': errors.topic }">
            <label for="topic">需求類別<span class="req" aria-hidden="true">*</span></label>
            <QSelect id="topic" v-model="form.topic" :options="topicOptions" placeholder="請選擇" required :invalid="!!errors.topic" describedby="topic-error" />
            <p v-if="errors.topic" id="topic-error" class="field-error" role="alert">{{ errors.topic }}</p>
          </div>

          <div class="field full" :class="{ 'has-error': errors.message }">
            <label for="message">需求說明<span class="req" aria-hidden="true">*</span></label>
            <textarea id="message" v-model="form.message" placeholder="請簡述你的需求，例如：想了解請款流程、員工權限設定或方案差異" required
              :aria-invalid="!!errors.message" aria-describedby="message-error" />
            <p v-if="errors.message" id="message-error" class="field-error" role="alert">{{ errors.message }}</p>
          </div>

          <div class="field full" :class="{ 'has-error': errors.human }">
            <div class="captcha">
              <label class="check" for="human">
                <input id="human" v-model="form.human" type="checkbox" :aria-invalid="!!errors.human" aria-describedby="human-error" />
                <span>我不是機器人</span>
              </label>
            </div>
            <p v-if="errors.human" id="human-error" class="field-error" role="alert">{{ errors.human }}</p>
          </div>

          <div class="field full" :class="{ 'has-error': errors.agree }">
            <label class="check" for="agree">
              <input id="agree" v-model="form.agree" type="checkbox" :aria-invalid="!!errors.agree" aria-describedby="agree-error" />
              <span>我已閱讀並同意<RouterLink to="/privacy">隱私權政策</RouterLink>，同意收到與本次需求相關的回覆。</span>
            </label>
            <p v-if="errors.agree" id="agree-error" class="field-error" role="alert">{{ errors.agree }}</p>
          </div>

          <div class="full submit-row">
            <button type="submit" class="btn-primary submit-btn" :disabled="status === 'sending'">
              {{ status === 'sending' ? '送出中…' : '送出需求' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* 左欄插畫：貼齊左欄底部（桌機），寬度跟隨左欄 */
.contact-art {
  width: 100%;
  max-width: 440px;
  margin-top: 48px;
}
@media (min-width: 960px) {
  .contact-info {
    display: flex;
    flex-direction: column;
  }
  .contact-art {
    margin-top: auto;
    padding-top: 48px;
  }
}
/* 左欄寬度依標題實際寬度，聯絡項目不超過標題寬度 */
@media (min-width: 960px) {
  .contact-info {
    width: fit-content;
    max-width: 100%;
  }
}
/* 聯絡資訊：標題與內容同一行 */
.contact-rows {
  display: grid;
  gap: 16px;
  margin-top: 32px;
}
.contact-row {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 16px;
}
.contact-row h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-ink);
}
.contact-title {
  margin-top: 0;
}
.contact-lead {
  margin-top: var(--section-lead-gap-top);
}
.contact-row a {
  font-size: 16px;
  color: var(--color-primary-700);
  text-decoration: none;
  word-break: break-all;
}
.contact-row a:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 2px;
  border-radius: 4px;
}
/* 機器人驗證（示意）：僅呈現版面，未串接實際驗證服務 */
.captcha {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-control);
}
.captcha .check {
  margin: 0;
}
/* ---- 表單：品牌綠卡片；欄位為白底加邊框，清楚呈現可輸入的區域 ---- */
.form-panel {
  padding: 36px;
  background: var(--color-primary-50);
  border: 0;
  border-radius: 28px;
  box-shadow: var(--shadow-card);
}
@media (max-width: 639.98px) {
  .form-panel {
    padding: 24px 20px;
  }
}
.form-grid {
  row-gap: 24px;
}
.field label {
  font-size: 15px;
  font-weight: 600;
  color: var(--color-ink);
}
.req {
  margin-left: 4px;
  color: var(--color-primary-600);
}
.field input:not([type='checkbox']),
.field textarea {
  width: 100%;
  min-height: 48px;
  box-sizing: border-box;
  padding: 12px 16px;
  font: inherit;
  font-size: 15px;
  color: var(--color-ink);
  background: var(--color-canvas);
  border: 1.5px solid var(--color-hairline-strong);
  border-radius: var(--radius-control);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.field input:not([type='checkbox'])::placeholder,
.field textarea::placeholder {
  color: var(--color-muted-soft);
  opacity: 1;
}
.field input:not([type='checkbox']):hover,
.field textarea:hover {
  border-color: var(--color-hairline-strong);
}
.field input:not([type='checkbox']):focus,
.field textarea:focus {
  outline: none;
  border-color: var(--color-primary-500);
  box-shadow: 0 0 0 3px var(--color-primary-100);
}
.field textarea {
  min-height: 140px;
  resize: vertical;
}
/* 需求類別下拉與其他欄位共用同一組邊框、高度與字級 */
.field :deep(.qselect-trigger) {
  min-height: 48px;
  padding: 12px 16px;
  font-size: 15px;
  border: 1.5px solid var(--color-hairline-strong);
  border-radius: var(--radius-control);
}
.field :deep(.qselect-trigger:hover) {
  border-color: var(--color-hairline-strong);
}
.field :deep(.qselect-trigger:focus-visible),
.field.has-error :deep(.qselect-trigger) {
  border-color: var(--color-primary-500);
}
.field.has-error :deep(.qselect-trigger) {
  border-color: #dc2626;
}
.field.has-error input:not([type='checkbox']),
.field.has-error textarea {
  border-color: #dc2626;
}
.submit-row {
  margin-top: 8px;
}
.submit-btn {
  width: 100%;
  min-height: 52px;
  font-size: 16px;
}
.submit-btn:disabled {
  opacity: 0.6;
  cursor: wait;
}
.captcha {
  background: var(--color-canvas);
  border: 1.5px solid var(--color-hairline-strong);
  border-radius: var(--radius-control);
}
.field.has-error .captcha {
  border-color: #dc2626;
}
</style>
