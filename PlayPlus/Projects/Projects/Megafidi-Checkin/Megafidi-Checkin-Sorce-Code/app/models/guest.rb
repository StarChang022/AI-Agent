# == Schema Information
#
# Table name: guests
#
#  id                :integer          not null, primary key
#  behalf            :string
#  certificate_num   :string
#  company_name      :string
#  deleted_at        :datetime
#  department_name   :string
#  name              :string
#  note              :text
#  phone             :string
#  registration_time :datetime
#  special           :boolean          default(FALSE)
#  status            :integer
#  trophy_num        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  activity_id       :integer
#
# Indexes
#
#  index_guests_on_activity_id  (activity_id)
#
class Guest < ApplicationRecord
  belongs_to :activity, optional: true
  delegate :name, :date, to: :activity, prefix: true, allow_nil: true

  enum status: {
    waiting: 0,
    registrated: 1,
  }
  include EnumName
  include AASM

  aasm(:status, enum: true) do
    state :waiting, initial: true
    state :registrated

    event :registrate do
      transitions from: [:waiting], to: :registrated
      after do
        update_columns(registration_time: Time.current)
      end
    end

    event :cancel do
      transitions from: [:registrated], to: :waiting
      after do
        update_columns(registration_time: nil)
      end
    end
  end

  def self.v_search(params = {})
    @_self = all
    params = params.symbolize_keys

    if params[:bulk_ids].present?
      @_self = @_self.where(id: params[:bulk_ids])
    end

    if params[:q].present?
      @_self = @_self.ransack(params[:q])
      @_self = @_self.result(distinct: true)
    end

    if params[:daterange].present?
      @start_at = params[:daterange].split('-')[0].to_date.beginning_of_day
      @end_at = params[:daterange].split('-')[1].to_date.end_of_day
      @_self = @_self.between_times(@start_at, @end_at)
    end

    if params[:k].present?
      sql_string = column_names.map { |i| "(#{table_name}.#{i} LIKE :k)" }.join(' OR ')

      @_self = @_self.where(sql_string, k: "%#{params[:k]}%")
    end

    if params[:phone_keyword].present?
      @_self = @_self.where('SUBSTRING(phone, LENGTH(phone) - 4, 5) = ?', params[:phone_keyword])
    end

    column_names.each do |key|
      next if %w[id priority].include?(key.to_s)

      next unless params[key.to_sym].present?

      _value = params[key.to_sym]
      if _value.is_a?(Array)
        _value.compact_blank!
      end

      @_self = @_self.where(key.to_sym => _value) if _value.present?
    end

    @_self.all
  end
end
