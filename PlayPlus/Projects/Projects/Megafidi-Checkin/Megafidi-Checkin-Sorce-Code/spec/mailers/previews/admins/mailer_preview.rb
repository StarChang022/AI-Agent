# Preview all emails at http://localhost:3000/rails/mailers/admins/mailer
class Admins::MailerPreview < ActionMailer::Preview
	def confirmation_instructions
		Admins::MailerMailer.confirmation_instructions(Admin.first, Admin.first.confirmation_token || "confirmation_token")
	end

	def reset_password_instructions
		Admins::MailerMailer.reset_password_instructions(Admin.first, Admin.first.reset_password_token || "reset_password_token")
	end

	def email_changed
		Admins::MailerMailer.email_changed(Admin.first)
	end

	def password_change
		Admins::MailerMailer.password_change(Admin.first)
	end

	def unlock_instructions
		Admins::MailerMailer.unlock_instructions(Admin.first, Admin.first.unlock_token || "unlock_token")
	end

end
