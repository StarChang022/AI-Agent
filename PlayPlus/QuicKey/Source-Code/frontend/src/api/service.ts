/**
 * 前端 API 底層服務（fetch 封裝）。
 *
 * 職責：
 * - base URL：讀 `import.meta.env.VITE_API_BASE_URL`，未設定則走 dev proxy 的 `/api`
 * - Authorization header：從 localStorage 讀 JWT 自動注入
 * - 序列化：request body / query 由 camelCase → snake_case（FormData body 原樣送出）
 * - 反序列化：response JSON 由 snake_case → camelCase
 * - 錯誤：非 2xx 一律 throw `HttpError`，body 已 parse 為 camelCase
 *
 * 各 `api/*.ts` 業務模組透過本檔的 `service.get/post/...` 定義 endpoint fn；
 * store / composable 只 import 業務模組，不直接碰本檔或 fetch。
 */

import { AUTH_TOKEN_STORAGE_KEY } from './auth'
import { toCamel, toSnake } from '@/utils/case'

const DEFAULT_BASE_URL = '/api'

function baseUrl(): string {
  const configured = import.meta.env.VITE_API_BASE_URL as string | undefined
  return (configured ?? DEFAULT_BASE_URL).replace(/\/+$/, '')
}

export class HttpError<TBody = unknown> extends Error {
  readonly status: number
  readonly body: TBody

  constructor(status: number, body: TBody, message?: string) {
    super(message ?? `HTTP ${status}`)
    this.name = 'HttpError'
    this.status = status
    this.body = body
  }
}

type QueryScalar = string | number | boolean | null | undefined
type QueryValue = QueryScalar | ReadonlyArray<QueryScalar>
// 用 object 而非 Record<string, QueryValue>，讓具名 interface（如 ListBudgetsQuery）
// 不需宣告 index signature 也能結構相容；欄位型別限制由各 interface 自己把關。
type QueryParams = object

interface RequestOptions {
  query?: QueryParams
  /** 覆寫或補上 header；`Content-Type` 與 `Authorization` 已預設，不需重寫 */
  headers?: Record<string, string>
  /** 覆寫預設行為：不注入 Authorization header（例如 public endpoint） */
  skipAuth?: boolean
  /** 覆寫預設行為：request body 不做 camelCase → snake_case 轉換 */
  skipBodyTransform?: boolean
  /** 覆寫預設行為：response 不做 snake_case → camelCase 轉換 */
  skipResponseTransform?: boolean
  signal?: AbortSignal
}

function buildUrl(path: string, query?: QueryParams): string {
  const base = baseUrl()
  const cleanPath = path.startsWith('/') ? path : `/${path}`
  const url = `${base}${cleanPath}`
  if (!query) return url

  const snakeQuery = toSnake<Record<string, QueryValue>>(query)
  const search = new URLSearchParams()
  for (const [k, v] of Object.entries(snakeQuery)) {
    if (v === undefined || v === null) continue
    // 陣列展開為 Rails 慣例 `key[]=v1&key[]=v2`
    if (Array.isArray(v)) {
      for (const item of v) {
        if (item === undefined || item === null) continue
        search.append(`${k}[]`, String(item))
      }
      continue
    }
    search.append(k, String(v))
  }
  const qs = search.toString()
  return qs ? `${url}?${qs}` : url
}

function readToken(): string | null {
  if (typeof window === 'undefined') return null
  return window.localStorage.getItem(AUTH_TOKEN_STORAGE_KEY)
}

async function request<T = unknown>(
  method: string,
  path: string,
  body: unknown,
  options: RequestOptions = {},
): Promise<T> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...(options.headers ?? {}),
  }

  if (!options.skipAuth) {
    const token = readToken()
    if (token) headers.Authorization = `Bearer ${token}`
  }

  let payload: BodyInit | undefined
  if (body instanceof FormData) {
    // multipart：Content-Type（含 boundary）交給瀏覽器產生，欄位名由呼叫端自行用 snake_case
    payload = body
  } else if (body !== undefined && body !== null) {
    headers['Content-Type'] ??= 'application/json'
    const serialized = options.skipBodyTransform ? body : toSnake(body)
    payload = JSON.stringify(serialized)
  }

  const res = await fetch(buildUrl(path, options.query), {
    method,
    headers,
    body: payload,
    signal: options.signal,
  })

  // 204 或明確空 body：不 parse
  if (res.status === 204 || res.headers.get('content-length') === '0') {
    if (res.ok) return undefined as T
    throw new HttpError(res.status, undefined)
  }

  const text = await res.text()
  const raw = text.length === 0 ? undefined : JSON.parse(text)
  const parsed = options.skipResponseTransform ? raw : toCamel(raw)

  if (!res.ok) {
    throw new HttpError(res.status, parsed)
  }
  return parsed as T
}

/**
 * 下載檔案（xlsx / csv / pdf 等）。帶 Authorization；完成後觸發瀏覽器儲存對話框。
 * 檔名優先用伺服器回的 Content-Disposition，fallback 用傳入 filename。
 */
async function downloadFile(
  path: string,
  options: { query?: QueryParams; filename: string },
): Promise<void> {
  const headers: Record<string, string> = {}
  const token = readToken()
  if (token) headers.Authorization = `Bearer ${token}`

  const res = await fetch(buildUrl(path, options.query), { headers })
  if (!res.ok) {
    const text = await res.text()
    let body: unknown = text
    try { body = text.length ? JSON.parse(text) : undefined } catch { /* 保留原文 */ }
    throw new HttpError(res.status, body)
  }

  const blob = await res.blob()
  const filename = parseContentDispositionFilename(res) ?? options.filename
  const objectUrl = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = objectUrl
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(objectUrl)
}

function parseContentDispositionFilename(res: Response): string | null {
  const cd = res.headers.get('Content-Disposition')
  if (!cd) return null
  const star = /filename\*\s*=\s*(?:UTF-8'')?([^;]+)/i.exec(cd)
  if (star) {
    try { return decodeURIComponent(star[1].replace(/^"|"$/g, '').trim()) } catch { /* fall through */ }
  }
  const plain = /filename\s*=\s*"?([^";]+)"?/i.exec(cd)
  return plain ? plain[1].trim() : null
}

export const service = {
  get:    <T = unknown>(path: string, options?: RequestOptions) =>
    request<T>('GET', path, undefined, options),
  post:   <T = unknown>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('POST', path, body, options),
  put:    <T = unknown>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('PUT', path, body, options),
  patch:  <T = unknown>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('PATCH', path, body, options),
  delete: <T = unknown>(path: string, options?: RequestOptions) =>
    request<T>('DELETE', path, undefined, options),
  downloadFile,
}

export type { RequestOptions, QueryParams }
