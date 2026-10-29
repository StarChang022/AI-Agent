import { driver, type Driver, type DriveStep } from 'driver.js'
import 'driver.js/dist/driver.css'
import { useRouter, type Router } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingStore } from '@/stores/onboarding'

/**
 * Onboarding tour composable。
 *
 * 依 auth.role 動態選 admin（10 步：核心 9 步 + 尾步指向右上角「新手導覽」
 * 入口）或 employee（4 步：核心 3 步 + 尾步同上）steps，跨頁跳轉時先
 * router.push、polling 等 target 出現（500ms）、scrollIntoView + 等 smooth
 * scroll 完成後才 highlight，讓 fold 以下 target 也能被打亮（見 openspec
 * add-onboarding-wizard design.md Decision 4 / 5 / 7 / 11 / 12）。
 * onNextClick / onPrevClick 皆會先切 route + 等 target 再交給 driver
 * 前進/後退，兩向對稱避免上一步 fallback 到中央 tooltip。
 *
 * 尾步的 target 是 PrimeVue Menu popup 內的「新手導覽」項目，透過 step 的
 * preAction 呼叫 onboarding.setUserMenuOpen(true) → UserBadge watch 到 →
 * 程式化打開 popup；離開該步（上一步/完成/關閉）都會歸零狀態，讓 popup
 * 關掉。z-index 上刻意讓 driver.js 遮罩蓋在 menu popup 之上（menu 用
 * PrimeVue 預設 ~1000，driver overlay ~10000），透過 SVG 挖空效果讓
 * 「新手導覽」項目被 highlight，其他 menu item 一起被 dim。
 *
 * driver 實例存 module-scope，避免同時多實例衝突（Decision 9）。tour 結束
 * 或按 X / Esc 都會走 onDestroyed hook 標記完成，語意單一入口。
 *
 * 手機端為 first-class：popover 未設 `side` 讓 driver.js 依 viewport 自動
 * 選方向；mobile 樣式覆寫（max-width 320px、safe-area padding）在 styles/index.css
 * 內處理（Decision 6）。
 */

interface TourStep {
  routeName: string
  selector: string
  title: string
  description: string
  /**
   * 該步對應的 sidebar nav item route name（僅 admin 桌機用；手機 drawer 隱藏
   * 不受影響）。留空表示不打亮 sidebar（例如深頁面）。若跟 routeName 一樣可省略；
   * 深頁如 admin-expense-new 對應 sidebar 「支出管理」= admin-expenses，需明填。
   */
  sidebarRouteName?: string
  /**
   * scrollIntoView 的 block 參數，預設 'center'（適合小 target）。當 target
   * 高於 viewport（例如整個 form 或 table）時設 'start'，把頂部對齊 viewport
   * 頂部，避免頂部區塊（如「填寫支出內容」的 圖片上傳/開始辨識）落在 viewport
   * 上方看不到。因 driver.js 自己也會 center-scroll，onHighlighted 內再覆蓋
   * 一次才會生效。
   */
  scrollBlock?: ScrollLogicalPosition
  /**
   * 手機/平板（viewport < lg = 1024px）下把 target 內部水平 scroll 到最右，
   * 讓右側「操作」欄的行動按鈕（通過/駁回）出現在 viewport 內。
   * 桌機通常整張表 fit 得下，不需 scroll → 略過。
   */
  scrollToRight?: boolean
  /**
   * 該步 target 需先做動作才會出現（例如打開右上角選單才能看到「新手導覽」項目）。
   * 在 route 切換之後、waitForSelector 之前執行；若回傳 Promise 會 await。
   * 對應的離開清理（例如關閉選單）由 onPrevClick / onDestroyed 觸發。
   */
  preAction?: () => void | Promise<void>
}

