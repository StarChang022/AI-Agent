# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_user_id", null: false
    t.jsonb "after"
    t.jsonb "before"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "target_id", null: false
    t.string "target_type", null: false
    t.index ["actor_user_id"], name: "index_audit_logs_on_actor_user_id"
    t.index ["company_id", "created_at"], name: "index_audit_logs_on_company_id_and_created_at", order: { created_at: :desc }
    t.index ["company_id"], name: "index_audit_logs_on_company_id"
    t.index ["target_type", "target_id", "created_at"], name: "index_audit_logs_on_target_type_and_target_id_and_created_at", order: { created_at: :desc }
  end

  create_table "budget_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.uuid "category_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "cycle", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budget_templates_on_category_id"
    t.index ["company_id", "category_id", "cycle"], name: "index_budget_templates_on_company_category_cycle", unique: true
    t.index ["company_id"], name: "index_budget_templates_on_company_id"
  end

  create_table "budgets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.uuid "category_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "cycle", null: false
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["company_id", "category_id", "cycle", "period_start"], name: "index_budgets_on_company_category_cycle_period_start", unique: true
    t.index ["company_id"], name: "index_budgets_on_company_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_code", default: "", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_archived", default: false, null: false
    t.string "kind", default: "expense", null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "is_archived"], name: "index_categories_on_company_id_and_is_archived"
    t.index ["company_id", "kind"], name: "index_categories_on_company_id_and_kind"
    t.index ["company_id", "sort_order"], name: "index_categories_on_company_id_and_sort_order"
    t.index ["company_id"], name: "index_categories_on_company_id"
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "company_type", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "ocr_monthly_quota", default: 50, null: false
    t.integer "ocr_monthly_used", default: 0, null: false
    t.integer "ocr_purchased_remaining", default: 0, null: false
    t.datetime "ocr_quota_reset_at", default: -> { "(((date_trunc('month'::text, (now() AT TIME ZONE 'Asia/Taipei'::text)) + 'P1M'::interval) AT TIME ZONE 'Asia/Taipei'::text) AT TIME ZONE 'UTC'::text)" }, null: false
    t.integer "payout_day", default: 5
    t.string "plan", default: "free", null: false
    t.string "tax_id"
    t.datetime "updated_at", null: false
  end

  create_table "expenses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.jsonb "attachments", default: [], null: false
    t.date "auto_planned_payout_date"
    t.uuid "category_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.date "date", null: false
    t.datetime "deleted_at"
    t.string "document_type", null: false
    t.string "invoice_no"
    t.jsonb "items", default: [], null: false
    t.text "note"
    t.date "paid_at"
    t.uuid "paid_by_id"
    t.string "payout_status", default: "pending", null: false
    t.date "planned_payout_date"
    t.boolean "planned_payout_manual", default: false, null: false
    t.decimal "pre_tax_amt", precision: 12, scale: 2
    t.string "source", default: "general", null: false
    t.uuid "source_ref_id"
    t.decimal "tax_amt", precision: 12, scale: 2
    t.string "tax_id"
    t.string "tax_rate", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["company_id", "date"], name: "index_expenses_on_company_id_and_date"
    t.index ["company_id", "payout_status"], name: "index_expenses_on_company_id_and_payout_status"
    t.index ["company_id", "source"], name: "index_expenses_on_company_id_and_source"
    t.index ["company_id"], name: "index_expenses_on_company_id"
    t.index ["created_by_id"], name: "index_expenses_on_created_by_id"
    t.index ["deleted_at"], name: "index_expenses_on_deleted_at"
    t.index ["paid_by_id"], name: "index_expenses_on_paid_by_id"
    t.index ["source_ref_id"], name: "index_expenses_on_source_ref_id"
  end

  create_table "incomes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.jsonb "attachments", default: [], null: false
    t.uuid "category_id", null: false
    t.date "collected_at"
    t.string "collection_status", default: "uncollected", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.string "customer", null: false
    t.date "date", null: false
    t.datetime "deleted_at"
    t.string "document_type", null: false
    t.string "invoice_no"
    t.jsonb "items", default: [], null: false
    t.text "note"
    t.decimal "pre_tax_amt", precision: 12, scale: 2
    t.decimal "tax_amt", precision: 12, scale: 2
    t.string "tax_id"
    t.string "tax_rate", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_incomes_on_category_id"
    t.index ["company_id", "collection_status"], name: "index_incomes_on_company_id_and_collection_status"
    t.index ["company_id", "date"], name: "index_incomes_on_company_id_and_date"
    t.index ["company_id"], name: "index_incomes_on_company_id"
    t.index ["created_by_id"], name: "index_incomes_on_created_by_id"
    t.index ["deleted_at"], name: "index_incomes_on_deleted_at"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.uuid "invited_by_id"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email"], name: "index_invitations_on_company_id_and_email"
    t.index ["company_id"], name: "index_invitations_on_company_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["company_id"], name: "index_notifications_on_company_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "password_reset_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.uuid "user_id", null: false
    t.index ["token_digest"], name: "index_password_reset_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "payout_day_change_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.uuid "changed_by_id", null: false
    t.uuid "company_id", null: false
    t.integer "from_day"
    t.integer "to_day"
    t.index ["changed_by_id"], name: "index_payout_day_change_logs_on_changed_by_id"
    t.index ["company_id", "changed_at"], name: "index_payout_day_change_logs_on_company_id_and_changed_at"
    t.index ["company_id"], name: "index_payout_day_change_logs_on_company_id"
  end

  create_table "reimbursements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.jsonb "approval_progress"
    t.uuid "category_id", null: false
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "document_type", null: false
    t.uuid "employee_id", null: false
    t.uuid "expense_id"
    t.jsonb "history", default: [], null: false
    t.date "incurred_at", null: false
    t.string "invoice_no"
    t.date "paid_at"
    t.uuid "paid_by_id"
    t.string "payment_method"
    t.decimal "pre_tax_amt", precision: 12, scale: 2
    t.string "receipt_names", default: [], null: false, array: true
    t.string "receipt_urls", default: [], null: false, array: true
    t.string "status", default: "draft", null: false
    t.decimal "tax_amt", precision: 12, scale: 2
    t.string "tax_id"
    t.string "tax_rate", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.integer "version", default: 1, null: false
    t.index ["category_id"], name: "index_reimbursements_on_category_id"
    t.index ["company_id", "status"], name: "index_reimbursements_on_company_id_and_status"
    t.index ["company_id"], name: "index_reimbursements_on_company_id"
    t.index ["employee_id", "status"], name: "index_reimbursements_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_reimbursements_on_employee_id"
    t.index ["paid_by_id"], name: "index_reimbursements_on_paid_by_id"
  end

  create_table "signup_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "company_name"
    t.string "company_type"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.string "password_digest"
    t.string "provider", default: "email", null: false
    t.string "tax_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["email"], name: "index_signup_tokens_on_email"
    t.index ["token_digest"], name: "index_signup_tokens_on_token_digest", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_login_at"
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.string "password_digest"
    t.string "role", default: "employee", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "audit_logs", "companies"
  add_foreign_key "audit_logs", "users", column: "actor_user_id"
  add_foreign_key "budget_templates", "categories"
  add_foreign_key "budget_templates", "companies"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "companies"
  add_foreign_key "categories", "companies"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "companies"
  add_foreign_key "expenses", "reimbursements", column: "source_ref_id"
  add_foreign_key "expenses", "users", column: "created_by_id"
  add_foreign_key "expenses", "users", column: "paid_by_id"
  add_foreign_key "incomes", "categories"
  add_foreign_key "incomes", "companies"
  add_foreign_key "incomes", "users", column: "created_by_id"
  add_foreign_key "invitations", "companies"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "notifications", "companies"
  add_foreign_key "notifications", "users"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "payout_day_change_logs", "companies"
  add_foreign_key "payout_day_change_logs", "users", column: "changed_by_id"
  add_foreign_key "reimbursements", "categories"
  add_foreign_key "reimbursements", "companies"
  add_foreign_key "reimbursements", "expenses"
  add_foreign_key "reimbursements", "users", column: "employee_id"
  add_foreign_key "reimbursements", "users", column: "paid_by_id"
  add_foreign_key "users", "companies"
end
