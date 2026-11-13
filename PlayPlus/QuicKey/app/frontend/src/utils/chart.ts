/**
 * 圖表共用設定。
 * 類別色盤：16 色，依類別排序（sortOrder）循環套用，新增類別也一定有顏色。
 */
export const CATEGORY_COLOR_PALETTE = [
  '#f2c66d', '#f0b75e', '#e7d86a', '#b8d96f', '#82cd73', '#62cfa5', '#5ecdc7', '#67bddf',
  '#6fa8df', '#84a2d8', '#a7b7c7', '#7fb8c8', '#f4a95e', '#d9cb66', '#7fcf8f', '#6cb7d8',
]

export function categoryColor(sortOrder: number): string {
  const n = CATEGORY_COLOR_PALETTE.length
  return CATEGORY_COLOR_PALETTE[((sortOrder % n) + n) % n]
}