const ADMIN_STEPS: TourStep[] = [
  {
    routeName: 'admin-expenses',
    selector: '[data-tour="expenses-new-button"]',
    title: '歡迎使用 Quickey',
    description:
      '接下來 10 步會帶你走過核心功能，隨時可點擊右上角結束導覽。<br>第一步：新增支出，支援 OCR 辨識、多筆匯入、手動輸入等方式。',
  },
  {
    routeName: 'admin-expense-new',
    selector: '[data-tour="expense-upload-area"]',
    title: '填寫支出內容',
    description:
      '上傳發票或收據圖片，自動辨識金額、廠商、明細等內容，或手動在下方輸入內容。',
    sidebarRouteName: 'admin-expenses',
  },
  {
    routeName: 'admin-expenses',
    selector: '[data-tour="expenses-table"]',
    title: '查看支出列表',
    description:
      '建立完成的支出會顯示在列表上，可依來源、類別、日期、付款狀態篩選。',
  },
  {
    routeName: 'admin-records',
    selector: '[data-tour="records-table"]',
    title: '查看請款記錄',
    description:
      '顯示所有員工代墊款，可依狀態、日期、關鍵字篩選。',
  },
  {
    routeName: 'admin-review',
    selector: '[data-tour="review-queue"]',
    title: '簽核代墊款',
    description: '待簽核的代墊款會列在簽核列表，可以逐筆或批次通過/退回；通過後 Quickey 會自動建立對應支出。',
    scrollToRight: true,
  },
  {
    routeName: 'admin-categories',
    selector: '[data-tour="categories-add-button"]',
    title: '設定費用類別',
    description:
      'Quickey 內建 13 個常見會計科目起始資料，你可以新增、修改或停用類別。',
  },
  {
    routeName: 'admin-budgets',
    selector: '[data-tour="budgets-page"]',
    title: '建立第一筆預算',
    description:
      '為每個類別設定月/年預算，Quickey 會自動計算執行率並在超支時提示。',
    // 頁面較高（PageHeader + 週期切換 + 表格），用 'start' 讓標題對齊 viewport
    // 頂部，避免 driver.js center-scroll 把 PageHeader 推到 viewport 上方
    scrollBlock: 'start',
  },
  {
    routeName: 'admin-users',
    selector: '[data-tour="users-invite-button"]',
    title: '邀請員工',
    description:
      '透過 Email 邀請員工加入公司，員工自行設定密碼後就能開始送出代墊款。',
  },
  {
    routeName: 'admin-dashboard',
    selector: '[data-tour="dashboard-overview"]',
    title: '儀表板',
    description:
      '儀表板呈現公司支出概況與預算執行率，可以從這裡快速掌握財務狀況。',
    // 涵蓋 KPI + 兩張圖表；區塊高於 viewport，用 'start' 讓「本月支出/未結清代墊款」對齊 viewport 頂部
    scrollBlock: 'start',
  },
  {
    routeName: 'admin-dashboard',
    selector: '.tour-onboarding-item',
    title: '新手導覽',
    description:
      '隨時可以從右上角選單「新手導覽」重新開始導覽。',
    // route 不變，preAction 打開右上角 UserBadge popup 讓「新手導覽」項目顯現
    preAction: () => useOnboardingStore().setUserMenuOpen(true),
  },
]

const EMPLOYEE_STEPS: TourStep[] = [
  {
    routeName: 'front-new',
    selector: '[data-tour="expense-upload-area"]',
    title: '歡迎使用 Quickey',
    description:
      '接下來 4 步會帶你走過代墊款請款流程，隨時可點擊右上角結束導覽。<br>第一步：拍下或上傳發票收據，Quickey 會自動辨識金額、廠商、明細等內容，或可以手動輸入內容。',
    // 目標本身緊接 PageHeader 下方，'start' / 'center' 都會把頁面往下捲，反而
    // 讓 PageHeader 消失、視覺焦點落到下面欄位。用 'nearest' 只在元素離開
    // viewport 時才捲，避免無謂下捲。
    scrollBlock: 'nearest',
  },
  {
    routeName: 'front-history',
    selector: '[data-tour="history-table"]',
    title: '追蹤代墊款進度',
    description: '所有已送出的代墊款列在這裡，可即時看到簽核狀態與撥款進度；也可以編輯草稿或撤回簽核。',
  },
  {
    routeName: 'front-home',
    selector: '[data-tour="home-welcome"]',
    title: '首頁一覽',
    description:
      '首頁呈現待收款、已發放金額及最近請款紀錄，讓你快速掌握代墊款狀態。',
    scrollBlock: 'start',
  },
  {
    routeName: 'front-home',
    selector: '.tour-onboarding-item',
    title: '新手導覽',
    description:
      '隨時可以從右上角選單「新手導覽」重新開始導覽。',
    preAction: () => useOnboardingStore().setUserMenuOpen(true),
  },
]

