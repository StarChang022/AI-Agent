import { computed, onBeforeUnmount, reactive, ref, type Ref } from 'vue'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import {
  MAX_ATTACHMENTS,
  MAX_ATTACHMENT_MB,
  deleteTempAttachments,
  fileUrl,
  uploadAttachments,
  type AttachErrorCode,
} from '@/api/attachments'
import { HttpError } from '@/api/service'
import type { Attachment } from '@/types/domain'
import type { FormAttachment } from '@/types/expense-form'
import { applyFreshUrls, useAttachmentUrlRefresh } from '@/composables/useAttachmentUrlRefresh'
import { isImageMime, isPdfFile } from '@/utils/attachment'
import { userErrorToast } from '@/utils/userFeedback'

let keySeq = 0
function nextKey() {
  keySeq += 1
  return `att-${keySeq}`
}

/** 後端回的圖檔轉成表單用的；saved = 已掛在紀錄上（編輯載入），false = 暫存檔（批次匯入帶入） */
export function toFormAttachment(att: Attachment, saved: boolean): FormAttachment {
  return {
    key: nextKey(),
    id: att.id,
    filename: att.filename,
    mimeType: att.mimeType,
    url: att.url,
    localUrl: null,
    saved,
    uploading: false,
  }
}

/** 儲存時要帶的新暫存檔 id（支出、收入、移轉只帶新的；已存的不用帶） */
export function newAttachmentIds(list: ReadonlyArray<FormAttachment>): string[] {
  return list.filter((a) => !a.saved && a.id).map((a) => a.id as string)
}

/**
 * 還有效的項目：上傳中或已有 id。上傳失敗的項目若在換頁後才失敗，會留在別筆的快照裡，
 * 多筆分頁的表單換頁載入時用這個濾掉
 */
export function isUsableAttachment(a: FormAttachment): boolean {
  return a.uploading || a.id !== null
}

/**
 * 批次匯入同一頁拆成多筆時共用同一個暫存檔：目前這筆或其他筆還有沒有用到這個 id。
 * 多筆分頁的表單用來判斷移除時能不能立刻刪暫存檔
 */
export function isUsedInPages(
  id: string,
  current: ReadonlyArray<FormAttachment>,
  pages: ReadonlyArray<{ attachments: ReadonlyArray<FormAttachment> }>,
  currentIndex: number,
): boolean {
  return (
    current.some((a) => a.id === id) ||
    pages.some((p, i) => i !== currentIndex && p.attachments.some((a) => a.id === id))
  )
}

function errorCode(err: unknown): string | undefined {
  if (!(err instanceof HttpError)) return undefined
  const body = err.body as { error?: unknown } | undefined
  return typeof body?.error === 'string' ? body.error : undefined
}

interface Options {
  /**
   * 編輯頁刪除已儲存的圖檔（立即永久刪除，先二次確認）。
   * 不提供時，已儲存的圖檔只從畫面移除，儲存時才生效（代墊款）
   */
  deleteSaved?: (attachmentId: string) => Promise<unknown>
  /** 已儲存圖檔刪除成功後；參數為 deleteSaved 的回傳（整筆紀錄） */
  onSavedDeleted?: (result: unknown) => void
  /** 編輯時重撈這筆紀錄的圖檔（網址失效時拿新網址）；新增時不提供 */
  fetchSaved?: () => Promise<Attachment[]>
  /** 上傳前處理檔案（例如前台壓縮圖片）；回傳要上傳的檔案 */
  prepare?: (file: File) => Promise<File>
  /**
   * 移除暫存檔時，同一個 id 是否還有其他地方在用（批次匯入同一頁拆成多筆會共用，見 isUsedInPages）。
   * 還在用就先不刪，留到離開頁面時一起清
   */
  isStillUsed?: (id: string) => boolean
}

/**
 * 表單的憑證上傳（docs/資料模型.md §2.4、docs/dev/attachments-api.md）：
 * - 選檔後立即上傳成暫存檔，上傳中顯示 loading，失敗提示原因並移除
 * - 移除尚未儲存的圖檔：直接刪暫存檔，不需確認
 * - 編輯頁移除已儲存的圖檔：二次確認後立即永久刪除（deleteSaved）
 * - 取消、關閉、離開頁面：discard() 刪除這次上傳但未儲存的暫存檔（元件卸載時自動執行）
 * - 簽章網址失效：onExpired() 重撈這筆紀錄拿新網址（fetchSaved）
 *
 * list 是表單目前顯示的憑證陣列；多筆分頁的表單換頁時可整個換掉，上傳中的項目完成後仍會更新到原本那一筆。
 */
