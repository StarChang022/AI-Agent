# Preview all emails at http://localhost:3000/rails/mailers/users/mailer
class Users::MailerPreview < ActionMailer::Preview

	def confirmation_instructions
		Users::MailerMailer.confirmation_instructions(User.first, User.first.confirmation_token || "confirmation_token")
	end

	def reset_password_instructions
		Users::MailerMailer.reset_password_instructions(User.first, User.first.reset_password_token || "reset_password_token")
	end

	def email_changed
		Users::MailerMailer.email_changed(User.first)
	end

	def password_change
		Users::MailerMailer.password_change(User.first)
	end

	def unlock_instructions
		Users::MailerMailer.unlock_instructions(User.first, User.first.unlock_token || "reset_password_token")
	end

end
