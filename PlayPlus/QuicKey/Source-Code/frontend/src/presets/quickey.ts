import { definePreset } from '@primeuix/themes'
import Aura from '@primeuix/themes/aura'

/**
 * Quickey preset — PrimeVue Aura 對齊 Quickey Design System（design-system/）。
 *
 * - 主色：品牌綠 #00B39F（primary-500，取自 Logo）；按鈕、文字、選取狀態用 primary-700
 *   (#008072) 當「實色」，確保白字與白底上的對比度。
 * - 表單欄位：高 44px、圓角 16px（radius-control）、1.5px 邊框（styles/index.css）。
 * - 按鈕：膠囊形、高 44px；小尺寸同為 44px（styles/index.css）。
 * 數值與 styles/index.css 的 @theme tokens 一一對應，改色時兩邊一起改。
 */
export const Quickey = definePreset(Aura, {
  semantic: {
    primary: {
      50: '#edfaf8',
      100: '#d1f1ee',
      200: '#8cddd4',
      300: '#58cdc0',
      400: '#2abfaf',
      500: '#00b39f',
      600: '#019181',
      700: '#008072',
      800: '#035a50',
      900: '#053f38',
      950: '#062a25',
    },
    // 下拉選單（Select / MultiSelect / AutoComplete）的彈出面板與輸入框同為 16px；
    // 選項 12px = 16px 外框 − 4px 內距，視覺上同心
    overlay: {
      select: {
        borderRadius: '16px',
      },
    },
    list: {
      option: {
        borderRadius: '12px',
      },
    },
    formField: {
      borderRadius: '16px',
      paddingX: '14px',
      paddingY: '11px',
    },
    colorScheme: {
      light: {
        primary: {
          color: '{primary.700}',
          contrastColor: '#ffffff',
          hoverColor: '{primary.800}',
          activeColor: '{primary.900}',
        },
        highlight: {
          background: '{primary.50}',
          focusBackground: '{primary.100}',
          color: '{primary.700}',
          focusColor: '{primary.800}',
        },
        formField: {
          borderColor: '#e3e6ec', // --color-hairline
          hoverBorderColor: '#c9cedd', // --color-hairline-strong
          focusBorderColor: '{primary.700}',
          placeholderColor: '#a6acb8', // --color-muted-soft
          color: '#2a3140', // --color-ink
        },
        // PrimeVue 預設文字色（Dialog 標題、Menu、Popover 等）對齊 Quickey 文字色階
        text: {
          color: '#2a3140', // --color-ink
          hoverColor: '#2a3140',
          mutedColor: '#646d80', // --color-muted
          hoverMutedColor: '#485266', // --color-slate
        },
      },
    },
  },
  components: {
    button: {
      root: {
        borderRadius: '9999px',
        paddingX: '20px',
        paddingY: '0',
        gap: '6px',
        label: {
          fontWeight: '600',
        },
        sm: {
          fontSize: '13px',
          paddingX: '14px',
          paddingY: '0',
        },
      },
    },
    datatable: {
      headerCell: {
        background: '#f4f5f8', // --color-surface
        color: '#485266', // --color-slate
        borderColor: '#e3e6ec',
        padding: '12px 16px',
      },
      bodyCell: {
        borderColor: '#e3e6ec',
        padding: '14px 16px',
      },
      row: {
        hoverBackground: '#eef1f5', // --color-surface-soft
      },
    },
    datepicker: {
      panel: {
        borderRadius: '16px',
      },
    },
    dialog: {
      root: {
        borderRadius: '20px',
      },
    },
    tabs: {
      tab: {
        padding: '0 0 12px 0',
        fontWeight: '500',
      },
    },
  },
})
