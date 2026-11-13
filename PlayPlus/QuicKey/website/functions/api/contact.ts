// POST /api/contact：官網聯絡表單
// 流程：驗證 Turnstile → 伺服器端驗證欄位 → 用 Resend 寄信 → 背景備份到 Google 試算表
// 回應以寄信結果為準；試算表只是備份，失敗不影響回應，但會寄通知信到 ALERT_TO（見 docs/上線前規格.md D14）。
// 注意：執行紀錄只記錄錯誤原因，不可以印出表單內容（見 docs/上線前規格.md 一-2）。

interface Env {
  RESEND_API_KEY: string
  TURNSTILE_SECRET_KEY: string
  /** 收件人，可用逗號分隔多個 */
  MAIL_TO: string
  /** 寄件人，例如 `Quickey 官網 <noreply@quickey.com.tw>` */
  MAIL_FROM: string
  /** Apps Script 網頁應用程式網址；未設定時略過備份 */
  SHEET_WEBHOOK_URL?: string
  /** 送到 Apps Script 的密碼，要跟 Script Properties 裡的 SHEET_TOKEN 相同 */
  SHEET_TOKEN?: string
  /** 試算表備份失敗時的通知收件人，可用逗號分隔多個；未設定時不寄通知 */
  ALERT_TO?: string
}

interface ContactFields {
  name: string
  company: string
  email: string
  phone: string
  topic: string
  message: string
}

type FieldErrors = Partial<Record<keyof ContactFields | 'agree' | 'turnstile' | 'form', string>>

const TOPICS = ['產品諮詢', '功能建議', '合作洽談', '其他問題']
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const MAX_BODY_CHARS = 20_000
const SITEVERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'
const RESEND_URL = 'https://api.resend.com/emails'

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const { request, env } = context

  const raw = await request.text()
  if (raw.length > MAX_BODY_CHARS) return json(413, { errors: { form: '內容太長' } })

  let body: Record<string, unknown>
  try {
    const parsed: unknown = JSON.parse(raw)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('not an object')
    body = parsed as Record<string, unknown>
  } catch {
    return json(400, { errors: { form: '資料格式錯誤' } })
  }

  // 1. Turnstile（token 只能驗一次，前端失敗後要重置 widget）
  const token = body.turnstileToken
  if (typeof token !== 'string' || !token || token.length > 2048) {
    return json(400, { errors: { turnstile: '請先完成機器人驗證' } })
  }
  let human: boolean
  try {
    human = await verifyTurnstile(token, env.TURNSTILE_SECRET_KEY, request.headers.get('CF-Connecting-IP'))
  } catch (err) {
    console.error('Turnstile 驗證服務連線失敗：', errorReason(err))
    return json(502, { error: 'turnstile_unavailable' })
  }
  if (!human) return json(400, { errors: { turnstile: '機器人驗證沒有通過，請重新驗證' } })

  // 2. 欄位
  const { fields, errors } = validate(body)
  if (Object.keys(errors).length) return json(400, { errors })

  // 3. 寄信
  const submittedAt = new Date()
  const mailSent = await sendMail(env, fields, submittedAt)

  // 4. 備份到試算表（背景執行，不讓填表人多等；寄信失敗也照樣備份）
  context.waitUntil(backupToSheetAndAlert(env, fields, mailSent))

  return mailSent ? json(200, { ok: true }) : json(502, { error: 'mail_failed' })
}

function json(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  })
}

/** 逗號分隔的收件人清單 */
function recipients(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
}

function errorReason(err: unknown): string {
  return err instanceof Error ? err.message : String(err)
}

