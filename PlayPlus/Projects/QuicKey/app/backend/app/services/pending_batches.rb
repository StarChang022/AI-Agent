module PendingBatches
  # 待付款／待收款依應付／應收日期分組（PRD 第 23 條、docs/資料模型.md §六）。支出、收入共用。
  # 逾期（日期早於公司時區今天；當天不算）合併成一組排最前面，其餘依日期由近到遠。
  # 每組回 key、date、overdue、total、count，加上呼叫端 block 回傳的欄位（例如 rows）。
  # overdue 組的 key 為 "0000-overdue"、date 為組內最早的日期。
  OVERDUE_KEY = "0000-overdue".freeze

  def self.group(records, date_of:, today: Date.current)
    overdue, upcoming = records.partition { |r| date_of.call(r) < today }

    groups = []
    groups << build(OVERDUE_KEY, overdue.map(&date_of).min, overdue, true) { |rows| yield rows } if overdue.any?
    upcoming.group_by(&date_of).sort_by(&:first).each do |date, rows|
      groups << build(date.iso8601, date, rows, false) { |r| yield r }
    end
    groups
  end

  def self.build(key, date, rows, overdue)
    {
      key:     key,
      date:    date.iso8601,
      overdue: overdue,
      total:   rows.sum(&:amount).to_f,
      count:   rows.size
    }.merge(yield(rows))
  end
  private_class_method :build
end
