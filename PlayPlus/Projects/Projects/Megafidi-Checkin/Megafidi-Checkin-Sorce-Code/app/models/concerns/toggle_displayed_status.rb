module ToggleDisplayedStatus
  extend ActiveSupport::Concern
  included do
    enum status: {
      hidden: 0,
      displayed: 1,
    }

    include AASM
    aasm(:status, :enum => true) do
      state :hidden,initial: true
      state :displayed

      event :show do
        transitions from: [:hidden], to: :displayed
      end

      event :hide do
        transitions from: [:displayed], to: :hidden
      end

    end
  end
end