/** 以字元數計算長度（中文、emoji 都算 1 個字） */
function charLength(value: string): number {
  return [...value].length
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

/** 單行欄位：換行改成空白，避免夾帶內容到信件標頭 */
function singleLine(value: unknown): string {
  return text(value).replace(/[\r\n\u2028\u2029]+/g, ' ').trim()
}

function validate(body: Record<string, unknown>): { fields: ContactFields; errors: FieldErrors } {
  const fields: ContactFields = {
    name: singleLine(body.name),
    company: singleLine(body.company),
    email: singleLine(body.email),
    phone: singleLine(body.phone),
    topic: singleLine(body.topic),
    message: text(body.message).replace(/\r\n?/g, '\n').trim(),
  }
  const errors: FieldErrors = {}

  if (!fields.name) errors.name = '請填寫姓名'
  else if (charLength(fields.name) > 50) errors.name = '姓名最多 50 個字'

  if (charLength(fields.company) > 100) errors.company = '公司名稱最多 100 個字'

  if (!fields.email) errors.email = '請填寫 Email'
  else if (charLength(fields.email) > 100) errors.email = 'Email 最多 100 個字'
  else if (!EMAIL_RE.test(fields.email)) errors.email = 'Email 格式好像不太對，再確認一下'

  if (charLength(fields.phone) > 30) errors.phone = '聯絡電話最多 30 個字'

  if (!TOPICS.includes(fields.topic)) errors.topic = '請選擇需求類別'

  const messageLength = charLength(fields.message)
  if (messageLength === 0) errors.message = '請簡單描述你的需求'
  else if (messageLength > 2000) errors.message = '需求說明最多 2000 個字'

  if (body.agree !== true) errors.agree = '送出前請先同意隱私權政策'

  return { fields, errors }
}

async function verifyTurnstile(token: string, secret: string, ip: string | null): Promise<boolean> {
  const form = new FormData()
  form.append('secret', secret)
  form.append('response', token)
  if (ip) form.append('remoteip', ip)

  const res = await fetch(SITEVERIFY_URL, { method: 'POST', body: form })
  if (!res.ok) throw new Error(`siteverify HTTP ${res.status}`)
  const data = (await res.json()) as { success?: boolean; 'error-codes'?: string[] }
  if (!data.success) console.warn('Turnstile 驗證未通過：', (data['error-codes'] ?? []).join(',') || 'unknown')
  return data.success === true
}

function formatTaipeiTime(date: Date): string {
  return new Intl.DateTimeFormat('zh-TW', {
    timeZone: 'Asia/Taipei',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date)
}

function mailText(f: ContactFields, submittedAt: Date): string {
  const blank = '（未填）'
  return [
    '官網聯絡表單有一則新留言。',
    '直接按「回覆」就會回信給填表人。',
    '',
    `姓名：${f.name}`,
    `公司名稱：${f.company || blank}`,
    `Email：${f.email}`,
    `聯絡電話：${f.phone || blank}`,
    `需求類別：${f.topic}`,
    `送出時間：${formatTaipeiTime(submittedAt)}（台北時間）`,
    '',
    f.message,
  ].join('\n')
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

// 表單內容都要先 escapeHtml，避免填表人塞 HTML 進通知信
function mailHtml(f: ContactFields, submittedAt: Date): string {
  const blank = '（未填）'
  const email = escapeHtml(f.email)
  const rows: [string, string][] = [
    ['姓名', escapeHtml(f.name)],
    ['公司名稱', escapeHtml(f.company || blank)],
    ['Email', `<a href="mailto:${email}">${email}</a>`],
    ['聯絡電話', escapeHtml(f.phone || blank)],
    ['需求類別', escapeHtml(f.topic)],
    ['送出時間', `${formatTaipeiTime(submittedAt)}（台北時間）`],
  ]
  const message = escapeHtml(f.message).replace(/\r?\n/g, '<br>')
  return [
    '<div>',
    '官網聯絡表單有一則新留言。<br>',
    '直接按「回覆」就會回信給填表人。<br>',
    '<br>',
    ...rows.map(([label, value]) => `<b>${label}</b>：${value}<br>`),
    '<br>',
    `<div style="background-color:#f7f7f7;border-left:4px solid #333;padding:12px 16px;margin-top:6px;font-size:14px">${message}</div>`,
    '</div>',
  ].join('\n')
}

async function sendMail(env: Env, f: ContactFields, submittedAt: Date): Promise<boolean> {
  const to = recipients(env.MAIL_TO)
  if (!env.RESEND_API_KEY || !env.MAIL_FROM || to.length === 0) {
    console.error('寄信設定不完整：請確認 RESEND_API_KEY、MAIL_FROM、MAIL_TO')
    return false
  }

  try {
    const res = await fetch(RESEND_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        to,
        reply_to: f.email,
        subject: `[官網留言] ${f.topic}｜${f.name}`,
        text: mailText(f, submittedAt),
        html: mailHtml(f, submittedAt),
      }),
    })
    if (!res.ok) {
      // Resend 的錯誤訊息可能夾帶 Email 等表單內容，只記錄狀態碼和錯誤類型
      const err = (await res.json().catch(() => null)) as { name?: string } | null
      console.error('Resend 寄信失敗：', res.status, err?.name ?? 'unknown')
      return false
    }
    return true
  } catch (err) {
    console.error('Resend 連線失敗：', errorReason(err))
    return false
  }
}

