class ApplicationMailer < ActionMailer::Base
  default from: 'Small Bets <support@smallbets.com>'
  layout 'mailer'

  helper_method :formatted_time

  def formatted_time(time)
    return "" unless time

    time.in_time_zone("Pacific Time (US & Canada)").strftime("%b %-d, %-I:%M %p")
  end
end

