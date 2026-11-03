module CustomizedActiveStorage
	extend ActiveSupport::Concern
	included do

		attr_accessor *attachment_reflections.keys.map{|i| "remove_#{i}".to_sym}
		attr_accessor *attachment_reflections.keys.map{|i| "remote_#{i}_url".to_sym}

		before_save do
			# 移除圖片
			self.class.attachment_reflections.keys.each do |key|
				if self.send("remove_#{key}") == "1"
					self.send(key).purge
				end
			end

			# 遠端存取圖片
			self.class.attachment_reflections.keys.each do |key|
				if self.send("remote_#{key}_url").present?
					url = self.send("remote_#{key}_url")

					filename = File.basename(URI.parse(url).path)
					file = URI.open(url)

					self.send("remote_#{key}_url=", nil)

					self.send(key).attach(io: file, filename: filename)

				end
			end
		end

	end
end