class NotifierMailer < ApplicationMailer
  include ActionView::Helpers::TextHelper
  
  def unread_mentions(user, messages)
    @user = user
    @messages = messages

    mail(to: @user.email_address, subject: "You have #{pluralize(messages.size, "unread mention")}")
  end
end
