# config/initializers/smtp.rb
ActionMailer::Base.smtp_settings = {
  address: "email-smtp.eu-north-1.amazonaws.com",
  port: 465,
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  authentication: :login,
  enable_starttls_auto: true,
  ssl: true
}
