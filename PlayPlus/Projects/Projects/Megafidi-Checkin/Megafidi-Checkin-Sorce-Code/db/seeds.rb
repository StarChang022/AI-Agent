# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
unless Admin.exists?
  Admin.create(email: 'admin@playplus.com.tw', name: 'admin', password: '00000000', role: 'admin', status: 'active')
  Admin.create(email: 'staff@playplus.com.tw', name: 'staff', password: '00000000', role: 'staff', status: 'active')
end
SystemSetting.create(seo_meta_tag: SeoMetaTag.new) if SystemSetting.first.blank?

Activity.clean
[
  { name: '高雄場活動', date: '2024/5/7' },
  { name: '台中場活動', date: '2024/5/9' },
  { name: '台北場活動', date: '2024/5/10' },
].each do |activity|
  @activity = Activity.find_or_initialize_by(name: activity[:name])
  @activity.update(date: activity[:date])
end

Guest.clean
@import_service = Import::Guest.new
@import_service.run
puts @import_service.errors
