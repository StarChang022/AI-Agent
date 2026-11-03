module Import
  class Base
    include ActiveModel::Model
    attr_accessor :file

    def initialize(attributes = {})
      super
    end

    def header
      %w[]
    end

    def data
      @data = []
      sheet.each_row_streaming(offset: offset) do |current|
        @current_data = current.inject([]) do |array, i|
          value = i.value.is_a?(Roo::Link) ? i.value.to_s : i.value
          array.insert((i.coordinate.column - 1), value)
        end

        @hash_data = header.each_with_index.map { |obj, index| [obj, @current_data[index]] }.to_h
        @hash_data.delete(nil)

        @data << @hash_data if @current_data.compact.present?
      end
      return @data
    end

    def offset
      1
    end

    def sheet
      require 'uri'
      @url = file
      # @sheet = Roo::Spreadsheet.open(@url, extension: file.filename.extension.to_sym)
      @sheet = Roo::Spreadsheet.open(@url, extension: :xlsx)
    end
  end
end
