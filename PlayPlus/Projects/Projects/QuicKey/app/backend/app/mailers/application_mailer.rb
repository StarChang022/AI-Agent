class ApplicationMailer < ActionMailer::Base
  default from: ENV["SMTP_FROM"].presence || ENV["SMTP_USERNAME"].presence || "from@example.com"
  layout "mailer"
end
