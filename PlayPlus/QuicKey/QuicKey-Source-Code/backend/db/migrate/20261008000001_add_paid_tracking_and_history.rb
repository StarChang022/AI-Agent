class AddPaidTrackingAndHistory < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :paid_at, :date
    add_reference :expenses, :paid_by, type: :uuid, foreign_key: { to_table: :users }, index: true

    add_column :reimbursements, :paid_at, :date
    add_reference :reimbursements, :paid_by, type: :uuid, foreign_key: { to_table: :users }, index: true
    add_column :reimbursements, :history, :jsonb, default: [], null: false
  end
end