let driverInstance: Driver | null = null

/**
 * 把 target（或它內部第一個可 scroll 的 descendant）水平 smooth-scroll 到最右。
 * 供簽核步在手機/平板下把「操作」欄的行動按鈕帶進 viewport。
 * 若 target 本身可 scroll 就直接用，否則往下找 div/section/table 找第一個
 * scrollWidth > clientWidth 的元素（PrimeVue DataTable 內部 wrapper 也吃）。
 */
function scrollTargetToRight(el: HTMLElement): void {
  const candidates: HTMLElement[] = [el]
  el.querySelectorAll<HTMLElement>('div, section, table').forEach((d) =>
    candidates.push(d),
  )
  for (const c of candidates) {
    if (c.scrollWidth > c.clientWidth) {
      c.scrollTo({ left: c.scrollWidth - c.clientWidth, behavior: 'smooth' })
      return
    }
  }
}

/**
 * Polling 找 selector 對應的 DOM 元素，每 50ms 試一次。逾時仍找不到 return null；
 * 找到但 display:none（offsetParent === null）仍回傳，讓 caller 決定 fallback。
 */
async function waitForSelector(
  selector: string,
  timeoutMs: number,
): Promise<Element | null> {
  const startAt = Date.now()
  while (Date.now() - startAt < timeoutMs) {
    const el = document.querySelector(selector)
    if (el instanceof HTMLElement && el.offsetParent !== null) {
      return el
    }
    await new Promise((r) => setTimeout(r, 50))
  }
  return document.querySelector(selector)
}

/**
 * 前進到指定 step：切 route → 等 target → scroll 至中央 → 等 smooth scroll 完成。
 * 回傳 target 元素供 caller 判斷是否 fallback 到 center tooltip。
 */
async function transitionToStep(
  router: Router,
  step: TourStep,
): Promise<HTMLElement | null> {
  if (router.currentRoute.value.name !== step.routeName) {
    await router.push({ name: step.routeName })
  }
  if (step.preAction) {
    await step.preAction()
  }
  const target = await waitForSelector(step.selector, 500)
  if (target instanceof HTMLElement && target.offsetParent !== null) {
    target.scrollIntoView({
      block: step.scrollBlock ?? 'center',
      behavior: 'smooth',
    })
    // 縱向 scroll 的同時觸發橫向 scroll，兩軸並行動畫；避免 driver.js
    // highlight 貼上後才 scroll 造成 ~1s 延遲的 UX（見使用者回饋）。
    if (step.scrollToRight && window.innerWidth < 1024) {
      scrollTargetToRight(target)
    }
    await new Promise((r) => setTimeout(r, 300))
    return target
  }
  return null
}

