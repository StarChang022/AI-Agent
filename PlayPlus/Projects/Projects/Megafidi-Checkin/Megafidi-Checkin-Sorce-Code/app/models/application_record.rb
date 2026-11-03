class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  
  self.abstract_class = true

  acts_as_paranoid

  include ActsAsDefaultValue
  include EnumAttributeLocalizable

  # 多圖範例
  #has_many :images, as: :item
  #accepts_nested_attributes_for :images, allow_destroy: true, reject_if: :all_blank

  def self.form_columns_hash remove_columns = nil
    remove_columns ||= ["id", "slug", "status", "deleted_at", "created_at", "updated_at"]
    @form_columns_hash = self.columns_hash.dup
    @form_columns_hash = @form_columns_hash.map{|k, v| [k, v.type]}.to_h.except(*remove_columns)
  end

  def self.v_search params = {}
    @_self = self.all
    params = params.symbolize_keys

    if params[:bulk_ids].present?
      @_self = @_self.where(id: params[:bulk_ids])
    end

    if params[:q].present?
      @_self = @_self.ransack(params[:q])
      @_self = @_self.result(distinct: true)
    end

    if params[:daterange].present?
      @start_at = params[:daterange].split("-")[0].to_date.beginning_of_day
      @end_at = params[:daterange].split("-")[1].to_date.end_of_day
      @_self = @_self.between_times(@start_at, @end_at)
    end

    if params[:k].present?
      sql_string = column_names.map{|i| "(#{table_name}.#{i} LIKE :k)"}.join(" OR ")

      @_self = @_self.where(sql_string, :k => "%#{params[:k]}%")
    end

    self.column_names.each do |key|
      next if %w[id priority].include?(key.to_s)

      if params[key.to_sym].present?
        _value = params[key.to_sym]
        if _value.kind_of?(Array)
          _value.compact_blank!
        end

        @_self = @_self.where(key.to_sym => _value) if _value.present?
      end
    end

    self.try(:acts_as_taggable_on).each do |current|
      current = current.to_sym
      next unless params.dig(current)
      @_self = @_self.tagged_with(params.dig(current), on: current, any: true)
    end if self.try(:acts_as_taggable_on)

    @_self.all
  end

  def self.nested_attributes
    @nested_attributes = column_names.dup
    @nested_attributes.push("_destroy")
  end

  def self.clean
    require 'database_cleaner'
    DatabaseCleaner.strategy = :truncation, {:only => [self.table_name]}
    DatabaseCleaner.clean
  end

  def self.clean_rich_text
    require 'database_cleaner'
    DatabaseCleaner.strategy = :truncation, {:only => [:action_text_rich_texts]}
    DatabaseCleaner.clean
  end

end