export function useAttachmentUploads(list: Ref<FormAttachment[]>, options: Options = {}) {
  const toast = useToast()
  const confirm = useConfirm()
  const urlRefresh = useAttachmentUrlRefresh()

  /** 這次上傳或帶入、還沒確認掛上紀錄的暫存檔 id；discard 時一起刪（已掛上的後端會略過） */
  const tracked = new Set<string>()
  /** 上傳中被移除的項目；上傳完成時直接刪掉暫存檔 */
  const removedKeys = new Set<string>()
  const localUrls = new Set<string>()
  /** discard 後遞增；舊批次的上傳完成時直接刪掉 */
  let generation = 0
  let disposed = false

  /** 選檔後到上傳完成前（含前台壓縮）的檔案數；也算進張數上限 */
  const pendingUploads = ref(0)
  const isUploading = computed(() => pendingUploads.value > 0)
  /** 刪除已存圖檔的確認視窗開著；放在 Dialog 內時外層要據此停用 Esc 關閉 */
  const confirming = ref(false)
  const deletingKeys = ref(new Set<string>())

  function deleteTemp(ids: string[]) {
    // 失敗也沒關係：超過 24 小時未掛上的暫存檔後端每天會清除
    deleteTempAttachments(ids).catch(() => {})
  }

  function validate(file: File): string | null {
    if (!['image/jpeg', 'image/png'].includes(file.type) && !isPdfFile(file)) return '只接受 JPG、PNG 或 PDF'
    if (file.size > MAX_ATTACHMENT_MB * 1024 * 1024) return `超過 ${MAX_ATTACHMENT_MB}MB，請壓縮後再上傳`
    return null
  }

  async function uploadOne(file: File) {
    const gen = generation
    let toUpload = file
    if (options.prepare) {
      try {
        toUpload = await options.prepare(file)
      } catch {
        toast.add({ severity: 'error', summary: `${file.name} 讀取失敗`, detail: '請重新選擇檔案。', life: 3500 })
        return
      }
    }
    const invalid = validate(toUpload)
    if (invalid) {
      toast.add({ severity: 'warn', summary: `${file.name} 無法上傳`, detail: invalid, life: 3500 })
      return
    }
    const mimeType = toUpload.type || 'application/pdf'
    const localUrl = isImageMime(mimeType) ? URL.createObjectURL(toUpload) : null
    if (localUrl) localUrls.add(localUrl)
    const item = reactive<FormAttachment>({
      key: nextKey(),
      id: null,
      filename: toUpload.name,
      mimeType,
      url: null,
      localUrl,
      saved: false,
      uploading: true,
    })
    list.value.push(item)
    try {
      const [att] = await uploadAttachments([toUpload])
      if (disposed || gen !== generation || removedKeys.has(item.key)) {
        deleteTemp([att.id])
        return
      }
      tracked.add(att.id)
      Object.assign(item, { id: att.id, filename: att.filename, mimeType: att.mimeType, url: att.url, uploading: false })
    } catch (err) {
      // 換頁後才失敗時項目留在別筆的快照，id 為 null、不再上傳中，換回該筆時由 isUsableAttachment 濾掉
      item.uploading = false
      list.value = list.value.filter((a) => a.key !== item.key)
      if (!disposed && gen === generation) {
        toast.add({ severity: 'error', ...userErrorToast(err, `${file.name} 上傳失敗`), life: 3500 })
      }
    }
  }

  /** 選檔或拖放；超過張數的提示後略過，其餘同時上傳 */
  async function addFiles(files: ReadonlyArray<File>) {
    if (files.length === 0) return
    // 還在壓縮、尚未出現在清單的檔案也要算進去，避免連續選檔超過上限
    const waiting = pendingUploads.value - list.value.filter((a) => a.uploading).length
    const room = Math.max(MAX_ATTACHMENTS - list.value.length - Math.max(waiting, 0), 0)
    if (files.length > room) {
      toast.add({ severity: 'warn', summary: `最多上傳 ${MAX_ATTACHMENTS} 張憑證`, life: 3000 })
    }
    const accepted = files.slice(0, room)
    pendingUploads.value += accepted.length
    await Promise.all(
      accepted.map((f) =>
        uploadOne(f).finally(() => {
          pendingUploads.value -= 1
        }),
      ),
    )
  }

  function releaseTemp(att: FormAttachment) {
    if (att.uploading) {
      removedKeys.add(att.key)
      return
    }
    if (!att.id) return
    if (options.isStillUsed?.(att.id)) return
    tracked.delete(att.id)
    deleteTemp([att.id])
  }

  async function deleteSavedNow(att: FormAttachment) {
    if (!options.deleteSaved || !att.id) return
    deletingKeys.value = new Set(deletingKeys.value).add(att.key)
    try {
      const result = await options.deleteSaved(att.id)
      list.value = list.value.filter((a) => a.key !== att.key)
      toast.add({ severity: 'success', summary: '圖檔已刪除', detail: att.filename, life: 2500 })
      options.onSavedDeleted?.(result)
    } catch (err) {
      if (err instanceof HttpError && err.status === 404 && errorCode(err) === 'ATTACHMENT_NOT_FOUND') {
        // 別處已刪除：畫面同步拿掉
        list.value = list.value.filter((a) => a.key !== att.key)
        toast.add({ severity: 'info', summary: '這張圖檔已不存在', detail: att.filename, life: 3000 })
        return
      }
      toast.add({ severity: 'error', ...userErrorToast(err, '刪除圖檔失敗'), life: 3500 })
    } finally {
      const next = new Set(deletingKeys.value)
      next.delete(att.key)
      deletingKeys.value = next
    }
  }

  /** 移除一張：暫存檔直接刪；已儲存的在編輯頁先確認再立即永久刪除 */
  function remove(att: FormAttachment) {
    if (att.saved && options.deleteSaved) {
      confirming.value = true
      confirm.require({
        header: '刪除圖檔',
        message: `「${att.filename}」會立即永久刪除，無法復原；之後取消編輯也不會恢復。確定要刪除嗎？`,
        icon: 'pi pi-exclamation-triangle',
        acceptLabel: '永久刪除',
        rejectLabel: '取消',
        acceptProps: { severity: 'danger' },
        accept: () => void deleteSavedNow(att),
        onHide: () => (confirming.value = false),
      })
      return
    }
    list.value = list.value.filter((a) => a.key !== att.key)
    if (!att.saved) releaseTemp(att)
  }

  /** 整筆拿掉（多筆分頁的「移除這筆」）：這筆的暫存檔比照移除單張處理；呼叫前先把該筆從分頁移除 */
  function release(atts: ReadonlyArray<FormAttachment>) {
    for (const a of atts) if (!a.saved) releaseTemp(a)
  }

  /** 批次匯入帶進來的暫存檔，也算這次的，離開時一起清 */
  function adopt(atts: ReadonlyArray<FormAttachment>) {
    for (const a of atts) if (!a.saved && a.id) tracked.add(a.id)
  }

  /**
   * 儲存成功後：這些圖檔已掛上紀錄，標成已儲存、不必再刪。
   * 編輯支出時更新成功、接著付款失敗，重試就不會再帶同一批 id
   */
  function markAttached(atts: ReadonlyArray<FormAttachment>) {
    for (const a of atts) {
      if (a.saved || !a.id) continue
      a.saved = true
      tracked.delete(a.id)
    }
  }

  /**
   * 儲存回 422 ATTACHMENT_NOT_FOUND（暫存檔已逾時清除）時：找出讀不到的暫存檔，從畫面移除並列出檔名。
   * 不是這個錯誤回 false
   */
  async function handleSaveError(err: unknown): Promise<boolean> {
    if (errorCode(err) !== ('ATTACHMENT_NOT_FOUND' satisfies AttachErrorCode)) return false
    const temps = list.value.filter((a) => !a.saved && a.id && a.url)
    const missing: FormAttachment[] = []
    await Promise.all(
      temps.map(async (a) => {
        try {
          const res = await fetch(fileUrl(a.url as string), { method: 'HEAD' })
          if (res.status === 404) missing.push(a)
        } catch {
          // 網路錯誤：判斷不了，保留
        }
      }),
    )
    if (missing.length) {
      const keys = new Set(missing.map((a) => a.key))
      list.value = list.value.filter((a) => !keys.has(a.key))
      for (const a of missing) if (a.id) tracked.delete(a.id)
      toast.add({
        severity: 'warn',
        summary: '有圖檔已逾時清除，請重新上傳',
        detail: missing.map((a) => a.filename).join('、'),
        life: 5000,
      })
    }
    return true
  }

  /** 縮圖或預覽讀不到（簽章網址失效）：重撈這筆紀錄拿新網址；同一張只重撈一次 */
  async function onExpired(att: FormAttachment) {
    if (!att.saved || !att.url || !options.fetchSaved) return
    const fresh = await urlRefresh.refresh(att.url, 'record', options.fetchSaved)
    if (fresh) applyFreshUrls(list.value, fresh)
  }

  /** 取消、關閉、離開：刪除這次上傳但未儲存的暫存檔；上傳中的完成後也會刪 */
  function discard() {
    generation += 1
    removedKeys.clear()
    const ids = [...tracked]
    tracked.clear()
    if (ids.length) deleteTemp(ids)
  }

  onBeforeUnmount(() => {
    discard()
    disposed = true
    for (const u of localUrls) URL.revokeObjectURL(u)
    localUrls.clear()
  })

  return {
    addFiles,
    remove,
    release,
    adopt,
    markAttached,
    handleSaveError,
    onExpired,
    discard,
    isUploading,
    confirming,
    deletingKeys,
  }
}
