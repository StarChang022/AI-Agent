# == Schema Information
#
# Table name: system_settings
#
#  id                :integer          not null, primary key
#  address           :string
#  deleted_at        :datetime
#  email             :string
#  line_notify_token :string
#  name              :string
#  phone             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class SystemSetting < ApplicationRecord

  store :socials, accessors: []

  include Seo

  before_validation :line_notify_validation

  def line_notify_validation
    if line_notify_token_changed? && line_notify_token.present?
      @line_notify_testing = line_notify_testing
      unless @line_notify_testing.status == 200
        errors.add(:line_notify_token, @line_notify_testing.res_message)
      end
    end
  end

  def line_notify_testing
    line_notify = Line::Notify::Client.new(token: line_notify_token, message: "#{name}測試訊息")
    line_notify.run

    return line_notify
  end

end
