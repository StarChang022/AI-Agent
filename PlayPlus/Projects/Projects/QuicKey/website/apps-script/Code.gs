/**
 * 官網聯絡表單：備份到 Google 試算表
 *
 * 由官網的 /api/contact（Cloudflare Pages Functions）在背景呼叫，每筆留言新增一列到「留言」工作表。
 * 建立與部署步驟見 apps-script/README.md。
 *
 * 安全規則：
 * - 密碼放在「專案設定 → 指令碼屬性」的 SHEET_TOKEN，不寫在程式裡；密碼不符就不寫入
 * - 所有內容一律當文字寫入，填「=公式」也不會被執行
 * - 不可以用 console.log / Logger.log 印出表單內容，只記錄錯誤原因
 */

var SHEET_NAME = '留言'
var HEADERS = ['時間', '姓名', '公司', 'Email', '電話', '類別', '內容', '寄信成功']
// 各欄位長度上限：官網伺服器已經檢查過，這裡再保險一次。
// 這裡的長度算法會把 emoji 算成 2 個字，所以上限留兩倍，避免截掉正常內容。
var LIMITS = { name: 100, company: 200, email: 200, phone: 60, topic: 40, message: 4000 }

function doPost(e) {
  try {
    var data = JSON.parse((e && e.postData && e.postData.contents) || '{}')

    var expected = PropertiesService.getScriptProperties().getProperty('SHEET_TOKEN')
    if (!expected || data.token !== expected) return respond_({ ok: false, error: 'unauthorized' })

    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_NAME)
    if (!sheet) return respond_({ ok: false, error: 'sheet_not_found' })

    var row = [
      Utilities.formatDate(new Date(), 'Asia/Taipei', 'yyyy/MM/dd HH:mm:ss'),
      asText_(data.name, LIMITS.name),
      asText_(data.company, LIMITS.company),
      asText_(data.email, LIMITS.email),
      asText_(data.phone, LIMITS.phone),
      asText_(data.topic, LIMITS.topic),
      asText_(data.message, LIMITS.message),
      data.mailSent === true ? '是' : '否',
    ]

    // 同時有多筆送進來時，避免寫到同一列
    var lock = LockService.getScriptLock()
    lock.waitLock(10000)
    try {
      var range = sheet.getRange(sheet.getLastRow() + 1, 1, 1, row.length)
      range.setNumberFormat('@') // 整列設成純文字格式
      range.setValues([row])
    } finally {
      lock.releaseLock()
    }

    return respond_({ ok: true })
  } catch (err) {
    // 只記錄錯誤原因，不印出表單內容
    console.error('寫入失敗：' + (err && err.message ? err.message : err))
    return respond_({ ok: false, error: 'write_failed' })
  }
}

/** 轉成字串、截斷長度，開頭是 = + - @ 或定位字元時加上 '，讓試算表一律當文字 */
function asText_(value, max) {
  var s = value === undefined || value === null ? '' : String(value)
  if (s.length > max) s = s.slice(0, max)
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s
  return s
}

function respond_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON)
}

/**
 * 第一次設定時在編輯器裡手動執行一次：建立「留言」工作表和標題列（已經有就不動）。
 */
function setupSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet()
  var sheet = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME)
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS)
    sheet.setFrozenRows(1)
  }
}
