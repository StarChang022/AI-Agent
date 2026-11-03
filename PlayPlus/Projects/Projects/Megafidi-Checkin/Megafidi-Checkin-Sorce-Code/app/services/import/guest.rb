# frozen_string_literal: true

# Import::Guest.new.run
module Import
  class Guest < Base
    attr_accessor :errors

    def initialize(attributes = {})
      super
      @errors = []
    end

    def run
      data.each do |guest|
        @guest = ::Guest.new(
          guest,
        )

        unless @guest.save
          @errors << @guest.errors.full_messages
        end
      end
      @errors
    end

    def xlsx
      require 'uri'
      @file = 'guests.xlsx'
      @url = Rails.root.join('data', @file)
      # @sheet = Roo::Spreadsheet.open(@url, extension: file.filename.extension.to_sym)
      @sheet = Roo::Spreadsheet.open(@url, extension: :xlsx)
    end

    def sheets
      @sheets = xlsx.sheets
    end

    def data
      @data = []
      sheets.each_with_index do |_sheet, index|
        v_sheet = xlsx.sheet(index)
        v_sheet.each(
          trophy_num: '獎盃編號',
          name: '姓名',
          phone: '手機號碼',
          company_name: '公司名稱',
          department_name: '單位名稱',
          certificate_num: '登錄證字號',
          behalf: '代領獎人',
          special: '貴賓',
          activity_name: '參加場次',
        ) do |hash|
          next if hash[:trophy_num] == '獎盃編號'

          hash[:trophy_num] = hash[:trophy_num].to_i
          hash[:activity_id] = find_activity_id(hash.delete(:activity_name))
          @data << hash
        end
      end

      @data
    end

    def find_activity_id(name)
      @activity = ::Activity.find_or_create_by(name: name).id
    end
  end
end
