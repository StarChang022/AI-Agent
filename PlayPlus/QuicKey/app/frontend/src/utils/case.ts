/**
 * snake_case ↔ camelCase 遞迴轉換。
 *
 * 用途：後端 wire format 為 snake_case、前端 domain / DTO 為 camelCase；
 * `api/service.ts` 於 request body / query 送出前呼叫 `toSnake`，
 * response payload 解析後呼叫 `toCamel`。
 *
 * 只轉換 **物件的 key**，不動 value：
 * - 陣列元素遞迴進去
 * - Date / File / Blob / FormData / null / primitive 直接回傳
 * - 已含 `_` 或大寫字母的 key 也一律套規則轉，保持行為可預測
 */

type JsonPrimitive = string | number | boolean | null

// 遇到後端偶爾用底線開頭（例如 __meta__）或全大寫錯誤碼時，原樣保留
function snakeToCamelKey(key: string): string {
  if (!key.includes('_')) return key
  return key.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase())
}

function camelToSnakeKey(key: string): string {
  return key.replace(/([A-Z])/g, (_, c: string) => `_${c.toLowerCase()}`)
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object') return false
  const proto = Object.getPrototypeOf(value)
  return proto === Object.prototype || proto === null
}

function transformKeys<T>(value: T, transformer: (key: string) => string): T {
  if (Array.isArray(value)) {
    return value.map((item) => transformKeys(item, transformer)) as unknown as T
  }
  if (isPlainObject(value)) {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(value)) {
      out[transformer(k)] = transformKeys(v, transformer)
    }
    return out as T
  }
  return value
}

export function toCamel<T = unknown>(value: unknown): T {
  return transformKeys(value, snakeToCamelKey) as T
}

export function toSnake<T = unknown>(value: unknown): T {
  return transformKeys(value, camelToSnakeKey) as T
}

export type { JsonPrimitive }