const SHEET_ERROR_REASONS: Record<string, string> = {
  unauthorized: '密碼不符（Cloudflare 的 SHEET_TOKEN 和 Apps Script 指令碼屬性的 SHEET_TOKEN 不一樣）',
  sheet_not_found: '找不到「留言」工作表（可能被改名或刪除）',
  write_failed: 'Apps Script 寫入試算表時發生錯誤（詳細原因見 Apps Script 的「執行作業」紀錄）',
}

/**
 * 備份到試算表。成功或未設定時回傳 null；失敗時回傳失敗原因（不含表單內容）。
 */
async function backupToSheet(env: Env, f: ContactFields, mailSent: boolean): Promise<string | null> {
  if (!env.SHEET_WEBHOOK_URL || !env.SHEET_TOKEN) {
    console.warn('未設定 SHEET_WEBHOOK_URL 或 SHEET_TOKEN，略過試算表備份')
    return null
  }
  let res: Response
  try {
    // Apps Script 會先回 302 轉址到結果頁，fetch 預設會跟著轉址拿到結果
    res = await fetch(env.SHEET_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: env.SHEET_TOKEN, ...f, mailSent }),
    })
  } catch (err) {
    const reason = errorReason(err)
    console.error('試算表備份連線失敗：', reason)
    return `連不上 Apps Script（${reason}）`
  }

  const data = (await res.json().catch(() => null)) as { ok?: boolean; error?: string } | null
  if (res.ok && data?.ok) return null

  const code = data?.error ?? 'unknown'
  console.error('試算表備份失敗：', res.status, code)
  if (!res.ok) return `Apps Script 回應 HTTP ${res.status}（網址可能換了或已停用）`
  if (!data) return 'Apps Script 回應的不是預期的格式（部署的「誰可以存取」可能不是「所有人」，或網址不是 /exec 結尾）'
  return SHEET_ERROR_REASONS[code] ?? `Apps Script 回應失敗（${code}）`
}

async function backupToSheetAndAlert(env: Env, f: ContactFields, mailSent: boolean): Promise<void> {
  const reason = await backupToSheet(env, f, mailSent)
  if (reason) await sendSheetAlert(env, reason, mailSent, new Date())
}

/** 試算表失敗通知信：不可以放任何表單內容（姓名、Email、電話、留言） */
function alertText(reason: string, mailSent: boolean, failedAt: Date): string {
  return [
    '官網聯絡表單有一筆留言沒有備份到試算表。',
    '',
    `失敗時間：${formatTaipeiTime(failedAt)}（台灣時間）`,
    `失敗原因：${reason}`,
    `這一筆的留言信：${mailSent ? '有寄成功' : '也寄送失敗'}`,
    '',
    '處理方式：',
    mailSent
      ? '留言信已寄到信箱，資料在信裡。修好試算表後，從那封信手動把資料補進試算表。'
      : '留言信也沒寄出，填表人當下會看到「寄送失敗」，通常會再送一次。請一併檢查 Resend 的寄信設定。',
    '',
    '修好後請到官網送一筆測試留言，確認信箱和試算表都有收到，而且沒有再收到這封通知。',
    '建立與修改試算表的步驟見 repo 的 apps-script/README.md。',
  ].join('\n')
}

async function sendSheetAlert(env: Env, reason: string, mailSent: boolean, failedAt: Date): Promise<void> {
  const to = recipients(env.ALERT_TO)
  if (to.length === 0) return
  if (!env.RESEND_API_KEY || !env.MAIL_FROM) {
    console.error('無法寄出試算表失敗通知：請確認 RESEND_API_KEY、MAIL_FROM')
    return
  }

  try {
    const res = await fetch(RESEND_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        to,
        subject: '[官網] 試算表備份失敗',
        text: alertText(reason, mailSent, failedAt),
      }),
    })
    if (!res.ok) {
      const err = (await res.json().catch(() => null)) as { name?: string } | null
      console.error('試算表失敗通知寄送失敗：', res.status, err?.name ?? 'unknown')
    }
  } catch (err) {
    console.error('試算表失敗通知連線失敗：', errorReason(err))
  }
}
