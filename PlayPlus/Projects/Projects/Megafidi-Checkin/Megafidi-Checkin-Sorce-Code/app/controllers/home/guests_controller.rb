# frozen_string_literal: true

module Home
  class GuestsController < ResourcesController
    def index
      @new = true if @new != false
      @xlsx = false

      respond_to do |format|
        format.xlsx do
          @current_collection = default_scope.reorder(activity_id: :asc, trophy_num: :asc)
          package = Axlsx::Package.new
          workbook = package.workbook
          workbook.add_worksheet(name: '全部') do |sheet|
            sheet.add_row %w[
              獎盃編號
              姓名
              手機號碼
              公司名稱
              單位名稱
              登錄證字號
              代領獎人
              貴賓
              參加場次
              報到時間
              備註
            ]

            # 假設 @data 是從某處獲取的數據
            @current_collection.each do |row|
              sheet.add_row [
                row.trophy_num,
                row.name,
                row.phone,
                row.company_name,
                row.department_name,
                row.certificate_num,
                row.behalf,
                row[:special],
                row.activity_name, # 這裡應該是 activity_id 對應的名稱
                row.registration_time&.strftime('%F %R'),
                row.note,
              ], types: %i[string string string string string string string string string string string]
            end
          end

          # 使用 send_data 發送文件
          send_data package.to_stream.read, filename: 'trophy_data.xlsx',
                                            type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          # render filename: "#{model_class.model_name.human}.xlsx", xlsx: 'index'
        end
        format.html do
        end
      end
    end

    def show; end
  end

  private

  def download_excel(_data)
    package = Axlsx::Package.new
    workbook = package.workbook
    workbook.add_worksheet(name: '全部') do |sheet|
      sheet.add_row %w[
        獎盃編號
        姓名
        手機號碼
        公司名稱
        單位名稱
        登錄證字號
        代領獎人
        貴賓
        參加場次
        報到時間
        備註
      ]

      # 假設 @data 是從某處獲取的數據
      @current_collection.each do |row|
        sheet.add_row [
          row.trophy_num,
          row.name,
          row.phone,
          row.company_name,
          row.department_name,
          row.certificate_num,
          row.behalf,
          (row[:special] ? '✔' : '✘'),
          row.activity_name, # 這裡應該是 activity_id 對應的名稱
          row.registration_time.strftime('%F %R'),
          row.note,
        ], types: %i[string string string string string string string string string string string]
      end
    end

    # 使用 send_data 發送文件
    send_data package.to_stream.read, filename: 'trophy_data.xlsx',
                                      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  end
end
