/**
 * 全站共用的 DatePicker：沿用 PrimeVue DatePicker 的所有 props、事件與樣式，只修正手打日期的行為。
 * 用法與 PrimeVue 相同：`import DatePicker from '@/components/qds/DatePicker'`。
 *
 * PrimeVue 4.5 的問題：
 * 1. 逐字手打時，打到一半能解析成日期（例如「2026-10-1」→ 10/1）就更新 v-model，接著把格式化後的
 *    「2026-10-01」交回內層輸入框，蓋掉正在打的字，游標留在原位，下一個字就插錯位置
 *    （打「2026-10-15」變成「2026-10-051」）。
 * 2. 離開欄位時，把打到一半的文字補成最後解析出的日期（「2026-10-0」→ 10/02），等於寫入使用者沒打完的值。
 * 3. 聚焦時日曆會自動展開；這時點日曆圖示，按下瞬間輸入框先失焦（觸發第 2 點），點擊又把日曆收起來。
 *
 * 這裡的規則（只套用在單日、可手打的欄位；區間、多選、含時間的維持 PrimeVue 原本行為）：
 * - 輸入中：文字是完整、合法的日期（照欄位格式寫完整，例如 2026-10-15）才更新 v-model；
 *   打到一半不動 v-model，也就不會被重新格式化。清空文字照常更新為空值。
 * - 離開欄位：文字不完整或不合法，恢復成這次聚焦前的值（原本空白就維持空白）。
 * - 日曆圖示：按下時不讓輸入框失焦；聚焦時自動展開的日曆，點圖示維持展開，再點一次才收起。
 */
import { type ComponentOptions } from 'vue'
import PrimeDatePicker from 'primevue/datepicker'

interface PickerThis {
  selectionMode: string
  manualInput: boolean
  showTime: boolean
  timeOnly: boolean
  overlayVisible: boolean
  rawValue: unknown
  input: HTMLInputElement | null
  $el: HTMLElement
  /** 這次聚焦前的值；離開欄位時文字不完整就還原成它 */
  valueOnFocus: unknown
  /** 日曆是因為聚焦才自動展開的 */
  openedByFocus: boolean
  parseValue(text: string): unknown
  formatValue(value: unknown): string
  isValidSelection(value: unknown): boolean
  updateModel(value: unknown): void
  isCompleteDate(text: string): boolean
  handlesTyping(): boolean
  $emit(event: string, ...args: unknown[]): void
}

const base = (PrimeDatePicker as unknown as { methods: Record<string, (...args: unknown[]) => unknown> }).methods
function callBase(name: string, self: PickerThis, ...args: unknown[]) {
  return base[name].apply(self, args)
}

/** 日曆圖示與下拉按鈕：按下時不搶走輸入框焦點 */
const ICON_SELECTOR = '[data-pc-section="inputiconcontainer"], [data-pc-section="dropdown"]'

function sameValue(a: unknown, b: unknown): boolean {
  if (a instanceof Date && b instanceof Date) return a.getTime() === b.getTime()
  return a === b || (a == null && b == null)
}

const DatePicker: ComponentOptions = {
  name: 'DatePicker',
  extends: PrimeDatePicker as unknown as ComponentOptions,
  data: () => ({ valueOnFocus: null, openedByFocus: false }),
  mounted(this: PickerThis) {
    this.$el.addEventListener('mousedown', (e: MouseEvent) => {
      if ((e.target as HTMLElement | null)?.closest(ICON_SELECTOR)) e.preventDefault()
    })
  },
  methods: {
    handlesTyping(this: PickerThis) {
      return this.selectionMode === 'single' && this.manualInput && !this.showTime && !this.timeOnly
    },
    /** 照欄位格式寫完整的合法日期：解析後再格式化，要和輸入的文字一模一樣 */
    isCompleteDate(this: PickerThis, text: string) {
      const t = text.trim()
      try {
        const d = this.parseValue(t)
        return d instanceof Date && !isNaN(d.getTime()) && this.isValidSelection(d) && this.formatValue(d) === t
      } catch {
        return false
      }
    },
    onFocus(this: PickerThis, event: FocusEvent) {
      const wasOpen = this.overlayVisible
      this.valueOnFocus = this.rawValue
      callBase('onFocus', this, event)
      this.openedByFocus = !wasOpen && this.overlayVisible
    },
    onInput(this: PickerThis, event: Event) {
      const text = (event.target as HTMLInputElement).value
      if (!this.handlesTyping() || text.trim() === '' || this.isCompleteDate(text)) {
        callBase('onInput', this, event)
        return
      }
      // 打到一半：不更新 v-model，只轉發 input 事件
      this.$emit('input', event)
    },
    onBlur(this: PickerThis, event: FocusEvent) {
      const el = event.target as HTMLInputElement
      const text = el.value
      const revert = this.handlesTyping() && text.trim() !== '' && !this.isCompleteDate(text)
      // 先還原 v-model 再交給 PrimeVue 發出 blur，讓呼叫端在 blur 時拿到的是還原後的值
      if (revert && !sameValue(this.rawValue, this.valueOnFocus)) this.updateModel(this.valueOnFocus)
      callBase('onBlur', this, event)
      if (revert) el.value = this.valueOnFocus ? this.formatValue(this.valueOnFocus) : ''
    },
    onButtonClick(this: PickerThis) {
      // 聚焦時自動展開的日曆：點圖示維持展開（只是把焦點留在輸入框），下一次再點才收起
      if (this.overlayVisible && this.openedByFocus) {
        this.openedByFocus = false
        this.input?.focus()
        return
      }
      callBase('onButtonClick', this)
      this.openedByFocus = false
    },
  },
}

export default DatePicker as unknown as typeof PrimeDatePicker
