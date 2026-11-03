# config/initializers/recaptcha.rb
# google recaptcha = https://www.google.com/recaptcha/admin#list
Recaptcha.configure do |config|
  config.site_key  = ENV['recaptcha_site_key']
  config.secret_key = ENV['recaptcha_secret_key']
  # Uncomment the following line if you are using a proxy server:
  # config.proxy = 'http://myproxy.com.au:8080'
end