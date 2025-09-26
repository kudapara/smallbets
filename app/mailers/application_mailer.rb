class ApplicationMailer < ActionMailer::Base
  layout "mailer"

  helper_method :formatted_time

  def formatted_time(time)
    time&.strftime("%b %-d, %-I:%M %p")
  end
end
