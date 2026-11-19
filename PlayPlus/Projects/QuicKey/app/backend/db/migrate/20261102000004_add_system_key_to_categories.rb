# 系統保留類別（docs/資料模型.md §3.4）。既有公司補上手續費類別：已有同名支出類別就沿用，
# 停用中或在垃圾桶的恢復為使用中，沒有則新增。這是系統動作，不寫稽核日誌。
class AddSystemKeyToCategories < ActiveRecord::Migration[8.1]
  SYSTEM_KEY = "transfer_fee".freeze
  FEE_NAME   = "手續費".freeze
  FEE_CODE   = "6131".freeze

  def up
    add_column :categories, :system_key, :string
    add_index :categories, [ :company_id, :system_key ], unique: true, where: "system_key IS NOT NULL"
    backfill
  end

  def down
    remove_index :categories, [ :company_id, :system_key ]
    remove_column :categories, :system_key
  end

  # 同名有多筆時，優先用使用中的。
  def backfill
    key  = connection.quote(SYSTEM_KEY)
    name = connection.quote(FEE_NAME)
    code = connection.quote(FEE_CODE)

    execute <<~SQL.squish
      UPDATE categories SET system_key = #{key}, is_archived = FALSE, deleted_at = NULL, updated_at = now()
      WHERE id IN (
        SELECT DISTINCT ON (company_id) id FROM categories
        WHERE kind = 'expense' AND LOWER(name) = LOWER(#{name})
        ORDER BY company_id, deleted_at IS NOT NULL, is_archived, created_at
      )
    SQL
    execute <<~SQL.squish
      INSERT INTO categories (company_id, kind, name, account_code, sort_order, system_key, created_at, updated_at)
      SELECT companies.id, 'expense', #{name}, #{code},
             COALESCE((SELECT MAX(c.sort_order) + 1 FROM categories c WHERE c.company_id = companies.id AND c.kind = 'expense'), 0),
             #{key}, now(), now()
      FROM companies
      WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.company_id = companies.id AND c.system_key = #{key})
    SQL
  end
end
