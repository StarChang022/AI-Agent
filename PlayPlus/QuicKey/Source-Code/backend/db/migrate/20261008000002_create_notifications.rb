class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :user,    type: :uuid, null: false, foreign_key: true
      t.string  :kind,    null: false
      t.jsonb   :payload, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, [ :user_id, :read_at ]
  end
end