export function useOnboardingTour() {
  const router = useRouter()
  const auth = useAuthStore()
  const onboarding = useOnboardingStore()

  function pickSteps(): TourStep[] {
    if (auth.role === 'admin') return ADMIN_STEPS
    if (auth.role === 'employee') return EMPLOYEE_STEPS
    return []
  }

  function buildDriveSteps(steps: TourStep[]): DriveStep[] {
    return steps.map((s, i) => ({
      element: s.selector,
      popover: {
        title: s.title,
        description: s.description,
        // 不指定 side/align 讓 driver.js 依 viewport 自動選方向（見 Decision 6）
        progressText: `第 ${i + 1} 步 / 共 ${steps.length} 步`,
      },
    }))
  }

  async function startTour() {
    const steps = pickSteps()
    if (steps.length === 0) return

    // 避免同時多實例：先清掉舊 driver
    if (driverInstance) {
      driverInstance.destroy()
      driverInstance = null
    }

    // 先把第一步的 target 準備好（scroll into view 等）再啟動 driver
    await transitionToStep(router, steps[0])

    driverInstance = driver({
      steps: buildDriveSteps(steps),
      showProgress: true,
      allowClose: true,
      allowKeyboardControl: true,
      disableActiveInteraction: true,
      // 點遮罩不關閉（見 spec Requirement 4）：使用者可能為了瀏覽被打亮的元素
      // 而點旁邊，關閉會顯得意外。只能透過右上角「結束導覽」或 Esc 主動結束。
      overlayClickBehavior: () => {
        /* no-op — 點遮罩不關閉 */
      },
      popoverClass: 'quickey-tour-popover',
      doneBtnText: '完成',
      nextBtnText: '下一步',
      prevBtnText: '上一步',
      // 每次 popover render 把 X icon 換成「結束導覽」文字按鈕
      onPopoverRender: (popover) => {
        popover.closeButton.textContent = '結束導覽'
      },
      // 每步 highlight 開始時同步打亮左側選單對應項目：透過 Pinia state
      // 供 AdminLayout 用 :class 反應式綁定 .tour-nav-active（比依賴
      // data-tour-nav attribute 更穩，不受 RouterLink attr fall-through 行為
      // 影響）。桌機才看得到，手機 sidebar 藏在 drawer 內不受影響。
      onHighlightStarted: (_el, _step, opts) => {
        const idx = opts.state.activeIndex ?? 0
        const s = steps[idx]
        if (s) {
          onboarding.setActiveSidebar(s.sidebarRouteName ?? s.routeName)
        }
      },
      // driver.js 內部會自己 center-scroll target。若 scrollBlock !== 'center'
      // 在 driver 動作結束後覆蓋一次，讓頂部對齊 viewport（例如儀表板尾步）。
      // scrollToRight 已在 transitionToStep 中跟 vertical scroll 同步觸發，
      // 不放這裡以免累積延遲影響 UX。
      onHighlighted: (el, _step, opts) => {
        const idx = opts.state.activeIndex ?? 0
        const s = steps[idx]
        if (!s || !(el instanceof HTMLElement)) return
        if (s.scrollBlock && s.scrollBlock !== 'center') {
          setTimeout(() => {
            el.scrollIntoView({ block: s.scrollBlock!, behavior: 'smooth' })
          }, 350)
        }
      },
      onNextClick: async (_el, _step, opts) => {
        const currentIndex = opts.state.activeIndex ?? 0
        const nextIndex = currentIndex + 1
        if (nextIndex >= steps.length) {
          // 最後一步 → 直接 destroy 觸發 onDestroyed
          opts.driver.destroy()
          return
        }
        await transitionToStep(router, steps[nextIndex])
        opts.driver.moveNext()
      },
      // 對稱 onNextClick：上一步同樣要先切 route + 等 target，否則會停在現在
      // 這頁找 prev step 的 selector，找不到 fallback 到中央 tooltip
      // 且無 highlight（見 spec Requirement 3 反向邏輯）。
      // 若當前步曾透過 preAction 打開 UserBadge 選單（尾步「新手導覽」），
      // 退回上一步前先關閉，避免選單 popup 蓋在下一目標上。
      onPrevClick: async (_el, _step, opts) => {
        const currentIndex = opts.state.activeIndex ?? 0
        const prevIndex = currentIndex - 1
        if (prevIndex < 0) return
        if (steps[currentIndex]?.preAction) {
          onboarding.setUserMenuOpen(false)
        }
        await transitionToStep(router, steps[prevIndex])
        opts.driver.movePrevious()
      },
      onDestroyed: () => {
        onboarding.setActiveSidebar(null)
        onboarding.setUserMenuOpen(false)
        driverInstance = null
        if (auth.currentUser) {
          onboarding.markCompleted()
        }
      },
    })

    // 第一步的 sidebar highlight 需在 drive() 前先掛（onHighlightStarted 也會
    // 對第一步 fire，但用戶端瞬間看到 sidebar 沒亮再亮起，體驗較差）
    onboarding.setActiveSidebar(
      steps[0].sidebarRouteName ?? steps[0].routeName,
    )
    driverInstance.drive()
  }

  /**
   * 目前是否有 tour 正在跑（driver 實例存在）。DashboardView.onMounted 用來
   * 避免 step 9 → 10 (users → dashboard) 路由切換時 remount 重覆觸發 startTour，
   * 否則會產生兩層遮罩 + 兩個 popover + step 10 fallback 到中央 tooltip。
   */
  function isActive(): boolean {
    return driverInstance !== null
  }

  return { startTour, isActive }
}
