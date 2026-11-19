/** 憑證圖檔的類型判斷（縮圖、預覽、上傳共用） */

export function isImageMime(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}

/** 有些系統選 PDF 時 file.type 是空字串，用副檔名補判斷 */
export function isPdfFile(file: Pick<File, 'type' | 'name'>): boolean {
  return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')
}

export function isPdfAttachment(att: { mimeType: string; filename: string }): boolean {
  return att.mimeType === 'application/pdf' || att.filename.toLowerCase().endsWith('.pdf')
}
