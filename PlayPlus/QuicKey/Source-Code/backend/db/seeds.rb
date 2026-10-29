# Dev-only seed：對齊 frontend/src/mocks/users.json 的測試帳號，
# 方便前端 Stage C 串接時同一組帳號能登入。
#
# 只在 development 環境跑；測試站需要時手動執行：
#   docker compose -f compose.prod.yml exec -T -e SEED_DEMO_DATA=1 backend bin/rails db:seed
# 正式站另有註冊流程，不 seed 使用者。
return unless Rails.env.development? || ENV["SEED_DEMO_DATA"] == "1"

# 一家 seed 公司；所有 seed User 都掛在這家公司下。
company = Company.find_or_create_by!(name: "Quickey Demo Co.") do |c|
  c.company_type = "limited"
  c.tax_id       = "12345675"  # 通過台灣統編檢核的假統編
  c.plan         = "free"
end

DEV_USERS = [
  { email: "admin@example.com", name: "王管理", role: "admin",    status: "active" },
  { email: "ming@example.com",  name: "陳小明", role: "employee", status: "active" },
  { email: "zhang@example.com", name: "張大同", role: "employee", status: "active" }
]

DEV_USERS.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(attrs.merge(password: "password123", company: company))
  user.save!
end

puts "[seed] Company: #{company.name} (#{company.company_type})"
puts "[seed] Users: #{User.pluck(:email).join(', ')}"
