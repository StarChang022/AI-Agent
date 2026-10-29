import { toRaw, type Ref } from 'vue'

/**
 * 表單「清除所有欄位」：記住欄位剛宣告時的預設值，reset() 整組還原並清掉錯誤訊息。
 * 要在欄位 ref 宣告完、還沒載入任何資料前呼叫，記到的才會是新增頁的預設值。
 */
export function useFormReset(fields: Ref<unknown>[], errors: Record<string, string>) {
  // 陣列 ref 的值是 reactive Proxy，structuredClone 不能直接複製，要先取原始值
  const initial = fields.map((f) => structuredClone(toRaw(f.value)))

  function reset() {
    fields.forEach((f, i) => {
      f.value = structuredClone(initial[i])
    })
    for (const k of Object.keys(errors)) errors[k] = ''
  }

  return { reset }
}
